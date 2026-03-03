---
sidebar_position: 1
title: Overview
---

# Frontend Overview (`cr-frontend`)

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

## Source Structure

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

| Prefix | Rewritten to |
|--------|-------------|
| `/api/*` | `http://localhost:9090/*` (MPI backend — prefix stripped) |
| `/audit-api/*` | `http://localhost:9093/*` (Audit service — prefix stripped) |

All `patientService.js` calls use `/api/fhir/r4/...` and all `auditService.js` calls use `/audit-api/audits`.

The proxy is configured in `cr-frontend/vite.config.js`.

## Pages

| Page | Route | Description |
|------|-------|-------------|
| `LoginPage` | `/login` | Asgardeo sign-in button or simulated email/password form |
| `DashboardPage` | `/` | Stats cards (total patients, recent activity) |
| `PatientsPage` | `/patients` | Search patients, view/edit/delete, run $match, dedup management |
| `AuditPage` | `/audit` | Filterable audit event log |
