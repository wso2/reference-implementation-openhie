"""
Sri Lanka Patient Seeder — 100,000 patients with ~15% duplicates
Uses async HTTP (httpx) to POST FHIR R4 Patient resources to the CR API.

Install:  pip install httpx
Run:      python cr-core/scripts/seed_lk_100k.py
"""

import asyncio
import random
import base64
import json
import httpx
from datetime import date, timedelta


# ─── CONFIG ──────────────────────────────────────────────────────────────────
BASE_URL       = "http://localhost:9090/fhir/r4/Patient"
TOTAL_BASE     = 85_000   # unique patients
DUP_RATE       = 0.15     # 15% will get 1 duplicate variant → ~12,750 extra
CONCURRENCY    = 50       # parallel requests
X_USER         = "seed-script"

# Simulated JWT: base64-encoded {"sub":"seed-script","role":"admin","exp":9999999999999}
def _make_token() -> str:
    payload = {"sub": "seed-script", "role": "admin", "exp": 9999999999999}
    return base64.b64encode(json.dumps(payload, separators=(",", ":")).encode()).decode()

AUTH_TOKEN = _make_token()
# ─────────────────────────────────────────────────────────────────────────────

# Sri Lankan name pools
SINHALA_GIVEN  = ["Kamal","Nimal","Sunil","Ruwan","Asanka","Chamara","Dinesh",
                   "Tharaka","Lasitha","Buddhika","Pradeep","Sampath","Roshan",
                   "Nuwan","Isuru","Sachith","Gayan","Thilina","Lahiru","Kasun",
                   "Malani","Nimali","Dilhani","Chamari","Sandya","Rashmi",
                   "Kumari","Thilini","Nadeesha","Anusha","Iresha","Samanthi",
                   "Kanchana","Sewwandi","Hiruni","Ruwanthika","Amaya","Sachini"]

TAMIL_GIVEN    = ["Arjun","Vijay","Kumar","Rajan","Selvam","Maran","Suresh",
                   "Prasath","Balamurugan","Karthik","Arun","Muthu","Senthil",
                   "Priya","Kavitha","Meena","Lakshmi","Anitha","Geetha","Nithya"]

SINHALA_FAMILY = ["Perera","Silva","Fernando","Jayasinghe","Wickramasinghe",
                   "Rajapaksa","Dissanayake","Gunasekara","Herath","Bandara",
                   "Seneviratne","Weerasinghe","Ranasinghe","Pathirana",
                   "Dharmawardena","Jayawardena","Liyanage","Kumara","Gamage",
                   "Rathnayake","Nanayakkara","Senanayake","Marasinghe","Peiris"]

TAMIL_FAMILY   = ["Navaratnam","Balasundaram","Ratnasingham","Krishnarajah",
                   "Sivanesan","Subramaniam","Chelvanayagam","Ramasamy",
                   "Thiruchelvam","Murugesan","Kandasamy","Arulpragasam"]

ALL_GIVEN  = SINHALA_GIVEN + TAMIL_GIVEN
ALL_FAMILY = SINHALA_FAMILY + TAMIL_FAMILY

CITIES = [
    ("Colombo",    "Western",      "00100"),
    ("Gampaha",    "Western",      "11000"),
    ("Kalutara",   "Western",      "12000"),
    ("Kandy",      "Central",      "20000"),
    ("Matale",     "Central",      "21000"),
    ("Nuwara Eliya","Central",     "22200"),
    ("Galle",      "Southern",     "80000"),
    ("Matara",     "Southern",     "81000"),
    ("Hambantota", "Southern",     "82000"),
    ("Jaffna",     "Northern",     "40000"),
    ("Vavuniya",   "Northern",     "43000"),
    ("Mannar",     "Northern",     "41000"),
    ("Trincomalee","Eastern",      "31000"),
    ("Batticaloa", "Eastern",      "30000"),
    ("Ampara",     "Eastern",      "32000"),
    ("Kurunegala", "North Western","60000"),
    ("Puttalam",   "North Western","61000"),
    ("Anuradhapura","North Central","50000"),
    ("Polonnaruwa","North Central","51000"),
    ("Badulla",    "Uva",          "90000"),
    ("Monaragala", "Uva",          "91000"),
    ("Ratnapura",  "Sabaragamuwa","70000"),
    ("Kegalle",    "Sabaragamuwa","71000"),
]

