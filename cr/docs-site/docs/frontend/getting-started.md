---
sidebar_position: 2
title: Getting Started
---

# Frontend — Getting Started

## Prerequisites

- Node.js 18+
- The MPI backend (`cr-core`) running on port 9090
- The audit service (`audit-service`) running on port 9093

## Run in Development

```bash
cd cr-frontend
npm install
npm run dev
# App at http://localhost:5173
```

In development (no Asgardeo env vars set), log in with **any** email and password — the simulated auth grants the `admin` role automatically.

## Build for Production

```bash
cd cr-frontend
npm run build
# Output in dist/
```

Serve the `dist/` directory with any static file server or reverse proxy (nginx, Caddy, etc.).

## Lint

```bash
npm run lint
```

Uses ESLint with the config in `cr-frontend/eslint.config.js`.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `VITE_ASGARDEO_CLIENT_ID` | No | Asgardeo SPA client ID. Leave blank for simulated auth. |
| `VITE_ASGARDEO_BASE_URL` | No | Asgardeo API base URL (e.g. `https://api.asgardeo.io/t/myorg`). Leave blank for simulated auth. |

Copy `cr-frontend/.env.example` to `cr-frontend/.env` and fill in values for production use.

## Authentication Modes

See [Frontend Authentication](authentication) for detailed setup of both development (simulated) and production (Asgardeo) modes.
