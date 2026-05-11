# OpenHIE Reference Implementation

This repository contains the reference implementation of the OpenHIE architecture — a set of interoperable health information services that collectively enable standards-based health data exchange across a Health Information Exchange (HIE).

## Repository Structure

```
reference-implementation-openhie/
├── iol/          # Interoperability Layer (IOL)
└── cr/           # Client Registry (MPI)
```

## Components

### Interoperability Layer (`iol/`)

The IOL is the central message broker and routing engine of the HIE. It receives incoming FHIR and HL7v2 messages, routes them to the appropriate downstream services, and publishes audit events.

| Service | Description | Port |
|---|---|---|
| `iol-core/` | Core message router (HTTP + TCP listeners) | 9080 / 9081 |
| `audit-service/` | Audit event logging and OpenSearch publishing | 9091 |
| `websubhub/hub/` | WebSub event hub for pub/sub notifications | 9095 |
| `fhir-workflows/` | FHIR workflow services (e.g. patient demographics) | — |
| `opensearch/` | OpenSearch dashboard configuration | 5601 |

See [iol/README.md](iol/README.md) for setup and running instructions.

---

### Client Registry (`cr/`)

The CR is a standards-based **Master Patient Index (MPI)** that manages FHIR R4 `Patient` resources within the HIE. It implements IHE PDQm/PIXm transactions with intelligent patient matching, deduplication, and a management UI.

| Service | Description | Port |
|---|---|---|
| `cr-core/` | Ballerina FHIR R4 backend (MPI service) | 9090 |
| `audit-service/` | FHIR AuditEvent service (IHE ATNA) | 9093 |
| `cr-frontend/` | React management UI | 5173 |
| `documentation/` | Docusaurus documentation site | — |

See [cr/README.md](cr/README.md) for setup and running instructions.

---

## Quick Start

### Run the IOL

```bash
cd iol
bash setup.sh
```

### Run the Client Registry

```bash
cd cr
bash start.sh
```

---

## Docker

Both components ship with Docker support for containerised deployment.

### Client Registry — Docker Compose

The CR `docker-compose.yml` starts the full stack (PostgreSQL + audit service + CR core + frontend) with health-checked startup ordering:

```bash
cd cr
docker compose up --build
```

| Container | Image | Port |
|---|---|---|
| `postgres` | `postgres:16` | 5432 |
| `audit-service` | built from `cr/audit-service/Dockerfile` | 9096 |
| `core` | built from `cr/cr-core/Dockerfile` | 9090 |
| `frontend` | built from `cr/cr-frontend/Dockerfile` | 80 |

The frontend container is served on port **80** when running via Docker (instead of 5173 in dev mode).

### IOL — OpenSearch via Docker Compose

The IOL uses Docker Compose only for the OpenSearch cluster and dashboard:

```bash
cd iol/opensearch
docker compose up
```

| Container | Port |
|---|---|
| `opensearch-node1` | 9200, 9600 |
| `opensearch-node2` | — |
| `opensearch-dashboards` | 5601 |

OpenSearch credentials:
```
Username: admin
Password: openHIEdemo!123
```

Access the dashboard at `http://localhost:5601` — use the **Global** tenant and navigate to **Dashboards → openhie-ref-impl**.

### Building Individual Docker Images

Each CR service has its own Dockerfile and can be built independently:

```bash
# CR Core
docker build -t cr-core ./cr/cr-core

# CR Audit Service
docker build -t cr-audit-service ./cr/audit-service

# CR Frontend
docker build -t cr-frontend ./cr/cr-frontend
```

---

## Prerequisites

| Requirement | Details |
|---|---|
| [Ballerina](https://ballerina.io/downloads/) | Swan Lake (tested on 2201.13.1) |
| [Docker](https://www.docker.com/products/docker-desktop/) | Required for OpenSearch (IOL) and full CR stack |
| [Node.js](https://nodejs.org/) 18+ | For the CR Frontend (local dev only) |
| [npm](https://www.npmjs.com/) 9+ | For the CR Frontend (local dev only) |
| [Git Bash](https://git-scm.com/downloads) | **Windows only** — required to run `.sh` scripts |

> **Windows users:** Run scripts with `bash` (Git Bash), not `sh` or PowerShell.
