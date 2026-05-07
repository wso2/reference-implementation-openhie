# Demo Script — OpenHIE Client Registry
## A Day in Sri Lanka's Health Information Exchange

---

## Setup

**Base URL:** `http://localhost:9090`
**Audit URL:** `http://localhost:9093`


---

## Story 1: Maria's Healthcare Journey

> *Maria Silva is a 24-year-old woman living in Colombo. She visits her regional hospital for a routine checkup, then moves to Kandy and registers at a new hospital there. We track her full lifecycle in the Client Registry.*

### Scene 1 — Maria visits Colombo Regional Hospital for a checkup

She's never been in the system before. The hospital clerk registers her.

**`PUT`** `http://localhost:9090/fhir/r4/Patient?identifier=http://colombo-regional.moh.lk/mr|CR-2024-0156`

```json
{
  "resourceType": "Patient",
  "identifier": [
    { "use": "official", "system": "http://colombo-regional.moh.lk/mr", "value": "CR-2024-0156" },
    { "use": "official", "system": "http://moh.gov.lk/nic", "value": "200012345678" }
  ],
  "active": true,
  "name": [{ "use": "official", "family": "Silva", "given": ["Maria", "Fernanda"] }],
  "telecom": [
    { "system": "phone", "value": "+94771234567", "use": "mobile" },
    { "system": "email", "value": "maria.silva@example.com" }
  ],
  "gender": "female",
  "birthDate": "2000-06-15",
  "address": [{ "use": "home", "line": ["45 Galle Road"], "city": "Colombo", "district": "Western", "postalCode": "00300", "country": "LK" }],
  "extension": [{ "url": "http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName", "valueString": "Perera" }]
}
```
**Expected:** `201 Created` — Maria is now in the national Client Registry. Note the `id` (CRUID) returned.

**Talking point:** *"The hospital's local MRN (`CR-2024-0156`) is kept alongside her NIC number. The CR assigns a national CRUID that links her across all facilities."*

---

### Scene 2 — Doctor searches for Maria before the appointment

**`GET`** `http://localhost:9090/fhir/r4/Patient?family=Silva&given=Maria`

**Expected:** Bundle with Maria's record.

**Talking point:** *"Any facility connected to the HIE can search by name, NIC, phone, or other demographics."*

---

### Scene 3 — Maria moves to Kandy, registers at Kandy Teaching Hospital

6 months later, Maria relocated. She visits Kandy Teaching Hospital for a fever. The clerk registers her with her new address and the hospital's own MRN.

**`PUT`** `http://localhost:9090/fhir/r4/Patient?identifier=http://moh.gov.lk/nic|200012345678`

```json
{
  "resourceType": "Patient",
  "identifier": [
    { "use": "official", "system": "http://kandy-teaching.moh.lk/mr", "value": "KT-2024-0892" },
    { "use": "official", "system": "http://moh.gov.lk/nic", "value": "200012345678" }
  ],
  "active": true,
  "name": [{ "use": "official", "family": "Silva", "given": ["Maria", "Fernanda"] }],
  "telecom": [
    { "system": "phone", "value": "+94771234567", "use": "mobile" },
    { "system": "email", "value": "maria.silva@example.com" }
  ],
  "gender": "female",
  "birthDate": "2000-06-15",
  "address": [{ "use": "home", "line": ["120 Peradeniya Road"], "city": "Kandy", "district": "Central", "postalCode": "20000", "country": "LK" }],
  "extension": [{ "url": "http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName", "valueString": "Perera" }]
}
```
**Expected:** `200 OK` — Because the NIC (`200012345678`) already exists, this is a **conditional update**, not a duplicate. Her address changes to Kandy and version increments.

**Talking point:** *"The conditional PUT uses the NIC as the match key. Since Maria already exists, the CR updates her record instead of creating a duplicate. This is the ITI-104 transaction."*

---

### Scene 4 — Verify Maria's updated record

