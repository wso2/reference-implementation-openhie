---
sidebar_position: 3
title: Seeding Data
---

# Seeding Data

The repository includes shell scripts to populate the registry with sample patients for development, testing, and demos. All scripts run from the **repo root** and require the MPI backend (`cr-core`) to be running on port 9090.

## Available Scripts

| Script | Purpose |
|--------|---------|
| `seed-patients.sh` | Seed a small representative set of patients |
| `seed-dedup-scenarios.sh` | Seed patients with intentional duplicates for dedup demo |
| `seed-demo.sh` | Full demo seed: patients + duplicates |
| `seed-large.sh` | Bulk seed up to 500,000 patients for performance testing |

## Basic Seed

```bash
# Small set of patients
bash seed-patients.sh

# Patients with duplicate groups (for dedup demo)
bash seed-dedup-scenarios.sh

# Full demo seed (patients + duplicates)
bash seed-demo.sh
```

## Large Scale Seed

Seed up to 500,000 patients for performance and load testing:

```bash
# Syntax: bash seed-large.sh [total] [concurrency] [start_index]
bash seed-large.sh 500000 40 1
```

### Environment Overrides

```bash
BASE_URL="http://localhost:9090/fhir/r4" \
SYSTEM="http://www.acme.com/identifiers/patient" \
USER_ID="bulk-seeder" \
bash seed-large.sh 500000 40 1
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `total` | — | Total number of patients to seed |
| `concurrency` | — | Number of parallel requests |
| `start_index` | — | Starting index (re-run with a different value to append non-overlapping ranges) |
| `BASE_URL` | `http://localhost:9090/fhir/r4` | Backend URL |
| `SYSTEM` | — | Identifier system namespace |
| `USER_ID` | — | Agent name for audit trail |

:::tip Tuning concurrency
Increase or decrease `concurrency` based on your machine and backend capacity. Start with 10–20 for development machines.
:::

## Python Seed Script

The `cr-core/scripts/seed_lk_100k.py` script generates Sri Lanka–realistic patient data:

```bash
cd cr-core/scripts
python seed_lk_100k.py
```

## H2 SQL Seed

For direct database seeding (bypassing the API):

```bash
# Requires H2 CLI or the H2 console
# See guides/h2-console for access instructions
```

Script: `cr-core/scripts/seed_1m_pdqm_patients_h2.sql`
