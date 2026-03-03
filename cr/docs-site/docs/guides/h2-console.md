---
sidebar_position: 2
title: H2 Console
---

# H2 Database Console

The H2 web console provides direct access to the embedded database for inspection and debugging. It is available while `cr-core` is running.

## Accessing the Console

1. Ensure `cr-core` is running (`bal run` in the `cr-core/` directory)
2. Open your browser and navigate to the H2 console URL provided in the Ballerina startup output (typically `http://localhost:9090/h2-console` or the standalone H2 console tool)
3. Connect with the following credentials:

| Field | Value |
|-------|-------|
| **JDBC URL** | `jdbc:h2:file:./data/mpi` |
| **Username** | `sa` |
| **Password** | *(leave empty)* |

## Useful Queries

```sql
-- Count all patients
SELECT COUNT(*) FROM patients;

-- List recently created patients
SELECT id, family_name, given_name, birth_date, created_at
FROM patients
ORDER BY created_at DESC
LIMIT 20;

-- Show blocking key distribution
SELECT block_type, COUNT(*) as count
FROM blocking_keys
GROUP BY block_type
ORDER BY count DESC;

-- Find patients with no blocking keys (need refresh)
SELECT COUNT(*) FROM patients WHERE blocking_keys_at IS NULL;

-- Show dedup results above threshold
SELECT patient_id_1, patient_id_2, score, compared_at
FROM dedup_compared_pairs
WHERE score >= 0.50
ORDER BY score DESC
LIMIT 50;

-- Show rejected dedup pairs
SELECT * FROM dedup_pair_decisions WHERE status = 'rejected' AND active = true;

-- Show all identifiers for a patient
SELECT * FROM identifiers WHERE patient_id = 'your-patient-id';
```

## Database File Location

The database file is at `cr-core/data/mpi.mv.db`.

:::caution
Avoid modifying data directly through the H2 console in production. Use the FHIR API to ensure proper audit logging and business logic execution.
:::
