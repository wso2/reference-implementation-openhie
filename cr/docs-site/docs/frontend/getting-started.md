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

Copy `.env.example` to `.env` and set `VITE_AUTH_MODE` before starting — the app will not load without it.

For local development, set `VITE_AUTH_MODE=simulated` and log in with **any** email and password — the simulated auth grants the `admin` role automatically.

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
| `VITE_AUTH_MODE` | **Yes** | Authentication mode: `"oidc"` or `"simulated"`. App will not start without this. |
| `VITE_OIDC_CLIENT_ID` | When `VITE_AUTH_MODE=oidc` | Client ID registered in your identity provider |
| `VITE_OIDC_AUTHORITY` | When `VITE_AUTH_MODE=oidc` | OIDC issuer base URL (e.g. `https://api.asgardeo.io/t/myorg`) |

Copy `cr-frontend/.env.example` to `cr-frontend/.env` and fill in values.

## Authentication Modes

See [Frontend Authentication](authentication) for detailed setup of both OIDC (production) and simulated (development) modes, including provider-specific examples.