HOSPITALS = [
    ("http://colombo-general.moh.lk/mr",    "CG"),
    ("http://kandy-teaching.moh.lk/mr",     "KT"),
    ("http://galle-teaching.moh.lk/mr",     "GT"),
    ("http://jaffna-teaching.moh.lk/mr",    "JT"),
    ("http://kurunegala-general.moh.lk/mr", "KU"),
    ("http://anuradhapura-general.moh.lk/mr","AN"),
    ("http://ratnapura-general.moh.lk/mr",  "RP"),
    ("http://badulla-general.moh.lk/mr",    "BD"),
    ("http://matara-general.moh.lk/mr",     "MT"),
    ("http://batticaloa-general.moh.lk/mr", "BC"),
]

STREETS = ["Galle Road","Hospital Road","Temple Road","Main Street",
           "School Lane","Station Road","Lake Road","Kandy Road",
           "Beach Road","Market Street"]


def rand_nic(birth_year: int) -> str:
    """Generate a plausible new-format NIC (12 digits)."""
    day_offset = random.randint(1, 366)
    serial     = random.randint(100, 999)
    check      = random.randint(0, 9)
    return f"{birth_year}{day_offset:03d}{serial}{check}"


def rand_phone() -> str:
    prefix = random.choice(["071","072","075","076","077","078"])
    return f"+94{prefix[1:]}{random.randint(1000000, 9999999)}"


def rand_dob() -> str:
    start = date(1950, 1, 1)
    delta = random.randint(0, 365 * 70)
    return (start + timedelta(days=delta)).isoformat()


def rand_mrn(prefix: str, n: int) -> str:
    return f"{prefix}-{n:06d}"


def build_patient(idx: int, given: str, family: str, gender: str,
                  dob: str, phone: str, nic: str,
                  city_tuple: tuple, hospital: tuple) -> dict:
    hosp_sys, hosp_pfx = hospital
    city, district, postal = city_tuple
    mrn = rand_mrn(hosp_pfx, idx)
    street_no = random.randint(1, 500)
    street     = random.choice(STREETS)

    identifiers = [
        {"use": "official", "system": hosp_sys, "value": mrn},
    ]
    if nic:
        identifiers.append({"use": "official",
                             "system": "http://moh.gov.lk/nic",
                             "value": nic})

    return {
        "resourceType": "Patient",
        "identifier": identifiers,
        "active": True,
        "name": [{"use": "official", "family": family, "given": [given]}],
        "telecom": [
            {"system": "phone", "value": phone, "use": "mobile"},
            {"system": "email",
             "value": f"{given.lower()}.{family.lower()}{idx}@lk.example",
             "use": "home"},
        ],
        "gender": gender,
        "birthDate": dob,
        "address": [{
            "use": "home",
            "line": [f"{street_no} {street}"],
            "city": city,
            "district": district,
            "postalCode": postal,
            "country": "LK",
        }],
    }


