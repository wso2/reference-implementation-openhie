---
slug: /
sidebar_position: 1
title: Introduction
---

# OpenHIE Client Registry

A standards-based **Master Patient Index (MPI)** implementation for health information exchanges (HIEs). Stores FHIR R4 `Patient` resources with IHE PDQm/PIXm transaction support, blocking-based patient matching, incremental deduplication, and a full-featured management UI.

## Components

| Component | Description | Port |
|-----------|-------------|------|
| `cr-core/` | Ballerina FHIR R4 backend (MPI service) | **9090** |
| `audit-service/` | Ballerina FHIR AuditEvent service (IHE ATNA) | **9093** |
| `cr-frontend/` | React management UI | **5173** |

## Supported IHE Profiles

| Profile | Transaction | Description |
|---------|-------------|-------------|
| **ITI-78** | Patient Demographics Query | Search and read patient records |
| **ITI-104** | Patient Identity Feed | Create, update, delete, merge patients |
| **ITI-119** | Patient Demographics Match | Probabilistic patient matching |
| **ITI-20** | Audit Record Repository | FHIR AuditEvent logging (ATNA) |

## Key Features

- **ITI-78** — Patient Demographics Query (search by demographics, read by ID)
- **ITI-104** — Patient Identity Feed (conditional PUT upsert, soft delete, merge via `replaced-by` link)
- **ITI-119** — Blocking-accelerated probabilistic matching with configurable field weights and algorithms
- **Deduplication** — Async, incremental, blocking-based dedup with Union-Find grouping
- **Match Rejection** — Admins can reject false-positive pairs; rejected pairs are excluded from future dedup runs
- **Audit Trail** — FHIR AuditEvent logging for all patient operations (IHE ATNA ITI-20)
- **Blocking Strategy** — Pre-computed indexed keys reduce candidate sets from millions to ~10–500 per query
- **Authentication** — Asgardeo (WSO2 IdP) in production, simulated auth in development

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Backend | [Ballerina](https://ballerina.io/) 2201.13.1 (Swan Lake Update 13) |
| FHIR Library | `ballerinax/health.fhirr4` 3.0.2 |
| Database | H2 2.2.224 (embedded, auto-created) |
| Frontend | React 19, Vite 7, WSO2 Oxygen UI |
| Auth (prod) | WSO2 Asgardeo (OIDC / SCIM2) |

## Where to Go Next

- **New to the project?** → [Quick Start](getting-started/quick-start)
- **Deploying or configuring?** → [Configuration Reference](backend/configuration)
- **Calling the API?** → [FHIR API Reference](api-reference/fhir-endpoints)
- **Understanding the architecture?** → [System Overview](architecture/overview)
- **Seeing it in action?** → [Demo Scenarios](guides/demo-scenarios)
