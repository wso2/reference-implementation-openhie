---
sidebar_position: 2
title: Quick Start
---

# Quick Start

Start all three services in separate terminals. The order matters: start the audit service first, then the MPI backend, then the frontend.

## Step 1 — Start the Audit Service

```bash
cd audit-service
bal run
# Listening on http://localhost:9093
```

## Step 2 — Start the MPI Backend

```bash
cd cr-core
bal run
# Service starts at http://localhost:9090/fhir/r4
```

On first run, the H2 database is automatically created at `cr-core/data/mpi.mv.db`. All tables are created via DDL on startup.

## Step 3 — Start the Frontend

```bash
cd cr-frontend
npm install
npm run dev
# App at http://localhost:5173
```

## Log In

Open [http://localhost:5173](http://localhost:5173) in your browser.

Before logging in, copy `cr-frontend/.env.example` to `cr-frontend/.env` and set `VITE_AUTH_MODE`.

- **Development**: set `VITE_AUTH_MODE=simulated` and enter any email and password — all users receive the `admin` role automatically.
- **Production**: set `VITE_AUTH_MODE=oidc` and fill in `VITE_OIDC_CLIENT_ID` + `VITE_OIDC_AUTHORITY`.

:::tip Production authentication
See [Frontend Authentication](../frontend/authentication) for OIDC setup with any identity provider.
:::

## Verify the Backend

Check that the FHIR capability statement is reachable:

```bash
curl http://localhost:9090/fhir/r4/metadata
```

Expected: a FHIR `CapabilityStatement` resource (JSON).

## Seed Sample Data

To populate the registry with sample patients for testing:

```bash
# Small set of patients
bash seed-patients.sh

# Patients with duplicate groups (for dedup demo)
bash seed-dedup-scenarios.sh
```

See [Seeding Data](seeding-data) for all seed script options.

## Next Steps

- [Seeding Data](seeding-data) — Populate the registry with test patients
- [Demo Scenarios](../guides/demo-scenarios) — Walk through patient lifecycle and deduplication
- [FHIR API Reference](../api-reference/fhir-endpoints) — Explore all endpoints
