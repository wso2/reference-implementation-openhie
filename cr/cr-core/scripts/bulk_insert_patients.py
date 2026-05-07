"""
Bulk insert FHIR Patient NDJSON into the CR PostgreSQL database.

Reads the NDJSON produced by generate_lk_patients.py and inserts directly into
the patients, identifiers, and blocking_keys tables — bypassing the REST API.

Install:  pip install psycopg2-binary
Generate: python cr-core/scripts/generate_lk_patients.py --count 100
Run:      python cr-core/scripts/bulk_insert_patients.py
"""

import json
import re
import time
import uuid
from datetime import datetime, timezone

import psycopg2
import psycopg2.extras

# ─── CONFIG ──────────────────────────────────────────────────────────────────
DB_HOST    = "localhost"
DB_PORT    = 5432
DB_NAME    = "cr_db"
DB_USER    = "postgres"
DB_PASS    = "postgres"
INPUT_FILE = "./output/pdqm_patients.ndjson"
BATCH_SIZE = 1_000
# ─────────────────────────────────────────────────────────────────────────────


# ── Soundex (matches Ballerina matching.bal implementation) ──────────────────
_SOUNDEX_TABLE = str.maketrans(
    "BFPVCGJKQSXZDTLMNR",
    "111122222222334556"
)
_SOUNDEX_REMOVE = str.maketrans("", "", "AEIOUYHW")

def soundex(s: str) -> str:
    if not s:
        return "0000"
    s = s.upper()
    first = s[0]
    coded = s.translate(_SOUNDEX_TABLE)
    # remove duplicates keeping first char's code
    deduped = coded[0]
    for ch in coded[1:]:
        if ch != deduped[-1]:
            deduped += ch
    # remove non-digit chars (vowels, H, W, Y map to nothing)
    digits = re.sub(r"[^0-9]", "", deduped[1:])
    return (first + digits + "000")[:4]


# ── Field extraction helpers ─────────────────────────────────────────────────

def get_family(p: dict) -> str | None:
    names = p.get("name", [])
    return names[0].get("family") if names else None


def get_given(p: dict) -> str | None:
    names = p.get("name", [])
    if not names:
        return None
    given = names[0].get("given", [])
    return " ".join(given) if given else None


def get_telecom(p: dict, system: str) -> str | None:
    for t in p.get("telecom", []):
        if t.get("system") == system:
            return t.get("value")
    return None


def get_address_field(p: dict, field: str) -> str | None:
    addrs = p.get("address", [])
    return addrs[0].get(field) if addrs else None


def normalize_phone(phone: str | None) -> str | None:
    if not phone:
        return None
    digits = re.sub(r"[^0-9]", "", phone)
    # strip leading country code "1" if 11 digits (US) — matches matching.bal
    if len(digits) == 11 and digits.startswith("1"):
        digits = digits[1:]
    return digits if digits else None


# ── Blocking key computation ─────────────────────────────────────────────────

def compute_blocking_keys(patient_id: str, p: dict) -> list[tuple]:
    family     = get_family(p)
    given      = get_given(p)
    birth_date = p.get("birthDate")
    gender     = p.get("gender")
    postal     = get_address_field(p, "postalCode")
    phone_raw  = get_telecom(p, "phone")
    phone_norm = normalize_phone(phone_raw)

    keys = []

    if family and birth_date:
        keys.append((patient_id, "SDX_FAM_DOB",
                     soundex(family) + "|" + birth_date))

    if given and birth_date and gender:
        keys.append((patient_id, "SDX_GIV_DOB_GEN",
                     soundex(given) + "|" + birth_date + "|" + gender))

    if birth_date and gender and postal:
        keys.append((patient_id, "DOB_GEN_ZIP",
                     birth_date + "|" + gender + "|" + postal))

    if phone_norm:
        keys.append((patient_id, "PHONE", phone_norm))

    for ident in p.get("identifier", []):
        sys = ident.get("system", "")
        val = ident.get("value", "")
        if sys and val:
            keys.append((patient_id, "IDENT", sys + "|" + val))

    return keys


# ── Main ─────────────────────────────────────────────────────────────────────

def run():
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT,
        dbname=DB_NAME, user=DB_USER, password=DB_PASS
    )
    conn.autocommit = False
    cur = conn.cursor()

    now        = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    total      = 0
    errors     = 0
    t_start    = time.time()

    pat_batch   = []
    ident_batch = []
    key_batch   = []

    def flush():
        nonlocal total, errors
        if not pat_batch:
            return
        try:
            psycopg2.extras.execute_values(cur, """
                INSERT INTO patients
                    (id, resource_json, active, family_name, given_name,
                     gender, birth_date, phone, email, city, state,
                     postal_code, country, created_at, updated_at,
                     version, blocking_keys_at)
                VALUES %s
                ON CONFLICT (id) DO NOTHING
            """, pat_batch)

            if ident_batch:
                psycopg2.extras.execute_values(cur, """
                    INSERT INTO identifiers (patient_id, system, value)
                    VALUES %s
                    ON CONFLICT (system, value) DO NOTHING
                """, ident_batch)

            if key_batch:
                psycopg2.extras.execute_values(cur, """
                    INSERT INTO blocking_keys (patient_id, block_type, block_value)
                    VALUES %s
                """, key_batch)

            conn.commit()
            total += len(pat_batch)

            elapsed = time.time() - t_start
            rps     = total / elapsed if elapsed > 0 else 0
            print(f"  Inserted {total:,} patients  ({rps:.0f} rec/s)")

        except Exception as e:
            conn.rollback()
            errors += len(pat_batch)
            print(f"  Batch error: {e}")

        pat_batch.clear()
        ident_batch.clear()
        key_batch.clear()

    print(f"Reading {INPUT_FILE} ...")

    with open(INPUT_FILE, encoding="utf-8") as fh:
        for line_no, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                p = json.loads(line)
            except json.JSONDecodeError as e:
                print(f"  Line {line_no}: JSON error — {e}")
                errors += 1
                continue

            patient_id = str(uuid.uuid4())
            # Stamp the id back into the resource JSON
            p["id"] = patient_id
            resource_json = json.dumps(p, separators=(",", ":"))

            pat_batch.append((
                patient_id,
                resource_json,
                p.get("active", True),
                get_family(p),
                get_given(p),
                p.get("gender"),
                p.get("birthDate"),
                get_telecom(p, "phone"),
                get_telecom(p, "email"),
                get_address_field(p, "city"),
                get_address_field(p, "state"),
                get_address_field(p, "postalCode"),
                get_address_field(p, "country"),
                now, now,
                1,
                now,
            ))

            for ident in p.get("identifier", []):
                sys = ident.get("system", "")
                val = ident.get("value", "")
                if sys and val:
                    ident_batch.append((patient_id, sys, val))

            key_batch.extend(compute_blocking_keys(patient_id, p))

            if len(pat_batch) >= BATCH_SIZE:
                flush()

    flush()

    cur.close()
    conn.close()

    elapsed = time.time() - t_start
    print(f"\nDone in {elapsed:.1f}s — inserted {total:,} patients, {errors} errors")


if __name__ == "__main__":
    run()
