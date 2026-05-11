---
sidebar_position: 1
title: Prerequisites
---

# Prerequisites

Before running the OpenHIE Client Registry, ensure the following tools are installed.

## Required Tools

| Tool | Version | Install |
|------|---------|---------|
| [Ballerina](https://ballerina.io/downloads/) | **2201.13.1** (Swan Lake Update 13) | [ballerina.io/downloads](https://ballerina.io/downloads/) |
| [Node.js](https://nodejs.org/) | **18+** | [nodejs.org](https://nodejs.org/) |
| npm | **9+** | Bundled with Node.js |

## Verify Installation

```bash
# Check Ballerina version
bal version
# Expected: Ballerina 2201.13.1 (Swan Lake Update 13)

# Check Node.js version
node --version
# Expected: v18.x.x or higher

# Check npm version
npm --version
# Expected: 9.x.x or higher
```

## No External Database Required

The H2 database is **embedded** — it is automatically created at `cr-core/data/mpi.mv.db` on first run. No database server installation is needed.

## Network Ports

Ensure the following ports are available on your machine:

| Service | Port |
|---------|------|
| cr-core (MPI Backend) | 9090 |
| audit-service | 9093 |
| cr-frontend (dev server) | 5173 |

## Next Step

→ [Quick Start](quick-start)
