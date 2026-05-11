---
sidebar_position: 2
title: Audit API
---

# Audit Service API Reference

**Base URL:** `http://localhost:9093`

The OpenAPI 3.0.0 specification is available at `audit-service/oas/AuditServiceAPI.yaml`.

---

## `POST /audits` — Write Audit Event

Accepts a FHIR R4 `AuditEvent` resource and appends it to the log file.

**Request Body:** `application/json` — FHIR `AuditEvent` resource

**Responses:**
| Status | Description |
|--------|-------------|
| `200 OK` | Event written successfully. Returns the stored `AuditEvent` with `id` assigned. |
| `202 Accepted` | Write failed; event buffered for retry. |
| `500 Internal Server Error` | Both write and buffer failed. |

```bash
curl -X POST http://localhost:9093/audits \
  -H "Content-Type: application/json" \
  -d '{
    "resourceType": "AuditEvent",
    "type": {
      "system": "http://terminology.hl7.org/CodeSystem/audit-event-type",
      "code": "rest"
    },
    "action": "C",
    "outcome": "0",
    "recorded": "2025-01-01T00:00:00Z",
    "agent": [{"requestor": true, "who": {"display": "admin@example.com"}}],
    "source": {"observer": {"display": "client-registry"}},
    "entity": []
  }'
```

### Action Codes

| Code | Meaning |
|------|---------|
| `C` | Create |
| `R` | Read |
| `U` | Update |
| `D` | Delete |
| `E` | Execute |

---

## `GET /audits` — Query Audit Events

Read audit events from the log file with optional filtering and pagination.

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `action` | string | — | Filter by FHIR action code (`C`, `R`, `U`, `D`, `E`) |
| `subtype` | string | — | Filter by subtype code (e.g. `create`, `read`, `search-type`) |
| `since` | string (ISO 8601) | — | Return events recorded **after** this time |
| `before` | string (ISO 8601) | — | Return events recorded **before** this time |
| `limit` | integer | `50` | Maximum events to return |
| `offset` | integer | `0` | Number of events to skip |
| `sortOrder` | string | `desc` | `desc` (newest first) or `asc` (oldest first) |

Events with `source.observer.display == fhirServerName` (framework-generated) are automatically excluded.

```bash
# Get the 20 most recent events
curl "http://localhost:9093/audits?limit=20"

# Get create events since a timestamp
curl "http://localhost:9093/audits?action=C&since=2025-01-01T00:00:00Z"

# Get all updates in a time window
curl "http://localhost:9093/audits?action=U&since=2025-01-01T00:00:00Z&before=2025-02-01T00:00:00Z"

# Paginate through all events
curl "http://localhost:9093/audits?sortOrder=asc&limit=100&offset=0"
curl "http://localhost:9093/audits?sortOrder=asc&limit=100&offset=100"
```

**Returns:** JSON array of `AuditEvent` resources.

---

## AuditEvent Schema

```yaml
AuditEvent:
  type: object
  properties:
    id:
      type: string (uuid)
    type:
      $ref: Coding          # e.g. { system: "...", code: "rest" }
    subtype:
      type: array
      items: Coding         # e.g. [{ code: "create" }]
    action:
      type: string          # C | R | U | D | E
    outcome:
      type: string          # "0" = success
    recorded:
      type: string (date-time)
    agent:
      type: array
      items:
        type:     Coding
        who:      { display: string }
        requestor: boolean
    source:
      observer: { display: string }
    entity:
      type: array
      items:
        type: Coding
        role: Coding
        what: { reference: string }
```

## Internal Record Format

The audit service internally maps incoming FHIR `AuditEvent` resources to an `InternalAuditEvent` record for efficient filtering:

| Field | Type | Description |
|-------|------|-------------|
| `typeCode` | string | Event type code |
| `subTypeCode` | string | Event subtype code |
| `actionCode` | string | Action code (C/R/U/D/E) |
| `outcomeCode` | string | Outcome code |
| `recordedTime` | date-time | When the event was recorded |
| `agentType` | string | Type of agent |
| `agentName` | string | Agent identifier (e.g. email) |
| `agentIsRequestor` | boolean | Whether the agent initiated the request |
| `entityType` | string | Entity type |
| `entityRole` | string | Entity role |
| `entityWhatReference` | string | Reference to the affected resource |
| `sourceObserverName` | string | Observer name (used to filter framework events) |
| `sourceObserverType` | string | Observer type |
