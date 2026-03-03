---
sidebar_position: 2
title: Configuration
---

# Audit Service Configuration

Edit `audit-service/Ballerina.toml` or pass values as environment variables at startup.

## Config Keys

| Key | Default | Description |
|-----|---------|-------------|
| `auditLogPath` | `/tmp/audit-logs/fhir-audit.log` | Path to the NDJSON audit log file. The directory is created automatically if it does not exist. |
| `cacheCapacity` | `1000` | Maximum number of failed audit events to hold in the in-memory retry buffer |
| `fhirServerName` | `wso2fhirserver.com` | Source observer name used to **filter out** framework-generated events from `GET /audits` results |
| `agentType` | `humanuser` | Default agent type label used in audit event records |

## Retry Behaviour

If writing to the log file fails (e.g., disk full, permission error):
1. The event is buffered in-memory (up to `cacheCapacity` events)
2. A background task retries the write every **30 seconds**
3. `POST /audits` returns `202 Accepted` when the event is buffered, or `500` if the buffer is also full

## NDJSON Log Format

Each line in the log file is a JSON-serialized FHIR `AuditEvent` resource:

```json
{"resourceType":"AuditEvent","id":"uuid","type":{"system":"...","code":"rest"},"action":"C","outcome":"0","recorded":"2025-01-01T00:00:00Z","agent":[{"requestor":true,"who":{"display":"admin@example.com"}}],"source":{"observer":{"display":"client-registry"}},"entity":[]}
```

## cr-core Configuration

The MPI backend (`cr-core`) is configured to point at the audit service via `cr-core/config.toml`:

```toml
auditServiceUrl = "http://localhost:9093"
auditEnabled = true
sourceObserverName = "client-registry"
```

Set `auditEnabled = false` in `cr-core/config.toml` to disable audit event emission without stopping the audit service.
