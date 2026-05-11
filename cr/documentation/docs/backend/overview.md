---
sidebar_position: 1
title: Overview
---

# MPI Backend Overview (`cr-core`)

The `cr-core` service is the core of the Client Registry. It is a Ballerina FHIR R4 service that implements the Master Patient Index (MPI) functions: patient storage, search, probabilistic matching, and deduplication.

## Key Capabilities

- **Patient CRUD** — Create, read, update, soft-delete patients via FHIR R4 resources
- **Conditional PUT** — Identifier-based upsert (ITI-104 patient identity feed)
- **Patient Search** — 14 search parameters across demographics and identifiers (ITI-78)
- **Probabilistic Match** — Blocking-accelerated `$match` with configurable algorithms (ITI-119)
- **Deduplication Pipeline** — Async incremental dedup with Union-Find grouping
- **Audit Emission** — Automatically emits FHIR AuditEvents to `audit-service` after each operation

## Service Startup

```bash
cd cr-core
bal run
# Service starts at http://localhost:9090/fhir/r4
```

## Source Files

| File | Purpose |
|------|---------|
| `main.bal` | FHIR service definition, HTTP routes, request dispatch |
| `db_repository.bal` | All H2 database operations (queries, upserts, schema init) |
| `matching.bal` | Blocking key computation, scoring algorithms, dedup pipeline |
| `auth.bal` | Token parsing, role extraction, authorization checks |
| `audit_client.bal` | HTTP client that sends AuditEvent to the audit service |
| `api_config.bal` | FHIR API configuration (capability statement, resource types) |
| `config.toml` | Runtime configuration (DB, audit URL, matching thresholds) |

## Tests

```bash
# Run all cr-core tests
cd cr-core
bal test
```

Test files:
- `tests/iti78_test.bal` — ITI-78 search and read compliance tests
- `tests/matching_test.bal` — Matching algorithm unit tests
- `tests/compliance/` — Compliance test fixtures

## Related Pages

- [Authentication](authentication) — Token format, roles, Asgardeo setup
- [Deduplication](deduplication) — Full dedup pipeline walkthrough
- [Configuration](configuration) — All `config.toml` settings
- [FHIR API Reference](../api-reference/fhir-endpoints) — All endpoints with examples
