---
sidebar_position: 1
title: System Overview
---

# System Overview

The OpenHIE Client Registry is a three-service architecture: a FHIR R4 MPI backend, an ATNA-compliant audit service, and a React management UI.

## Component Diagram

```
                   ┌──────────────────────────────────┐
                   │    Browser (React App)           │
                   │    http://localhost:5173         │
                   └──────┬──────────────┬────────────┘
          /api/* → 9090   │              │ OIDC (production)
                          │              │
          ┌───────────────┘         ┌────▼───────────────┐
          │                         │  OIDC IdP          │
          ▼                         │  (any provider)    │
┌─────────────────────┐             └────────────────────┘
│  cr-core            │
│  Ballerina FHIR R4  │──POST /audits──►  ┌──────────────────────┐
│  localhost:9090     │                   │  audit-service       │
└────────┬────────────┘                   │  Ballerina AuditEvent│
         │                                │  localhost:9093      │
         ▼                                └──────────────────────┘
┌─────────────────────┐                   
│  H2 Database        │
│  data/mpi.mv.db     │
└─────────────────────┘
```

## Request Flow

Example: user searches for patients by surname.

```
Browser        cr-frontend      cr-core :9090    H2 Database    audit-service :9093
   │                │                │                │                  │
   │  User action   │                │                │                  │
   │───────────────►│                │                │                  │
   │                │  GET /fhir/r4/Patient?family=Silva                 │
   │                │───────────────►│                │                  │
   │                │                │  SELECT …      │                  │
   │                │                │───────────────►│                  │
   │                │                │◄── result rows─│                  │
   │                │  FHIR Bundle   │                │                  │
   │                │◄───────────────│                │                  │
   │ Rendered cards │                │                │                  │
   │◄───────────────│                │  POST /audits (async, new strand) │
   │                │                │── ── ── ── ── ── ── ── ── ── ── ► │
   │                │                │                │                  │
```
> Audit events are sent fire-and-forget on a separate Ballerina strand. The FHIR response is returned immediately; audit delivery does not block or affect the caller.

## Services

### cr-core (MPI Backend)

- **Language**: Ballerina 2201.13.1
- **Port**: 9090
- **Base path**: `/fhir/r4`
- **Database**: H2 (embedded, auto-created at `data/mpi.mv.db`)
- **Key responsibilities**:
  - FHIR R4 Patient resource CRUD (ITI-78, ITI-104)
  - Probabilistic patient matching (ITI-119)
  - Blocking key management and deduplication pipeline
  - Authentication and role-based access control
  - Audit event emission to the audit service

### audit-service

- **Language**: Ballerina 2201.13.1
- **Port**: 9093
- **Key responsibilities**:
  - Receive FHIR AuditEvent resources via `POST /audits`
  - Persist events to NDJSON log file
  - Expose `GET /audits` with filtering and pagination
  - Buffer failed writes in-memory with 30-second retry

### cr-frontend

- **Framework**: React 19 + Vite 7
- **Port**: 5173 (dev)
- **Key responsibilities**:
  - Patient search, create, update, delete
  - Deduplication review UI (start job, view groups, merge/reject)
  - Audit log viewer
  - Dual-mode authentication (OIDC + simulated)

## Repository Structure

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
│   │   ├── auth/             # AuthContext (OIDC + simulated), ProtectedRoute
│   │   ├── components/       # Reusable UI components
│   │   ├── hooks/            # Custom React hooks
│   │   ├── layouts/          # AppLayout with navigation
│   │   ├── pages/            # LoginPage, DashboardPage, PatientsPage, AuditPage
│   │   ├── utils/            # FHIR helpers, formatters, match utilities
│   │   └── theme.js          # WSO2 Oxygen UI theme
│   └── vite.config.js        # Dev proxy: /api → 9090, /audit-api → 9093
│
├── seed-patients.sh          # Seed sample patients
├── seed-large.sh             # Seed up to 500 000 patients (bulk)
├── seed-dedup-scenarios.sh   # Seed duplicate groups for dedup demo
└── seed-demo.sh              # Full demo seed (patients + duplicates)
```

## Authentication Architecture

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

The frontend creates a **bridge token** (base64-encoded `{ sub, role, exp }` JSON) from the OIDC session, which the backend decodes for authorization. A future phase will validate real OIDC JWTs via the JWKS endpoint.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend language | Ballerina | Native FHIR R4 library support, strong health interoperability ecosystem |
| Database | H2 (embedded) | Zero-config, sufficient for single-node HIE deployments |
| Auth bridge token | base64 JSON | Simplifies dev/prod parity while real JWT validation is built |
| Blocking strategy | Pre-computed keys | O(k×log n + c) vs O(n) full scan — enables $match at scale |
| Dedup grouping | Union-Find | Handles transitive duplicates (A=B, B=C → A=B=C) efficiently |
