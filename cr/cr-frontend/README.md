# OpenHIE Client Registry — Frontend

React management UI for the OpenHIE Client Registry MPI service. Provides patient search, CRUD, deduplication review, and audit log viewing.

## Tech Stack

| Library | Version | Purpose |
|---------|---------|---------|
| React | 19 | UI framework |
| Vite | 7 | Build tool & dev server |
| WSO2 Oxygen UI | latest | Component library (MUI-based) |
| React Router | 7 | Client-side routing |
| @asgardeo/react | 0.11 | Asgardeo OIDC authentication |
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
│   ├── AuthContext.jsx     # Dual-mode auth provider (Asgardeo / simulated)
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
│   └── auth.js             # Asgardeo SDK config + isAsgardeoEnabled flag
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
│   ├── LoginPage.jsx       # Login screen (Asgardeo button or simulated form)
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
- Node.js 18+
- The MPI backend (`cr-core`) running on port 9090
- The audit service (`audit-service`) running on port 9093

### Run in Development

```bash
npm install
npm run dev
# App at http://localhost:5173
```

In development (no Asgardeo env vars set), login with **any** email and password — the simulated auth grants `admin` role automatically.

### Build for Production

```bash
npm run build
# Output in dist/
```

## Authentication

### Development Mode (Simulated)

No configuration needed. Any credentials are accepted at the login screen.

### Production Mode (Asgardeo)

1. Create a [free Asgardeo account](https://console.asgardeo.io)
2. Create a **Single Page Application**
3. Set:
   - **Authorized Redirect URL**: your app origin (e.g. `http://localhost:5173`)
   - **Allowed Logout URL**: same as above
4. Copy `.env.example` to `.env` and fill in:

```env
VITE_ASGARDEO_CLIENT_ID=your-client-id
VITE_ASGARDEO_BASE_URL=https://api.asgardeo.io/t/your-org-name
```

### Role-Based Access

| Role | Label | Permissions |
|------|-------|-------------|
| `admin` | MPI Admin | Full access: create, edit, delete, merge, run dedup, reject matches |
| `viewer` | MPI Viewer | Read-only: search, view, run $match, view dedup results |

In Asgardeo, create groups named `admin` and `viewer`, assign users, and enable the `groups` User Attribute on the application. The `viewer` role is the default when no groups are configured.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `VITE_ASGARDEO_CLIENT_ID` | No | Asgardeo SPA client ID. Leave blank for simulated auth. |
| `VITE_ASGARDEO_BASE_URL` | No | Asgardeo API base URL (e.g. `https://api.asgardeo.io/t/myorg`). Leave blank for simulated auth. |