**`GET`** `http://localhost:9090/fhir/r4/Patient/{CRUID from Scene 1}`

**Expected:** Maria's record with Kandy address, `versionId: "2"`.

---

### Scene 5 — Maria passes away (or record needs to be deactivated)

**`DELETE`** `http://localhost:9090/fhir/r4/Patient?identifier=http://moh.gov.lk/nic|200012345678`

**Expected:** `204 No Content` — Soft delete, `active` set to `false`.

**`GET`** `http://localhost:9090/fhir/r4/Patient?family=Silva&active=false`

**Expected:** Maria appears with `"active": false`.

**Talking point:** *"The CR uses soft-delete — the record is deactivated, not erased, preserving the audit trail and historical data."*

---

## Story 2: The Duplicate Problem — Kamal Perera

> *Kamal Perera is a 34-year-old man who visits three different hospitals. Each one registers him slightly differently — different MRNs, slightly different name spellings. We use $match and system deduplication to find and resolve these duplicates.*

### Scene 1 — Three hospitals register the same patient differently

**Hospital A — Colombo General** (clean record)

**`PUT`** `http://localhost:9090/fhir/r4/Patient?identifier=http://colombo-general.moh.lk/mr|CG-10234`

```json
{
  "resourceType": "Patient",
  "identifier": [{ "use": "official", "system": "http://colombo-general.moh.lk/mr", "value": "CG-10234" }],
  "active": true,
  "name": [{ "use": "official", "family": "Perera", "given": ["Kamal", "Nishantha"] }],
  "telecom": [{ "system": "phone", "value": "+94712222222", "use": "mobile" }],
  "gender": "male",
  "birthDate": "1990-01-10",
  "address": [{ "use": "home", "line": ["88 Temple Road"], "city": "Colombo", "postalCode": "00100", "country": "LK" }]
}
```

**Hospital B — Kandy District Hospital** (middle name missing, different phone)

**`PUT`** `http://localhost:9090/fhir/r4/Patient?identifier=http://kandy-district.moh.lk/mr|KD-5567`

```json
{
  "resourceType": "Patient",
  "identifier": [{ "use": "official", "system": "http://kandy-district.moh.lk/mr", "value": "KD-5567" }],
  "active": true,
  "name": [{ "use": "official", "family": "Perera", "given": ["Kamal"] }],
  "telecom": [{ "system": "phone", "value": "+94773333333", "use": "mobile" }],
  "gender": "male",
  "birthDate": "1990-01-10",
  "address": [{ "use": "home", "city": "Kandy", "postalCode": "20000", "country": "LK" }]
}
```

**Hospital C — Galle Teaching Hospital** (different person entirely — Kasun Fernando)

**`PUT`** `http://localhost:9090/fhir/r4/Patient?identifier=http://galle-teaching.moh.lk/mr|GT-8821`

```json
{
  "resourceType": "Patient",
  "identifier": [{ "use": "official", "system": "http://galle-teaching.moh.lk/mr", "value": "GT-8821" }],
  "active": true,
  "name": [{ "use": "official", "family": "Fernando", "given": ["Kasun"] }],
  "telecom": [{ "system": "phone", "value": "+94779999999", "use": "mobile" }],
  "gender": "male",
  "birthDate": "1988-07-22",
  "address": [{ "use": "home", "city": "Galle", "postalCode": "80000", "country": "LK" }]
}
```

**Talking point:** *"In reality, patients visit multiple facilities. Without a shared identifier like NIC, each hospital creates its own record. The same person can end up with 2, 3, or more records in the CR."*

---

### Scene 2 — A clerk suspects a duplicate and uses $match

A data clerk at Colombo General wants to check if "Kamal Perera" already exists elsewhere.

**`POST`** `http://localhost:9090/fhir/r4/Patient/$match`

