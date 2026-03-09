---
sidebar_position: 3
title: Deduplication
---

# Deduplication

The deduplication pipeline identifies patient records that likely represent the same person and groups them for admin review. It is designed to be **incremental** (only new pairs are scored on each run) and **scalable** (blocking keys avoid O(n²) full comparisons).

## Starting a Dedup Run

The deduplication API follows the **FHIR async pattern** (same as `$export`): the start call returns `202 Accepted` with a `Content-Location` header pointing to the status URL. The client polls that URL until it receives `200 OK` with the full results.

```bash
# 1. Start the dedup job
curl -v -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/dedupstart

# Response: HTTP 202 Accepted
# Content-Location: /Patient/dedupstatus
# (no body)

# 2. Poll the Content-Location URL until done
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/dedupstatus

# While running → HTTP 202
# { "jobId": "...", "status": "running", "startedAt": "..." }
# Headers: X-Progress: running, Retry-After: 2

# When complete → HTTP 200 (full results inline)
# { "totalPatients": 5432, "totalGroups": 12, "groups": [...], ... }

# On failure → HTTP 500
# OperationOutcome with error details
```

If a job is already running, `dedupstart` still returns `202 Accepted` with the same `Content-Location` — the client simply starts polling the existing job.

## Pipeline Flowchart

```
Admin calls GET /Patient/dedupstart
                │
                ▼
    ┌───────────────────────┐
    │  Job already running? │
    └───────┬───────┬───────┘
            │       │
         Yes│       │No
            ▼       ▼
    202 + Content-  Create DedupJob (status: pending)
    Location header │
    (client polls)  ▼
          ┌─────────────────────┐
          │ Launch background   │
          │ strand (async)      │
          │ status → "running"  │
          └────────┬────────────┘
                   │
          ┌────────▼────────────┐
          │ Client polls        │
          │ /Patient/dedupstatus│
          │ → 202 while running │
          │ → 200 when done     │
          └─────────────────────┘
```

### Step 1 — Refresh Blocking Keys

Patients added or updated since the last run have `blocking_keys_at = NULL`. This step computes blocking keys for those patients:

| Block Type | Key Formula | Catches |
|---|---|---|
| `SDX_FAM_DOB` | `soundex(family) \| birth_date` | Name phonetic variants with same DOB |
| `SDX_GIV_DOB_GEN` | `soundex(given) \| birth_date \| gender` | Given name variants |
| `DOB_GEN_ZIP` | `birth_date \| gender \| postal_code` | Name changes (e.g. marriage) in same area |
| `PHONE` | Normalized phone digits | Direct phone number match |
| `IDENT` | `system \| value` | Exact identifier match |

Keys are inserted into `blocking_keys` in batches of 5,000.

### Step 2 — Find New Candidate Pairs

A self-join on `blocking_keys` finds patients sharing any key:

```sql
-- Conceptual query (simplified)
SELECT bk1.patient_id, bk2.patient_id
FROM blocking_keys bk1
JOIN blocking_keys bk2
  ON bk1.block_type = bk2.block_type
 AND bk1.block_value = bk2.block_value
 AND bk1.patient_id < bk2.patient_id
-- Exclude already-compared pairs
LEFT JOIN dedup_compared_pairs dcp ON ...
WHERE dcp.patient_id_1 IS NULL
  AND both patients are active
```

Only **new** pairs not in `dedup_compared_pairs` are processed.

### Step 3 — Score New Pairs

Each new pair is scored using the configured matching algorithms and field weights:

| Field | Default Weight | Default Algorithm |
|-------|----------------|-------------------|
| `identifier` | 0.30 | `exact` |
| `family` | 0.20 | `soundex` |
| `given` | 0.15 | `soundex` |
| `birthDate` | 0.20 | `exact` |
| `gender` | 0.05 | `exact` |
| `phone` | 0.05 | `levenshtein` |
| `postalCode` | 0.05 | `exact` |

Score = Σ (field_score × field_weight). Scores range from 0.0 to 1.0.

Results are stored in `dedup_compared_pairs`.

### Step 4 — Build Groups from All Scored Pairs

All pairs with `score >= dedupThreshold` (default 0.50) are loaded:

- If the pair has an active rejection in `dedup_pair_decisions` → **skip**
- Otherwise → **Union-Find**: merge the roots of A and B

This handles transitive duplicates: if A=B and B=C, then A, B, and C all end up in the same group.

### Step 5 — Build Result Groups

For each Union-Find group with ≥ 2 patients:
- Load full FHIR Patient resources
- Compute average pairwise score
- Assign match grade:
  - `≥ 0.95` → **certain**
  - `≥ 0.80` → **probable**
  - `≥ 0.60` → **possible**
- Compare fields between the first two patients (matched vs unmatched fields)

Returns `DedupResult` with `totalPatients`, `totalGroups`, `threshold`, `timestamp`, and `groups[]`.

## Post-Dedup Admin Review

After the `200 OK` response from `GET /Patient/dedupstatus` returns the full results, admins have three options:

### Merge (ITI-104)

```bash
# Mark a patient as replaced by another
curl -X PUT "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "active": false,
    "identifier": [{"system": "urn:oid:1.2.3", "value": "12345"}],
    "link": [{ "other": {"identifier": {"system": "urn:oid:1.2.3", "value": "67890"}}, "type": "replaced-by" }]
  }'
```

The subsumed patient is deactivated with a `replaced-by` link to the surviving patient.

### Reject (False Positive)

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient/dedupreject?patient1={id1}&patient2={id2}"
```

Creates an entry in `dedup_pair_decisions` with `status=rejected`. Future dedup runs skip this pair.

Returns:
```json
{ "status": "rejected", "patientId1": "...", "patientId2": "...", "decisionId": "..." }
```

:::note
Rejection only affects the dedup pipeline. Rejected patients still appear in `$match` (ITI-119) results for clinical review.
:::

### Skip

Do nothing — the pair remains in results for later review.

## Performance

| Operation | Without Blocking | With Blocking |
|---|---|---|
| `$match` per query | O(n) — full scan | O(k×log n + c) — k=5 keys, c=candidates |
| Deduplication | O(n²) — all pairs | O(b×p²) — b=blocks, p=patients per block (p much smaller than n) |

Blocking keys are computed automatically on `createPatient()` and `updatePatient()`. Existing patients are batch-processed via `refreshBlockingKeys()` on startup migration.

## Configuration

Thresholds and algorithms are configured in `cr-core/config.toml`. See [Configuration](configuration).
