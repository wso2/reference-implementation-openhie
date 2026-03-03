---
sidebar_position: 2
title: Database Schema
---

# Database Schema

The H2 database (`cr-core/data/mpi.mv.db`) is created automatically on first run. It contains five tables.

## Schema Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         patients                            │
├─────────────────┬───────────────┬────────────────────────────┤
│ Column          │ Type          │ Notes                      │
├─────────────────┼───────────────┼────────────────────────────┤
│ id              │ VARCHAR(64)   │ PK, UUID-based             │
│ resource_json   │ CLOB          │ Full FHIR JSON             │
│ active          │ BOOLEAN       │ Default: true              │
│ family_name     │ VARCHAR(255)  │ Indexed                    │
│ given_name      │ VARCHAR(255)  │ Indexed                    │
│ gender          │ VARCHAR(20)   │ Indexed                    │
│ birth_date      │ VARCHAR(10)   │ Indexed                    │
│ phone           │ VARCHAR(50)   │                            │
│ email           │ VARCHAR(255)  │                            │
│ city            │ VARCHAR(100)  │                            │
│ state           │ VARCHAR(100)  │                            │
│ postal_code     │ VARCHAR(20)   │                            │
│ country         │ VARCHAR(100)  │                            │
│ created_at      │ VARCHAR(30)   │                            │
│ updated_at      │ VARCHAR(30)   │ Indexed                    │
│ version         │ INT           │ Default: 1                 │
│ blocking_keys_at│ VARCHAR(30)   │ Last blocking key refresh  │
└─────────────────┴───────────────┴────────────────────────────┘
          │                 │                     │
          │ 1:N             │ 1:N                 │ 1:N
          ▼                 ▼                     ▼
┌─────────────────┐  ┌──────────────────────┐  ┌──────────────────────────────┐
│   identifiers   │  │    blocking_keys      │  │   dedup_pair_decisions        │
├─────┬───────────┤  ├──────┬───────────────┤  ├──────────────┬───────────────┤
│row_id│PK,Auto-i │  │row_id│PK, Auto-incr  │  │patient_id_1  │PK, FK→patient │
│patient_id│FK→pt │  │patient_id│FK→patients│  │patient_id_2  │PK, FK→patient │
│system│Namespace │  │block_type│Key category│  │decision_id   │VARCHAR(64)    │
│value │Identifier│  │block_value│Computed  │  │status        │VARCHAR(30)    │
├─────┴───────────┤  ├──────┴───────────────┤  │active        │BOOLEAN        │
│UNIQUE(sys,val)  │  │IDX(block_type,value) │  │created_at    │VARCHAR(30)    │
└─────────────────┘  │IDX(patient_id)       │  │updated_at    │VARCHAR(30)    │
                     └──────────────────────┘  │resolved_at   │VARCHAR(30)    │
                                               │created_by    │VARCHAR(255)   │
                                               │resolved_by   │VARCHAR(255)   │
                                               │resolution_rea│VARCHAR(255)   │
                                               ├──────────────┴───────────────┤
                                               │IDX(pid1,status), IDX(active) │
                                               └──────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                   dedup_compared_pairs                        │
├──────────────┬───────────────┬────────────────────────────────┤
│ Column       │ Type          │ Notes                          │
├──────────────┼───────────────┼────────────────────────────────┤
│ patient_id_1 │ VARCHAR(64)   │ PK (composite), id_1 < id_2   │
│ patient_id_2 │ VARCHAR(64)   │ PK (composite)                │
│ compared_at  │ VARCHAR(30)   │ When comparison was performed  │
│ score        │ DECIMAL(5,4)  │ Match score                    │
└──────────────┴───────────────┴────────────────────────────────┘
```

## Table Details

### `patients`

Stores the full FHIR Patient resource plus denormalized search fields for fast queries.

- **`id`** — UUID-based patient ID assigned by the CR (CRUID). Primary key.
- **`resource_json`** — Complete FHIR R4 Patient resource as JSON (CLOB).
- **`active`** — `true` for live patients, `false` for soft-deleted records.
- **Search fields** — `family_name`, `given_name`, `gender`, `birth_date` are indexed for ITI-78 queries.
- **`blocking_keys_at`** — Timestamp of last blocking key computation. `NULL` means keys need (re)computing.
- **`version`** — Incremented on each conditional PUT update.

### `identifiers`

Stores each `identifier` from the FHIR Patient resource for fast lookup.

- **`system`** — FHIR identifier system (e.g., `http://moh.gov.lk/nic`)
- **`value`** — Identifier value (e.g., `200012345678`)
- **Unique constraint** on `(system, value)` prevents duplicate identifiers

Enables O(1) lookup by identifier system + value for conditional PUT (upsert) operations.

### `blocking_keys`

Pre-computed keys that group patients into candidate sets for matching and deduplication.

- **`block_type`** — One of: `SDX_FAM_DOB`, `SDX_GIV_DOB_GEN`, `DOB_GEN_ZIP`, `PHONE`, `IDENT`
- **`block_value`** — The computed key string (e.g., `S400|1990-01-10`)
- **Composite index** on `(block_type, block_value)` enables fast candidate lookup

See [Deduplication](../backend/deduplication) for how these keys are computed and used.

### `dedup_compared_pairs`

Records every patient pair that has been scored during deduplication. Enables **incremental dedup** — only new, previously-uncompared pairs are scored on subsequent runs.

- Composite primary key `(patient_id_1, patient_id_2)` with convention `id_1 < id_2`
- **`score`** — The computed match score (0.0–1.0) from the last comparison

### `dedup_pair_decisions`

Stores admin decisions on candidate duplicate pairs.

- **`status`** — Currently only `rejected` is implemented
- **`active`** — `true` means the decision is in effect. Setting to `false` would re-enable the pair.
- Future dedup runs query this table to skip pairs with an active rejection decision.

## H2 Console Access

You can inspect the live database using the H2 web console. See [H2 Console](../guides/h2-console).
