---
sidebar_position: 1
title: FHIR Endpoints
---

# FHIR API Reference

**Base URL:** `http://localhost:9090/fhir/r4`

All endpoints (except `/metadata`) require authentication headers.

## Required Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <base64-token>` — token payload: `{ "sub": "user@example.com", "role": "admin", "exp": <ms> }` |
| `Content-Type` | For POST/PUT | `application/fhir+json` |
| `X-User-Id` | Optional | Agent identifier recorded in the audit trail |

### Generate a Test Token

```bash
TOKEN=$(echo -n '{"sub":"admin@example.com","role":"admin","exp":9999999999999}' | base64)
```

---

## Patient Endpoints

### `PUT /Patient?identifier=system|value` — Create / Update (ITI-104)

Conditional upsert: creates a new patient if the identifier does not exist; updates the existing patient if it does.

**Returns:** `201 Created` with `Location` header (new patient) or `200 OK` (updated patient)

```bash
curl -X PUT "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "identifier": [{"system": "urn:oid:1.2.3", "value": "12345"}],
    "name": [{"family": "Silva", "given": ["Maria"]}],
    "gender": "female",
    "birthDate": "2000-06-15"
  }'
```

**Merge / Replace (ITI-104):** Use `active: false` + `link.type: "replaced-by"` to mark a patient as subsumed:

```bash
curl -X PUT "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "active": false,
    "identifier": [{"system": "urn:oid:1.2.3", "value": "12345"}],
    "link": [{
      "other": { "identifier": {"system": "urn:oid:1.2.3", "value": "67890"} },
      "type": "replaced-by"
    }]
  }'
```

---

### `GET /Patient?<params>` — Search Patients (ITI-78)

Search across patient demographics and identifiers.

**Supported search parameters:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `_id` | Patient ID (CRUID) | `_id=abc123` |
| `family` | Family name (case-insensitive) | `family=Silva` |
| `given` | Given name | `given=Maria` |
| `identifier` | System\|value pair | `identifier=urn:oid:1.2.3\|12345` |
| `birthdate` | Date of birth | `birthdate=2000-06-15` |
| `gender` | `male`, `female`, `other`, `unknown` | `gender=female` |
| `telecom` | Phone or email | `telecom=+94771234567` |
| `address` | Any address field | `address=Colombo` |
| `address-city` | City | `address-city=Colombo` |
| `address-country` | Country code | `address-country=LK` |
| `address-postalcode` | Postal code | `address-postalcode=00300` |
| `address-state` | State / district | `address-state=Western` |
| `mothersMaidenName` | Mother's maiden name | `mothersMaidenName=Perera` |
| `active` | Active status | `active=true` |
| `_count` | Results per page (default: 20) | `_count=50` |
| `_offset` | Pagination offset | `_offset=100` |

```bash
# Search by family name
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient?family=Silva"

# Search by identifier
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345"

# Search by demographics with pagination
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient?family=Perera&gender=male&birthdate=1990-01-10&_count=50&_offset=0"
```

**Returns:** FHIR `Bundle` resource with `type: searchset`.

---

### `GET /Patient/{id}` — Read Patient (ITI-78)

Retrieve a single patient by their CRUID.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/{id}
```

**Returns:** FHIR `Patient` resource or `404 Not Found`.

---

### `DELETE /Patient?identifier=system|value` — Delete Patient (ITI-104)

Soft-delete a patient by identifier. Sets `active = false` — the record is not removed from the database.

```bash
curl -X DELETE \
  "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345" \
  -H "Authorization: Bearer $TOKEN"
```

**Returns:** `204 No Content`

Soft-deleted patients can be found by searching with `active=false`.

---

### `POST /Patient/$match` — Patient Match (ITI-119)

Probabilistic patient matching using blocking-accelerated scoring.

```bash
curl -X POST http://localhost:9090/fhir/r4/Patient/\$match \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Parameters",
    "parameter": [
      {
        "name": "resource",
        "resource": {
          "resourceType": "Patient",
          "name": [{"family": "Perera", "given": ["Kamal"]}],
          "gender": "male",
          "birthDate": "1990-01-10",
          "telecom": [{"system": "phone", "value": "+94712222222"}]
        }
      },
      {"name": "count", "valueInteger": 10},
      {"name": "onlyCertainMatches", "valueBoolean": false}
    ]
  }'
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resource` | Patient | Required | Patient demographics to match against |
| `count` | integer | 10 | Maximum number of results to return |
| `onlyCertainMatches` | boolean | false | If `true`, returns only grade=certain results (score ≥ 0.95) |

**Returns:** FHIR `Bundle` resource with match results. Each entry includes a `match` extension with `grade` (`certain`, `probable`, `possible`) and `score` (0.0–1.0).

---

## Deduplication Endpoints

### `GET /Patient/dedupstart` — Start Deduplication

Launch an async deduplication job.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/dedupstart
```

**Returns:**
```json
{ "jobId": "uuid", "status": "pending" }
```

Returns `409 Conflict` if a dedup job is already running.

---

### `GET /Patient/dedupstatus` — Poll Deduplication Status

Check the status of the current or most recent dedup job.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/dedupstatus
```

**Returns:**
```json
{ "status": "running" }
// or
{ "status": "completed", "totalGroups": 12, "totalPatients": 5432, "completedAt": "..." }
```

Possible statuses: `pending`, `running`, `completed`, `failed`.

---

### `GET /Patient/dedup` — Get Deduplication Results

Retrieve the full results from the most recent completed dedup job.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/dedup
```

**Returns:** `DedupResult` object:
```json
{
  "totalPatients": 5432,
  "totalGroups": 12,
  "threshold": 0.50,
  "timestamp": "2025-01-15T10:30:00Z",
  "groups": [
    {
      "patients": [...],
      "score": 0.82,
      "grade": "probable",
      "matchedFields": ["family", "birthDate", "gender"],
      "unmatchedFields": ["phone"]
    }
  ]
}
```

---

### `GET /Patient/dedupreject` — Reject Dedup Match

Record an admin rejection decision for a candidate duplicate pair.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient/dedupreject?patient1={id1}&patient2={id2}"
```

**Query Parameters:**

| Parameter | Description |
|-----------|-------------|
| `patient1` | CRUID of first patient |
| `patient2` | CRUID of second patient |

**Returns:**
```json
{
  "status": "rejected",
  "patientId1": "...",
  "patientId2": "...",
  "decisionId": "uuid"
}
```

Creates an entry in `dedup_pair_decisions`. Future dedup runs skip this pair.

:::note
Rejection only affects the dedup pipeline. Rejected patients still appear in `$match` (ITI-119) results for clinical review.
:::

---

## Capability Statement

```bash
curl http://localhost:9090/fhir/r4/metadata
```

Returns a FHIR `CapabilityStatement` resource. No authentication required.
