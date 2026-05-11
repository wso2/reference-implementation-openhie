---
sidebar_position: 1
title: Overview
---

# Audit Service Overview

Ballerina FHIR AuditEvent service implementing IHE ATNA (ITI-20). Receives structured `AuditEvent` resources from the MPI backend (`cr-core`), persists them to a log file, and exposes a query API for the frontend.

## Key Capabilities

- **`POST /audits`** — Write a FHIR `AuditEvent` (called by `cr-core` after each patient operation)
- **`GET /audits`** — Read audit events with filtering and pagination (used by the frontend Audit page)
- Events are appended to a **NDJSON** log file (one JSON object per line)
- Failed writes are **buffered in-memory** and retried every 30 seconds

## Running

```bash
cd audit-service
bal run
# Listening on http://localhost:9093
```

Start the audit service **before** `cr-core`, so that audit events emitted on startup are not lost.

## Source Files

```
audit-service/
├── Ballerina.toml   # Package metadata and distribution version
├── service.bal      # HTTP service (GET + POST /audits, retry task)
├── records.bal      # Internal InternalAuditEvent record type
├── tests/           # Service tests
└── oas/
    └── AuditServiceAPI.yaml  # OpenAPI 3.0.0 specification
```

## Tests

```bash
cd audit-service
bal test
```

## OpenAPI Specification

The full OpenAPI 3.0.0 spec is available at:
`audit-service/oas/AuditServiceAPI.yaml`

## Related Pages

- [Configuration](configuration) — Config keys for log path, cache, and observer settings
- [Audit API Reference](../api-reference/audit-api) — Full endpoint documentation with examples
