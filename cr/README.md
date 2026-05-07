# OpenHIE Client Registry

A standards-based **Master Patient Index (MPI)** implementation for health information exchanges (HIEs). Stores FHIR R4 `Patient` resources with IHE PDQm/PIXm transaction support, blocking-based patient matching, incremental deduplication, and a full-featured management UI.

## Components

| Component | Description | Port |
|-----------|-------------|------|
| `cr-core/` | Ballerina FHIR R4 backend (MPI service) | 9090 |
| `audit-service/` | Ballerina FHIR AuditEvent service (IHE ATNA) | 9093 |
| `cr-frontend/` | React management UI | 5173 |

## Features

- **ITI-78**: Patient Demographics Query (search, read)
- **ITI-104**: Patient Identity Feed (create, update, delete, merge)
- **ITI-119**: Patient Demographics Match (blocking-accelerated)
- **Deduplication**: Async, incremental, blocking-based patient deduplication with Union-Find grouping
- **Match Rejection**: Admin can reject false-positive matches; rejected pairs are excluded from future dedup runs
- **Audit Trail**: FHIR AuditEvent logging for all patient operations (IHE ATNA ITI-20)
- **Blocking Strategy**: Pre-computed indexed keys reduce candidate sets from millions to ~10-500 per query
- **Authentication**: Any OIDC-compliant provider (Asgardeo, Keycloak, Auth0, Okta, Azure AD, ...) in production, simulated auth in development

## Repository Structure

# Service starts at http://localhost:9090/fhir/r4
```
openhie_cr/
├── cr-core/                  # Ballerina FHIR MPI backend
│   ├── Ballerina.toml
│   ├── config.toml           # Service + matching configuration
│   ├── main.bal              # FHIR service endpoints
│   ├── db_repository.bal     # H2 database operations
│   ├── matching.bal          # Matching algorithms, scoring & blocking keys
│   ├── auth.bal              # Authentication & authorization
│   ├── audit_client.bal      # Audit service client
│   ├── api_config.bal        # FHIR API configuration
│   └── tests/               # Unit & integration tests
│
├── audit-service/            # Ballerina FHIR AuditEvent service
│   ├── Ballerina.toml
│   ├── service.bal           # Audit HTTP service (POST + GET /audits)
│   └── records.bal           # Internal audit record types
│
├── cr-frontend/              # React management UI
│   ├── src/
│   │   ├── api/              # API clients (patientService, auditService, matchService)
│   │   ├── auth/             # AuthContext (Asgardeo + simulated), ProtectedRoute
│   │   ├── components/       # Reusable UI components
│   │   ├── hooks/            # Custom React hooks (useAuditLog, useUserPreferences)
│   │   ├── layouts/          # AppLayout with navigation
│   │   ├── pages/            # LoginPage, DashboardPage, PatientsPage, AuditPage, ProfileSettingsPage
│   │   ├── utils/            # FHIR helpers, formatters, match utilities
│   │   └── theme.js          # WSO2 Oxygen UI theme
│   ├── public/Registry.png   # App logo displayed in the header
│   └── vite.config.js        # Dev proxy: /api → 9090, /audit-api → 9093
│
├── start.sh                  # One-command launcher (audit-service + cr-core + cr-frontend)
├── seed-patients.sh          # Seed sample patients
├── seed-large.sh             # Seed up to 500 000 patients (bulk)
├── seed-dedup-scenarios.sh   # Seed duplicate groups for dedup demo
└── seed-demo.sh              # Full demo seed (patients + duplicates)
```

## Prerequisites