```json
{
  "resourceType": "Parameters",
  "parameter": [
    {
      "name": "resource",
      "resource": {
        "resourceType": "Patient",
        "name": [{ "family": "Perera", "given": ["Kamal"] }],
        "gender": "male",
        "birthDate": "1990-01-10",
        "telecom": [{ "system": "phone", "value": "+94712222222" }]
      }
    },
    { "name": "count", "valueInteger": 5 },
    { "name": "onlyCertainMatches", "valueBoolean": false }
  ]
}
```

**Expected:** Bundle with both Kamal Perera records ranked by score. The Colombo one scores highest (exact match), Kandy one slightly lower (same family+DOB+gender, different phone). Kasun Fernando does **not** appear.

**Talking point:** *"The $match operation (ITI-119) uses weighted scoring across name, DOB, gender, phone, and postal code. It returns candidates with a confidence grade: certain (>=0.95), probable (>=0.80), or possible (>=0.60)."*

---

### Scene 3 — System-wide deduplication run

The MoH data team runs a nightly dedup to catch all duplicates across the registry.

**Step 1 — Start the job:**

**`GET`** `http://localhost:9090/fhir/r4/Patient/dedupstart`

**Expected:** `{ "jobId": "...", "status": "pending" }`

**Step 2 — Poll until done (every 2-3 seconds):**

**`GET`** `http://localhost:9090/fhir/r4/Patient/dedupstatus`

**Expected:** `"status": "running"` then `"status": "completed"` with `totalGroups` count.

**Step 3 — View the results:**

**`GET`** `http://localhost:9090/fhir/r4/Patient/dedup`

**Expected:** Groups array — each group contains 2 patients side-by-side, a match score, matched/unmatched fields.

**Talking point:** *"The dedup engine uses blocking keys (Soundex of name + DOB, phone number, identifiers) to narrow candidates, avoiding O(n squared) full comparisons. It then scores each pair and groups results above the 0.60 threshold."*

---

### Scene 4 — Reject a false positive

Suppose the system flags a pair that the reviewer determines are **not** the same person.

**`GET`** `http://localhost:9090/fhir/r4/Patient/dedupreject?patient1={CRUID_1}&patient2={CRUID_2}`

(Use two patient IDs from a group in the dedup results)

**Expected:** `{ "status": "rejected", "exclusionCode": "..." }`

**Talking point:** *"Rejected pairs get an exclusion code. Future dedup runs skip them automatically, so reviewers don't waste time on the same false positives."*

---

### Scene 5 — Re-run dedup to confirm

**`GET`** `http://localhost:9090/fhir/r4/Patient/dedupstart`

Wait for completion, then:

**`GET`** `http://localhost:9090/fhir/r4/Patient/dedup`

**Expected:** The rejected pair no longer appears in results.

---

## Bonus: Audit Trail

> *"Every action in the system is logged. Let's look at the complete audit trail of everything we just did."*

**`GET`** `http://localhost:9093/audits?sortOrder=desc&limit=20`

**Expected:** Array of AuditEvent entries showing creates, updates, deletes, searches, and matches — with timestamps, agent info, and entity references.

---

## Feature Coverage Summary

| Demo Step | Feature | IHE Profile |
|-----------|---------|-------------|
| Story 1, Scene 1 | **Create** patient | ITI-104 |
| Story 1, Scene 2 | **Search** by name | ITI-78 |
| Story 1, Scene 3 | **Update** (conditional PUT) | ITI-104 |
| Story 1, Scene 4 | **Read** by CRUID | ITI-78 |
| Story 1, Scene 5 | **Delete** (soft) | ITI-104 |
| Story 2, Scene 1 | Create multiple patients | ITI-104 |
| Story 2, Scene 2 | **$match** probabilistic | ITI-119 |
| Story 2, Scene 3 | **Dedup** — start, poll, view | Custom |
| Story 2, Scene 4 | **Dedup reject** false positive | Custom |
| Story 2, Scene 5 | **Dedup re-run** with exclusion | Custom |
| Bonus | **Audit trail** | ATNA |
