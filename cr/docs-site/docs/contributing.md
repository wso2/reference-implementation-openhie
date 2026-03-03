---
sidebar_position: 99
title: Contributing
---

# Contributing

## Development Setup

### Prerequisites

Follow the [Prerequisites](getting-started/prerequisites) guide to install Ballerina 2201.13.1 and Node.js 18+.

### Start All Services

```bash
# Terminal 1 — Audit service
cd audit-service && bal run

# Terminal 2 — MPI backend
cd cr-core && bal run

# Terminal 3 — Frontend
cd cr-frontend && npm install && npm run dev
```

## Running Tests

### cr-core (Backend)

```bash
cd cr-core
bal test
```

Test files:
- `tests/iti78_test.bal` — ITI-78 search/read compliance tests
- `tests/matching_test.bal` — Matching algorithm unit tests

### audit-service

```bash
cd audit-service
bal test
```

### cr-frontend (Linting)

```bash
cd cr-frontend
npm run lint
```

There are currently no Jest/Vitest unit tests for the frontend — contributions welcome.

## Git Workflow

1. Fork the repository and create a branch from `main`
2. Branch naming: `feat/description`, `fix/description`, `docs/description`
3. Make changes with focused, single-purpose commits
4. Run tests before opening a PR
5. Open a pull request against `main` with a clear description

## Code Style

### Ballerina

- Follow [Ballerina style guide](https://ballerina.io/learn/style-guide/)
- Use descriptive variable names
- Add function documentation with `///` doc comments for public functions

### Frontend (JavaScript/React)

- ESLint is configured in `cr-frontend/eslint.config.js`
- Use `npm run lint` to check before committing
- Follow the existing component pattern: custom hook for data, component for presentation

## Project Structure Summary

| Directory | Language | Responsibility |
|-----------|----------|---------------|
| `cr-core/` | Ballerina | FHIR MPI backend, matching, dedup, auth |
| `audit-service/` | Ballerina | FHIR AuditEvent receiver + query service |
| `cr-frontend/` | React 19 | Management UI |
| `docs-site/` | Docusaurus | This documentation site |

## Areas for Contribution

- **Backend JWT validation** — Replace bridge token with real Asgardeo JWT validation via JWKS
- **Frontend tests** — Add Vitest + Testing Library unit tests for components and hooks
- **CI/CD pipeline** — GitHub Actions for test + build on PRs
- **OpenAPI spec for cr-core** — Generate or write OpenAPI 3.0.0 spec for the FHIR endpoints
- **Docker Compose** — Containerize all three services for easy deployment
- **PostgreSQL support** — Add a PostgreSQL repository implementation alongside H2

## Reporting Issues

Open an issue on GitHub with:
1. The affected component (`cr-core`, `audit-service`, `cr-frontend`)
2. Steps to reproduce
3. Expected vs actual behaviour
4. Relevant log output
