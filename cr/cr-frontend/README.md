# OpenHIE Client Registry — Frontend

React management UI for the OpenHIE Client Registry MPI service. Provides patient search, CRUD, deduplication review, and audit log viewing.

## Tech Stack

| Library | Version | Purpose |
|---------|---------|---------|
| React | 19 | UI framework |
| Vite | 7 | Build tool & dev server |
| WSO2 Oxygen UI | latest | Component library (MUI-based) |
| React Router | 7 | Client-side routing |
| react-oidc-context | 3 | Generic OIDC authentication |
| oidc-client-ts | 3 | OIDC protocol implementation |
| date-fns | 4 | Date formatting |

## Project Structure

```
src/
├── api/
│   ├── client.js           # Base fetch wrapper (attaches auth headers)
│   ├── patientService.js   # Patient CRUD + search + dedup API calls
│   ├── matchService.js     # $match (ITI-119) API calls
│   └── auditService.js     # Audit log API calls
│
├── auth/
│   ├── AuthContext.jsx     # Dual-mode auth provider (OIDC / simulated)
│   └── ProtectedRoute.jsx  # Redirects unauthenticated users to /login
│
├── components/
│   ├── PatientCard.jsx          # Patient summary card
│   ├── PatientViewDialog.jsx    # Read-only patient detail dialog
│   ├── PatientFormModal.jsx     # Create / edit patient form
│   ├── PatientInlineEditForm.jsx# Inline field editing
│   ├── PatientSearchPanel.jsx   # Search filters panel
│   ├── PatientMatchDialog.jsx   # $match results dialog
│   ├── MatchGroupCard.jsx       # Dedup match group card
│   ├── MergeModal.jsx           # Merge confirmation dialog
│   ├── NotificationSnackbar.jsx # Toast notifications
│   ├── PatientDetailsList.jsx   # Field-by-field patient diff view
│   ├── ScoreCircle.jsx          # Match score visualisation
│   ├── SearchToolbar.jsx        # Search bar with filters
│   └── StatsGrid.jsx            # Dashboard stats cards
│
├── config/
│   └── auth.js             # Auth mode validation; authMode + authConfigError exports
│
├── hooks/
│   ├── usePatients.js      # Patient list state + CRUD operations
│   ├── useMatchGroups.js   # Dedup job state + result groups
│   ├── useAuditLog.js      # Audit events fetching
│   └── useNotification.js  # Snackbar notification state
│
├── layouts/
│   └── AppLayout.jsx       # AppBar + horizontal nav + <Outlet>
│
├── pages/
│   ├── LoginPage.jsx       # Login screen (OIDC redirect button or simulated form)
│   ├── DashboardPage.jsx   # Stats overview
│   ├── PatientsPage.jsx    # Patient search, CRUD, dedup management
│   └── AuditPage.jsx       # Audit event log viewer
│
├── utils/
│   ├── fhirHelpers.js      # FHIR resource field extraction utilities
│   ├── formatters.js       # Date / string display formatters
│   └── matchUtils.js       # Match score / grade helpers
│
└── theme.js                # Oxygen UI theme customisation
```

## Dev Proxy

The Vite dev server proxies API requests to avoid CORS issues:

| Prefix | Target |
|--------|--------|
| `/api` | `http://localhost:9090` (MPI backend, path prefix stripped) |
| `/audit-api` | `http://localhost:9093` (Audit service, path prefix stripped) |

All `patientService.js` calls use `/api/fhir/r4/...` and all `auditService.js` calls use `/audit-api/audits`.

## Getting Started

### Prerequisites
- Node.js 20+
- The MPI backend (`cr-core`) running on port 9090
- The audit service (`audit-service`) running on port 9093

### Run in Development

```bash
npm install
npm run dev
# App at http://localhost:5173
```

Copy `.env.example` to `.env` and set `VITE_AUTH_MODE` before starting. For development, set `VITE_AUTH_MODE=simulated` and log in with **any** email and password — the simulated auth grants `admin` role automatically.

### Build for Production

```bash
npm run build
# Output in dist/
```

### Docker

The frontend is served by nginx on port **80** when run via Docker Compose. nginx handles SPA routing (all paths fall back to `index.html`) and reverse-proxies API requests to the backend services using their Docker service names:

| nginx location | Proxied to |
|----------------|-----------|
| `/api/` | `http://core:9090/` |
| `/audit-api/` | `http://audit-service:9096/` |

```bash
# From the cr/ directory:
docker compose up --build frontend
# App at http://localhost:80
```

The `nginx.conf` in this directory is copied into the image at build time — edit it to change proxy targets or add additional routes.

## Authentication

### Simulated Mode (Development)

Set `VITE_AUTH_MODE=simulated`. Any credentials are accepted at the login screen.

### OIDC Mode (Production)

Works with any OIDC-compliant identity provider. Set the following in `.env`:

```env
VITE_AUTH_MODE=oidc
VITE_OIDC_CLIENT_ID=your-client-id
VITE_OIDC_AUTHORITY=https://your-oidc-provider-base-url
```

1. Register a **Single Page Application** (SPA) in your identity provider
2. Set the **Authorized Redirect URL** to your app origin (e.g. `http://localhost:5173`)
3. Set `VITE_OIDC_AUTHORITY` to the issuer base URL — OIDC discovery is fetched from `{authority}/.well-known/openid-configuration`

Provider examples:

| Provider | `VITE_OIDC_AUTHORITY` |
|----------|----------------------|
| Asgardeo | `https://api.asgardeo.io/t/your-org-name` |
| Keycloak | `https://your-keycloak-host/realms/your-realm` |
| Auth0 | `https://your-tenant.auth0.com` |
| Okta | `https://your-org.okta.com/oauth2/default` |
| Azure AD | `https://login.microsoftonline.com/your-tenant-id/v2.0` |

### Role-Based Access

| Role | Label | Permissions |
|------|-------|-------------|
| `admin` | MPI Admin | Full access: create, edit, delete, merge, run dedup, reject matches |
| `viewer` | MPI Viewer | Read-only: search, view, run $match, view dedup results |

Configure your IdP to include a `groups` claim in the ID token with values `admin` and/or `viewer`. The `viewer` role is the default when no groups are configured.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `VITE_AUTH_MODE` | **Yes** | `"oidc"` or `"simulated"`. App will not start without this. |
| `VITE_OIDC_CLIENT_ID` | When `oidc` | Client ID from your identity provider |
| `VITE_OIDC_AUTHORITY` | When `oidc` | OIDC issuer base URL |
