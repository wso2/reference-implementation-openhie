"""
Clear all patient data from the CR PostgreSQL database.

Truncates patients, identifiers, blocking_keys, dedup_compared_pairs,
and dedup_pair_decisions in the correct order (FK constraints respected).

Install:  pip install psycopg2-binary
Run:      python cr-core/scripts/clear_db.py
"""

import psycopg2

# ─── CONFIG ──────────────────────────────────────────────────────────────────
DB_HOST = "localhost"
DB_PORT = 5432
DB_NAME = "cr_db"
DB_USER = "postgres"
DB_PASS = "postgres"
# ─────────────────────────────────────────────────────────────────────────────

TABLES = [
    "dedup_pair_decisions",
    "dedup_compared_pairs",
    "blocking_keys",
    "identifiers",
    "patients",
]


def run():
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT,
        dbname=DB_NAME, user=DB_USER, password=DB_PASS
    )
    conn.autocommit = False
    cur = conn.cursor()

    for table in TABLES:
        cur.execute(f"TRUNCATE TABLE {table} CASCADE")
        print(f"  Cleared {table}")

    conn.commit()
    cur.close()
    conn.close()
    print("Done.")


if __name__ == "__main__":
    confirm = input("This will delete ALL patient data. Type 'yes' to continue: ")
    if confirm.strip().lower() == "yes":
        run()
    else:
        print("Aborted.")