| Tool | Version |
|------|---------|
| [Ballerina](https://ballerina.io/downloads/) | 2201.13.1 (Swan Lake Update 13) |
| [Node.js](https://nodejs.org/) | 18+ |
| npm | 9+ |

## Quick Start

### One-Command Start (recommended)

```bash
bash start.sh
```

This starts all three services in order (audit-service → cr-core → cr-frontend) and shuts them all down on `Ctrl+C`. Frontend dependencies are installed automatically if `node_modules` is missing.

```
Audit Service  → http://localhost:9093
MPI Backend    → http://localhost:9090/fhir/r4
Frontend       → http://localhost:5173
```

### Manual Start

#### 1. Start the Audit Service

```bash
cd audit-service
bal run
# Listening on http://localhost:9093
```

#### 2. Start the MPI Backend

```bash
cd cr-core
bal run
# Listening on http://localhost:9090/fhir/r4
```

#### 3. Start the Frontend

```bash
cd cr-frontend
npm install
npm run dev
# App at http://localhost:5173
```

Copy `cr-frontend/.env.example` to `cr-frontend/.env` and set `VITE_AUTH_MODE` before starting. For development, set `VITE_AUTH_MODE=simulated` and login with any email/password — all users receive the `admin` role.

See [cr-frontend/README.md](cr-frontend/README.md) for OIDC setup and frontend details.

---

## MPI Backend (`cr-core`)

### Database Schema

The H2 database (`data/mpi.mv.db`) is created automatically on first run.

#### patients table
Stores full PDQmPatient JSON + indexed search fields:
- `id` — Patient ID (primary key)
- `resource_json` — Full FHIR Patient JSON
- `family_name`, `given_name`, `gender`, `birth_date` — Indexed search fields
- `phone`, `email`, `city`, `state`, `postal_code`, `country` — Additional search fields
- `active`, `version`, `created_at`, `updated_at` — Metadata
- `blocking_keys_at` — Timestamp when blocking keys were last computed

#### identifiers table
For fast identifier lookups:
- `patient_id` — Foreign key to patients
- `system`, `value` — Identifier (unique constraint)

#### blocking_keys table
Pre-computed blocking keys for fast candidate selection:
- `patient_id` — Foreign key to patients
- `block_type` — Key category (e.g., `SDX_FAM_DOB`, `PHONE`)
- `block_value` — Computed key value
- Indexed on `(block_type, block_value)` and `(patient_id)`

#### dedup_compared_pairs table
Tracks previously compared patient pairs for incremental deduplication:
- `patient_id_1`, `patient_id_2` — Patient pair (PK, convention: id_1 < id_2)
- `compared_at` — Timestamp of comparison
- `score` — Match score from comparison (DECIMAL(5,4))

#### dedup_pair_decisions table
Stores admin decisions (e.g., rejections) on candidate duplicate pairs:
- `patient_id_1`, `patient_id_2` — Patient pair (composite PK, FK → patients with cascade delete)
- `decision_id` — UUID for this decision record
- `status` — Decision status (e.g., `rejected`)
- `active` — Whether this decision is currently active (default: true)
- `created_at`, `updated_at` — Timestamps
- `resolved_at` — When the decision was resolved (nullable)
- `created_by`, `resolved_by` — Agent who created/resolved the decision (nullable)
- `resolution_reason` — Free-text reason (nullable)
- Indexed on `(patient_id_1, status)`, `(patient_id_2, status)`, and `(active)`

### Visual Schema Diagram
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

### Running

```bash
cd cr-core
bal run
# Service starts at http://localhost:9090/fhir/r4
```

### Seed Patients

#### Search Patients (ITI-78)
```bash
# Seed a small set of patients
bash seed-patients.sh

# Seed patients with duplicate groups (for dedup demo)
bash seed-dedup-scenarios.sh

# Seed 500,000 patients for performance testing
# Syntax: bash seed-large.sh [total] [concurrency] [start_index]
bash seed-large.sh 500000 40 1
```

Optional environment overrides for seed-large.sh:

```bash
BASE_URL="http://localhost:9090/fhir/r4" \
SYSTEM="http://www.acme.com/identifiers/patient" \
USER_ID="bulk-seeder" \
bash seed-large.sh 500000 40 1
```

Notes:
- Increase/decrease `concurrency` based on your machine and backend capacity.
- Re-run with a different `start_index` to append another non-overlapping range.

## API Endpoints

All endpoints require a `Authorization: Bearer <token>` header. The token is a base64-encoded JSON object with `sub`, `role`, and `exp` claims. The `X-User-Id` header identifies the calling agent for audit logging.

### Required Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <base64-token>` — token payload: `{ "sub": "user@example.com", "role": "admin", "exp": <timestamp_ms> }` |
| `Content-Type` | For POST/PUT | `application/fhir+json` |
| `X-User-Id` | Optional | Agent identifier for audit trail |

### Roles & Permissions

| Endpoint | Method | Allowed Roles |
|----------|--------|---------------|
| `GET /Patient` | Search | `admin`, `viewer` |
| `GET /Patient/{id}` | Read | `admin`, `viewer` |
| `POST /Patient/$match` | Match | `admin`, `viewer` |
| `PUT /Patient?identifier=system\|value` | Create/Update | `admin` only |
| `DELETE /Patient?identifier=system\|value` | Delete | `admin` only |
| `GET /Patient/dedupstart` | Start dedup | `admin`, `viewer` |
| `GET /Patient/dedupstatus` | Poll dedup status | `admin`, `viewer` |
| `GET /Patient/dedup` | Get dedup results | `admin`, `viewer` |
| `GET /Patient/dedupreject?patient1=...&patient2=...` | Reject match | `admin` only |
| `GET /metadata` | Capability statement | No auth required |

### Example Token

```bash
# Generate a simulated admin token (base64-encoded JSON)
TOKEN=$(echo -n '{"sub":"admin@example.com","role":"admin","exp":9999999999999}' | base64)
```

### API Examples

#### Create Patient (ITI-104)
```bash
curl -X PUT "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "identifier": [{"system": "urn:oid:1.2.3", "value": "12345"}],
    "name": [{"family": "Test", "given": ["Patient"]}],
    "gender": "male",
    "birthDate": "1990-01-01"
  }'
```
Returns `201 Created` with `Location` header if patient doesn't exist, or `200 OK` with updated resource if it does.

#### Search Patients (ITI-78)
```bash
# By family name
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient?family=Doe"

# By identifier
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345"

# By demographics with pagination
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient?family=Doe&gender=male&birthdate=1980-01-01&_count=50&_offset=0"
```

Supported search parameters: `_id`, `_count`, `_offset`, `active`, `family`, `given`, `identifier`, `telecom`, `birthdate`, `address`, `address-city`, `address-country`, `address-postalcode`, `address-state`, `gender`, `mothersMaidenName`.

#### Read Patient (ITI-78)
```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/{id}
```

#### Match Patients (ITI-119)
```bash
curl -X POST http://localhost:9090/fhir/r4/Patient/\$match \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Parameters",
    "parameter": [{
      "name": "resource",
      "resource": {
        "resourceType": "Patient",
        "name": [{"family": "Doe", "given": ["John"]}],
        "birthDate": "1980-01-01"
      }
    }]
  }'
```
Optional parameters: `count` (max results, default 10), `onlyCertainMatches` (boolean, returns only grade=certain).

#### Update Patient (ITI-104)
```bash
curl -X PUT "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "identifier": [{"system": "urn:oid:1.2.3", "value": "12345"}],
    "name": [{"family": "Updated", "given": ["Patient"]}],
    "gender": "male",
    "birthDate": "1990-01-01"
  }'
```

#### Resolve Duplicate / Merge (ITI-104)
```bash
curl -X PUT "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "active": false,
    "identifier": [{"system": "urn:oid:1.2.3", "value": "12345"}],
    "link": [{
      "other": {
        "identifier": {"system": "urn:oid:1.2.3", "value": "67890"}
      },
      "type": "replaced-by"
    }]
  }'
```
Marks the subsumed patient as inactive with a `replaced-by` link to the surviving patient.

#### Delete Patient (ITI-104)
```bash
curl -X DELETE "http://localhost:9090/fhir/r4/Patient?identifier=urn:oid:1.2.3|12345" \
  -H "Authorization: Bearer $TOKEN"
```

#### Start Deduplication
```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/dedupstart
```
Returns `{ "jobId": "...", "status": "pending" }`. Returns `409 Conflict` if a job is already running.

#### Poll Deduplication Status
```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/dedupstatus
```
Returns the current/latest job status: `pending`, `running`, `completed`, or `failed`.

#### Get Deduplication Results
```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient/dedup
```
Returns the full results from the most recent completed dedup job, including match groups with scores.

#### Reject Dedup Match
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:9090/fhir/r4/Patient/dedupreject?patient1={id1}&patient2={id2}"
```
Records an admin rejection decision for a candidate duplicate pair by creating an entry in the `dedup_pair_decisions` table. Future dedup runs will skip pairs that have an active rejection decision. Returns `{ "status": "rejected", "patientId1": "...", "patientId2": "...", "decisionId": "..." }`.

Note: This does **not** affect `$match` (ITI-119) — rejected patients still appear in match results for clinical review.

## Authentication

The frontend supports two authentication modes: **OIDC** (production) and **Simulated** (development). The mode is explicitly set in `cr-frontend/.env` — the app will not start without it.

### Authentication Modes

#### OIDC (Any OIDC-Compliant Provider)

When `VITE_AUTH_MODE=oidc` is set along with `VITE_OIDC_CLIENT_ID` and `VITE_OIDC_AUTHORITY`, the app uses any standard OIDC identity provider (Asgardeo, Keycloak, Auth0, Okta, Azure AD, etc.) for authentication.

**Flow:**
1. User visits the app → `ProtectedRoute` redirects to `/login`
2. User clicks "Sign in" → redirected to the IdP hosted login page
3. After successful login → IdP redirects back to the app origin
4. The `react-oidc-context` library reads the session and populates user info from standard OIDC claims
5. `AuthContext` creates a **bridge token** (base64-encoded `{ sub, role, exp }`) for backend compatibility
6. Token and user info are synced to `localStorage` for the API client to use
7. On sign-out → IdP session is cleared and user is redirected to the app origin

#### Simulated (Development Mode)

When `VITE_AUTH_MODE=simulated` is set, the app uses a local email/password form. Any combination is accepted, and the user is assigned the `admin` role.

### Setup for Implementers

1. Register a **Single Page Application** (SPA) in your identity provider
2. Configure the application:
   - **Authorized Redirect URL**: `http://localhost:5173` (or your production URL)
   - **Allowed Logout URL**: `http://localhost:5173`
3. Copy `cr-frontend/.env.example` to `cr-frontend/.env` and fill in:
   ```env
   VITE_AUTH_MODE=oidc
   VITE_OIDC_CLIENT_ID=your-client-id
   VITE_OIDC_AUTHORITY=https://your-oidc-provider-base-url
   ```

Provider-specific `VITE_OIDC_AUTHORITY` examples:

| Provider | Authority URL |
|----------|--------------|
| Asgardeo | `https://api.asgardeo.io/t/your-org-name` |
| Keycloak | `https://your-keycloak-host/realms/your-realm` |
| Auth0 | `https://your-tenant.auth0.com` |
| Okta | `https://your-org.okta.com/oauth2/default` |
| Azure AD | `https://login.microsoftonline.com/your-tenant-id/v2.0` |

4. (Optional) For role-based access control:
   - Configure your IdP to include a `groups` claim in the ID token
   - Create groups `admin` and `viewer` and assign users accordingly

### Role-Based Access Control

| Role   | Chip Label | Source                                              |
|--------|------------|-----------------------------------------------------|
| admin  | MPI Admin  | User belongs to the `admin` group in the IdP        |
| viewer | MPI Viewer | Default when no groups are configured or user is not in `admin` group |

### Key Files

| File | Purpose |
|------|---------|
| `cr-frontend/src/config/auth.js` | Auth mode validation; `authMode` and `authConfigError` exports |
| `cr-frontend/src/auth/AuthContext.jsx` | Dual-mode auth provider (OIDC / simulated) with bridge token creation |
| `cr-frontend/src/auth/ProtectedRoute.jsx` | Route guard that redirects unauthenticated users to `/login` |
| `cr-frontend/src/api/client.js` | API client that attaches `Authorization` and `X-User-Id` headers |
| `cr-frontend/src/pages/LoginPage.jsx` | Login UI (OIDC redirect button or simulated form) |
| `cr-frontend/src/pages/ProfileSettingsPage.jsx` | Profile info, preferences, and session management (`/settings`) |
| `cr-frontend/src/hooks/useUserPreferences.js` | localStorage-backed preferences (page size, date format, audit auto-refresh) |
| `cr-frontend/.env.example` | Template for environment variables |

### Architecture Diagram

```
┌──────────────┐     ┌──────────────────┐
│   Browser    │────→│  OIDC IdP        │
│  (React App) │←────│  (any provider)  │
└──────┬───────┘     └──────────────────┘
       │
       │  Bridge Token (base64 JSON)
       │  + X-User-Id header
       ▼
┌──────────────┐     ┌──────────────────┐
│  Ballerina   │────→│  Audit Service   │
│  Backend     │     │  (audit-service) │
│  (cr-core)   │     │  Port 9093       │
└──────────────┘     └──────────────────┘
```

> **Phase 2 (planned):** The backend will validate real OIDC JWTs via the JWKS endpoint, replacing the bridge token approach.

## Profile & Settings (`/settings`)

The settings page is accessible via the gear icon in the app header and is available to all authenticated users.

### Tabs

| Tab | Description |
|-----|-------------|
| **Profile** | Read-only view of IdP-sourced user info (email, display name, role, groups) |
| **Preferences** | User-configurable UI settings persisted in `localStorage` |
| **Session** | Current session expiry timestamp and sign-out button |

### Preferences

Stored in `localStorage` under the key `user_preferences`. Applied immediately — no page reload required.

| Preference | Default | Options |
|------------|---------|---------|
| `defaultPageSize` | `10` | 5, 10, 25, 50 rows |
| `dateFormat` | `relative` | `relative` (e.g. "2 hours ago"), `absolute` (e.g. "Mar 3, 2026 14:30") |
| `auditAutoRefresh` | `true` | true / false |
| `auditRefreshInterval` | `30` | 15, 30, 60 seconds |

Preferences can be reset to defaults via the **Reset to Defaults** button.

## Deduplication Process Flowchart

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DEDUPLICATION PIPELINE                            │
└─────────────────────────────────────────────────────────────────────┘

    Admin calls GET /Patient/dedupstart
                    │
                    ▼
        ┌───────────────────────┐
        │  Job already running? │
        └───────┬───────┬───────┘
                │       │
             Yes│       │No
                ▼       ▼
          409 Conflict  Create DedupJob (status: pending)
                        │
                        ▼
              ┌─────────────────────┐
              │ Launch background   │
              │ strand (async)      │
              │ status → "running"  │
              └────────┬────────────┘
                       │
    ╔══════════════════╧═══════════════════════════════════════╗
    ║            STEP 1: Refresh Blocking Keys                 ║
    ╚══════════════════╤═══════════════════════════════════════╝
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Find patients where          │
        │ blocking_keys_at IS NULL     │
        │ (new/updated patients)       │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Compute blocking keys:       │
        │                              │
        │ • SDX_FAM_DOB                │
        │   soundex(family)|birthDate  │
        │                              │
        │ • SDX_GIV_DOB_GEN           │
        │   soundex(given)|DOB|gender  │
        │                              │
        │ • DOB_GEN_ZIP               │
        │   birthDate|gender|postal    │
        │                              │
        │ • PHONE                      │
        │   normalized phone digits    │
        │                              │
        │ • IDENT                      │
        │   system|value               │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Insert keys into             │
        │ blocking_keys table          │
        │ (batch of 5000 at a time)    │
        └──────────────┬───────────────┘
                       │
    ╔══════════════════╧═══════════════════════════════════════╗
    ║       STEP 2: Find New Candidate Pairs                   ║
    ╚══════════════════╤═══════════════════════════════════════╝
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Self-join blocking_keys:     │
        │                              │
        │ WHERE bk1.block_type         │
        │     = bk2.block_type         │
        │   AND bk1.block_value        │
        │     = bk2.block_value        │
        │   AND bk1.patient_id         │
        │     < bk2.patient_id         │
        │                              │
        │ Only ACTIVE patients         │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Exclude already-compared     │
        │ pairs (LEFT JOIN             │
        │ dedup_compared_pairs         │
        │ WHERE ... IS NULL)           │
        │                              │
        │ → Incremental: only NEW      │
        │   pairs are scored           │
        └──────────────┬───────────────┘
                       │
    ╔══════════════════╧═══════════════════════════════════════╗
    ║          STEP 3: Score New Pairs                         ║
    ╚══════════════════╤═══════════════════════════════════════╝
                       │
                       ▼
        ┌──────────────────────────────┐
        │ For each new pair (A, B):    │
        │                              │
        │  Load patients (with cache)  │
        │           │                  │
        │           ▼                  │
        │  calculateScore(A, B)        │
        │  ┌─────────────────────┐     │
        │  │ Per-field scoring:  │     │
        │  │ • identifier (0.30) │     │
        │  │ • family     (0.20) │     │
        │  │ • given      (0.15) │     │
        │  │ • birthDate  (0.20) │     │
        │  │ • gender     (0.05) │     │
        │  │ • phone      (0.05) │     │
        │  │ • postalCode (0.05) │     │
        │  │                     │     │
        │  │ Algorithms:         │     │
        │  │ exact/levenshtein/  │     │
        │  │ soundex/jarowinkler │     │
        │  │ per field           │     │
        │  └─────────────────────┘     │
        │           │                  │
        │           ▼                  │
        │  Store score in              │
        │  dedup_compared_pairs        │
        └──────────────┬───────────────┘
                       │
    ╔══════════════════╧═══════════════════════════════════════╗
    ║   STEP 4: Build Groups from ALL Scored Pairs             ║
    ╚══════════════════╤═══════════════════════════════════════╝
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Query ALL compared pairs     │
        │ WHERE score >= threshold     │
        │ (default 0.50)               │
        │ AND both patients active     │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ For each pair:               │
        │                              │
        │  ┌────────────────────────┐  │
        │  │ Active rejection in    │  │
        │  │ dedup_pair_decisions?  │  │
        │  └───────┬────────┬───────┘  │
        │       Yes│        │No        │
        │          ▼        ▼          │
        │       SKIP     Union-Find:   │
        │       pair     merge roots   │
        │                of A and B    │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Collect groups by root       │
        │ (only groups with ≥2         │
        │  patients)                   │
        └──────────────┬───────────────┘
                       │
    ╔══════════════════╧═══════════════════════════════════════╗
    ║        STEP 5: Build Result Groups                       ║
    ╚══════════════════╤═══════════════════════════════════════╝
                       │
                       ▼
        ┌──────────────────────────────┐
        │ For each group:              │
        │ • Load full FHIR Patient     │
        │   resources                  │
        │ • Compute avg pairwise score │
        │ • Assign match grade:        │
        │   ≥0.95 = certain            │
        │   ≥0.80 = probable           │
        │   ≥0.60 = possible           │
        │ • Compare fields between     │
        │   first two patients         │
        │   (matched vs unmatched)     │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ Return DedupResult:          │
        │ {                            │
        │   totalPatients,             │
        │   totalGroups,               │
        │   threshold,                 │
        │   timestamp,                 │
        │   groups: [...]              │
        │ }                            │
        │                              │
        │ Job status → "completed"     │
        └──────────────┬───────────────┘
                       │
    ╔══════════════════╧═══════════════════════════════════════╗
    ║              POST-DEDUP: Admin Review                     ║
    ╚══════════════════╤═══════════════════════════════════════╝
                       │
         ┌─────────────┼──────────────┐
         │             │              │
         ▼             ▼              ▼
    ┌─────────┐  ┌──────────┐  ┌──────────────┐
    │  MERGE  │  │  REJECT  │  │   SKIP       │
    │         │  │          │  │ (review later)│
    └────┬────┘  └────┬─────┘  └──────────────┘
         │            │
         ▼            ▼
    PUT /Patient   GET /Patient/dedupreject
    (ITI-104)      ?patient1=X&patient2=Y
    active=false        │
    link: replaced-by   ▼
         │         Decision record
         ▼         created in
    Subsumed       dedup_pair_decisions
    patient        → pair excluded from
    deactivated    future dedup runs
```

## Configuration

In `cr-core/config.toml`:
```toml
# Audit Service
auditServiceUrl = "http://localhost:9093"
auditEnabled = true
sourceObserverName = "client-registry"

# Database
dbUrl = "jdbc:h2:file:./data/mpi;AUTO_SERVER=TRUE"
dbUser = "sa"
dbPassword = ""

# Base URL
baseUrl = "http://localhost:9090/fhir/r4"
```

### Patient Matching Configuration

The matching engine supports four algorithms per field, all configured in `config.toml`:

| Algorithm | Description | Best for |
|-----------|-------------|----------|
| `exact` | Case-insensitive exact match | Identifiers, gender, dates |
| `levenshtein` | Edit-distance fuzzy matching | Typos, transpositions (Jhon/John) |
| `soundex` | Phonetic code matching | Names that sound alike (Michel/Michael, Robert/Rupert) |
| `jarowinkler` | Jaro-Winkler similarity | Short strings with prefix agreement (best for names) |

#### Thresholds

```toml
matchThreshold = 0.25       # minimum score for $match endpoint results
dedupThreshold = 0.50       # minimum score for dedup grouping

[gradeThresholds]
certain = 0.95              # >= 0.95 = certain match
probable = 0.80             # >= 0.80 = probable match
possible = 0.60             # >= 0.60 = possible match
```

#### Per-field algorithm and weight

Each field can use a different algorithm and weight. Weights must sum to 1.0.

```toml
[fields.identifier]
weight = 0.30
algorithm = "exact"

[fields.family]
weight = 0.20
algorithm = "soundex"           # change to "levenshtein" or "jarowinkler" for typo tolerance
levenshteinThreshold = 0.80     # only used when algorithm = "levenshtein"

[fields.given]
weight = 0.15
algorithm = "soundex"

[fields.birthDate]
weight = 0.20
algorithm = "exact"

[fields.gender]
weight = 0.05
algorithm = "exact"

[fields.phone]
weight = 0.05
algorithm = "levenshtein"       # fuzzy phone matching handles transpositions

[fields.postalCode]
weight = 0.05
algorithm = "exact"
```

When using `levenshtein`, the `levenshteinThreshold` (default 0.80) sets the minimum similarity ratio. Strings below this threshold score 0. Above it, the actual similarity is multiplied by the field weight, giving partial credit for close-but-not-exact matches.

When using `jarowinkler`, the optional parameters are:
```toml
jaroWinklerThreshold = 0.85     # minimum similarity to count as match (default 0.85)
jaroWinklerPrefixScale = 0.1    # prefix bonus scaling factor (default 0.1, max 0.25)
```

### Blocking Configuration

The blocking strategy avoids full-table scans by pre-computing indexed keys at patient creation/update time. Two patients sharing the same `(block_type, block_value)` become candidates for detailed scoring.

```toml
[blocking]
enabled = true                  # set to false to fall back to full-scan matching
refreshBatchSize = 5000         # patients per batch during startup migration
maxCandidatesPerMatch = 1000    # cap on candidates per $match query
```

#### Blocking Passes

| Block Type | Key Formula | Catches |
|---|---|---|
| `SDX_FAM_DOB` | `soundex(family) \| birth_date` | Phonetic name variants with same DOB |
| `SDX_GIV_DOB_GEN` | `soundex(given) \| birth_date \| gender` | Given name variants |
| `DOB_GEN_ZIP` | `birth_date \| gender \| postal_code` | Name changes (e.g., marriage) in same area |
| `PHONE` | Normalized phone digits | Direct telecom match |
| `IDENT` | `system \| value` | Exact identifier match |

Each patient produces 1-5 blocking keys depending on which fields are populated.

#### Why Each Block Exists

| Block              | What it catches                              | What it misses                              |
|--------------------|-----------------------------------------------|---------------------------------------------|
| **SDX_FAM_DOB**     | Name typos (Smith / Smyth)                    | Name changes (marriage, legal)              |
| **SDX_GIV_DOB_GEN** | First-name typos (Jon / John)                | Missing DOB or gender                       |
| **DOB_GEN_ZIP**     | Name changes completely                      | Patient moved (different ZIP)               |
| **PHONE**           | Everything if phone number is the same       | Different or missing phone numbers          |
| **IDENT**           | Re-registrations with the same identifier    | Different IDs across systems                |

#### How It Works

**`$match` (ITI-119):**
1. Compute blocking keys for the input patient (in memory)
2. Query `blocking_keys` table for candidate patient IDs sharing any key
3. Load and score only the candidates (~10-500 instead of all patients)
4. Filter by threshold, sort by score, return results

**Deduplication:**
1. Refresh blocking keys for new/updated patients (`refreshBlockingKeys()`)
2. Self-join `blocking_keys` to find candidate pairs sharing a key
3. Exclude already-compared pairs via `dedup_compared_pairs` (incremental)
4. Score new pairs, record results
5. Exclude pairs with shared exclusion codes (admin-rejected matches)
6. Build groups using Union-Find, return grouped results

#### Performance

| Operation | Before (full scan) | After (blocking) |
|---|---|---|
| `$match` per query | O(n) — scan all patients | O(k * log n + c) — k=5 block types, c=candidates |
| Deduplication | O(n²) — compare all pairs | O(b * p²) — b=blocks, p=patients per block (p << n) |

Blocking keys are automatically computed on `createPatient()` and `updatePatient()`. On first startup after migration, existing patients are batch-processed via `refreshBlockingKeys()`.

## H2 Console

Access H2 web console at runtime:
1. Database URL: `jdbc:h2:file:./data/mpi`
2. User: `sa`
3. Password: (empty)
