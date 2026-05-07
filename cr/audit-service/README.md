# OpenHIE Client Registry — Audit Service

Ballerina FHIR AuditEvent service implementing IHE ATNA (ITI-20). Receives structured `AuditEvent` resources from the MPI backend, persists them to a log file, and exposes a query API for the frontend.

## Overview

- **POST /audits** — Write a FHIR `AuditEvent` (called by `cr-core` after each patient operation)
- **GET /audits** — Read audit events with filtering and pagination (used by the frontend Audit page)
- Events are appended to a NDJSON log file (one JSON object per line)
- Failed writes are buffered in-memory and retried every 30 seconds

## Running

```bash
cd audit-service
bal run
# Listening on http://localhost:9093
```

## Configuration

Edit `Ballerina.toml` or pass as environment variables:

| Config Key | Default | Description |
|------------|---------|-------------|
| `auditLogPath` | `/tmp/audit-logs/fhir-audit.log` | Path to the NDJSON audit log file |
| `cacheCapacity` | `1000` | Max failed events to buffer for retry |
| `fhirServerName` | `wso2fhirserver.com` | Source observer name used to filter framework-generated events |
| `agentType` | `humanuser` | Default agent type in audit events |

## API

### POST /audits

Accepts a FHIR R4 `AuditEvent` resource and appends it to the log file.

- Returns `200 OK` with the stored `AuditEvent` (with `id` assigned if not provided)
- Returns `202 Accepted` if the write fails but the event is buffered for retry
- Returns `500 Internal Server Error` if both write and cache fail

```bash
curl -X POST http://localhost:9093/audits \
  -H "Content-Type: application/json" \
  -d '{
    "resourceType": "AuditEvent",
    "type": {"system": "http://terminology.hl7.org/CodeSystem/audit-event-type", "code": "rest"},
    "action": "C",
    "outcome": "0",
    "recorded": "2025-01-01T00:00:00Z",
    "agent": [{"requestor": true, "who": {"display": "admin@example.com"}}],
    "source": {"observer": {"display": "client-registry"}},
    "entity": []
  }'
```

### GET /audits

Query audit events from the log file with optional filtering.

**Query parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `action` | string | Filter by FHIR action code (`C`, `R`, `U`, `D`, `E`) |
| `subtype` | string | Filter by subtype code (e.g. `create`, `read`, `search-type`) |
| `since` | string | ISO 8601 timestamp — return events recorded after this time |
| `before` | string | ISO 8601 timestamp — return events recorded before this time |
| `limit` | int | Max events to return (default: 50) |
| `offset` | int | Number of events to skip (default: 0) |
| `sortOrder` | string | `desc` (newest first, default) or `asc` |

Events with `source.observer.display == fhirServerName` (framework-generated) are automatically excluded from results.

```bash
# Get the 20 most recent audit events
curl "http://localhost:9093/audits?limit=20"

# Get create events since a timestamp
curl "http://localhost:9093/audits?action=C&since=2025-01-01T00:00:00Z"

# Paginate
curl "http://localhost:9093/audits?limit=50&offset=50"
```

## File Structure

```
audit-service/
├── Ballerina.toml   # Package metadata and distribution version
├── service.bal      # HTTP service (GET + POST /audits, retry task)
├── records.bal      # Internal InternalAuditEvent record type
└── tests/           # Service tests
```