def mutate_for_duplicate(patient: dict) -> dict:
    """Return a variant of patient simulating a slightly different registration."""
    import copy
    dup = copy.deepcopy(patient)

    mutation = random.choice(["typo_given", "typo_family", "diff_phone",
                               "diff_hospital", "diff_address", "missing_middle"])

    if mutation == "typo_given":
        g = dup["name"][0]["given"][0]
        # swap two adjacent chars
        if len(g) >= 3:
            i = random.randint(0, len(g) - 2)
            g = g[:i] + g[i+1] + g[i] + g[i+2:]
        dup["name"][0]["given"][0] = g

    elif mutation == "typo_family":
        f = dup["name"][0]["family"]
        if len(f) >= 3:
            i = random.randint(1, len(f) - 2)
            f = f[:i] + f[i+1] + f[i] + f[i+2:]
        dup["name"][0]["family"] = f

    elif mutation == "diff_phone":
        dup["telecom"][0]["value"] = rand_phone()

    elif mutation == "diff_hospital":
        hosp = random.choice(HOSPITALS)
        mrn  = rand_mrn(hosp[1], random.randint(10000, 99999))
        # keep NIC if present, replace MRN only
        dup["identifier"] = [i for i in dup["identifier"]
                              if "nic" in i.get("system","")]
        dup["identifier"].insert(0, {"use":"official","system":hosp[0],"value":mrn})

    elif mutation == "diff_address":
        city_tuple = random.choice(CITIES)
        dup["address"][0]["city"]       = city_tuple[0]
        dup["address"][0]["district"]   = city_tuple[1]
        dup["address"][0]["postalCode"] = city_tuple[2]

    elif mutation == "missing_middle":
        # remove NIC identifier (simulates clerk not entering it)
        dup["identifier"] = [i for i in dup["identifier"]
                              if "nic" not in i.get("system","")]

    return dup


def generate_all_patients() -> list[dict]:
    patients = []
    for i in range(1, TOTAL_BASE + 1):
        given   = random.choice(ALL_GIVEN)
        family  = random.choice(ALL_FAMILY)
        gender  = random.choice(["male", "female"])
        dob     = rand_dob()
        phone   = rand_phone()
        birth_year = int(dob[:4])
        nic     = rand_nic(birth_year) if random.random() > 0.10 else ""
        city    = random.choice(CITIES)
        hosp    = random.choice(HOSPITALS)

        p = build_patient(i, given, family, gender, dob, phone, nic, city, hosp)
        patients.append(p)

        if random.random() < DUP_RATE:
            patients.append(mutate_for_duplicate(p))

    random.shuffle(patients)
    return patients


async def post_patient(client: httpx.AsyncClient,
                       sem: asyncio.Semaphore,
                       patient: dict,
                       idx: int,
                       total: int) -> str:
    # Use conditional PUT on NIC if present, else plain POST
    nic_id = next(
        (i["value"] for i in patient.get("identifier", [])
         if "nic" in i.get("system", "")), None
    )

    headers = {
        "Content-Type": "application/fhir+json",
        "X-User-Id": X_USER,
        "Authorization": f"Bearer {AUTH_TOKEN}",
    }

    async with sem:
        try:
            if nic_id:
                url = f"{BASE_URL}?identifier=http://moh.gov.lk/nic|{nic_id}"
                r   = await client.put(url, json=patient, headers=headers, timeout=30)
            else:
                r = await client.post(BASE_URL, json=patient, headers=headers, timeout=30)

            if idx % 1000 == 0:
                print(f"  [{idx}/{total}] status={r.status_code}")
            return "ok"
        except Exception as e:
            return f"err:{e}"


async def main():
    print("Generating patient records...")
    patients = generate_all_patients()
    total    = len(patients)
    print(f"Total to seed: {total} ({TOTAL_BASE} base + duplicates)")

    sem = asyncio.Semaphore(CONCURRENCY)
    limits = httpx.Limits(max_connections=CONCURRENCY, max_keepalive_connections=CONCURRENCY)

    async with httpx.AsyncClient(limits=limits) as client:
        tasks   = [post_patient(client, sem, p, i+1, total)
                   for i, p in enumerate(patients)]
        results = await asyncio.gather(*tasks)

    ok  = results.count("ok")
    err = total - ok
    print(f"\nDone. OK={ok}  Errors={err}")


if __name__ == "__main__":
    asyncio.run(main())
