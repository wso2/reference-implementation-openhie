---
sidebar_position: 2
title: Authentication
---

# Authentication

The system supports two authentication modes: **OIDC** (production) and **Simulated** (development). The mode is explicitly configured in `cr-frontend/.env` — the app will not start without it.

## Authentication Modes

### OIDC (Any OIDC-Compliant Provider)

When `VITE_AUTH_MODE=oidc` is set along with `VITE_OIDC_CLIENT_ID` and `VITE_OIDC_AUTHORITY` in `cr-frontend/.env`, the app uses any standard OIDC identity provider (Asgardeo, Keycloak, Auth0, Okta, Azure AD, etc.) for authentication.

**Flow:**
1. User visits the app → `ProtectedRoute` redirects to `/login`
2. User clicks "Sign in" → redirected to the IdP hosted login page
3. After successful login → IdP redirects back to the app origin
4. The `react-oidc-context` library reads the session and populates user info from standard OIDC claims
5. `AuthContext` creates a **bridge token** (base64-encoded `{ sub, role, exp }`) for backend compatibility
6. Token and user info are synced to `localStorage` for the API client to use
7. On sign-out → IdP session is cleared and user is redirected to the app origin

### Simulated (Development Mode)

When `VITE_AUTH_MODE=simulated` is set, the app uses a local email/password form. Any combination is accepted, and the user is assigned the `admin` role automatically.

## Token Format

The backend (`cr-core`) expects an `Authorization: Bearer <token>` header where `<token>` is a **base64-encoded JSON** string:

```json
{
  "sub": "user@example.com",
  "role": "admin",
  "exp": 9999999999999
}
```

### Generate a Test Token

```bash
TOKEN=$(echo -n '{"sub":"admin@example.com","role":"admin","exp":9999999999999}' | base64)
echo $TOKEN
```

Use this token in all API calls:

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:9090/fhir/r4/Patient?family=Silva
```

:::info Future improvement
The backend will validate real OIDC JWTs via the JWKS endpoint in a future phase, replacing the bridge token approach.
:::

## OIDC Setup (Production)

1. Register a **Single Page Application** (SPA) in your identity provider
2. Configure the application:
   - **Authorized Redirect URL**: `http://localhost:5173` (or your production URL)
   - **Allowed Logout URL**: `http://localhost:5173`
3. Copy `cr-frontend/.env.example` to `cr-frontend/.env` and fill in:
   ```env
   VITE_AUTH_MODE=oidc
   VITE_OIDC_CLIENT_ID=your-client-id
   VITE_OIDC_AUTHORITY=https://your-oidc-provider-base-url
   ```
4. (Optional) For role-based access control:
   - Configure your IdP to include a `groups` claim in the ID token
   - Create groups `admin` and `viewer` and assign users accordingly

Provider-specific `VITE_OIDC_AUTHORITY` examples:

| Provider | Authority URL |
|----------|--------------|
| Asgardeo | `https://api.asgardeo.io/t/your-org-name` |
| Keycloak | `https://your-keycloak-host/realms/your-realm` |
| Auth0 | `https://your-tenant.auth0.com` |
| Okta | `https://your-org.okta.com/oauth2/default` |
| Azure AD | `https://login.microsoftonline.com/your-tenant-id/v2.0` |

## Role-Based Access Control

| Role | Label | Source |
|------|-------|--------|
| `admin` | MPI Admin | User belongs to the `admin` group in the IdP; or any user in simulated mode |
| `viewer` | MPI Viewer | Default when no groups are configured, or user is not in `admin` group |

### Endpoint Permissions

| Endpoint | Method | Allowed Roles |
|----------|--------|---------------|
| `GET /Patient` | Search | `admin`, `viewer` |
| `GET /Patient/{id}` | Read | `admin`, `viewer` |
| `POST /Patient/$match` | Match | `admin`, `viewer` |
| `PUT /Patient?identifier=...` | Create/Update | `admin` only |
| `DELETE /Patient?identifier=...` | Delete | `admin` only |
| `GET /Patient/dedupstart` | Start dedup | `admin`, `viewer` |
| `GET /Patient/dedupstatus` | Poll dedup | `admin`, `viewer` |
| `GET /Patient/dedup` | Get dedup results | `admin`, `viewer` |
| `GET /Patient/dedupreject` | Reject match | `admin` only |
| `GET /metadata` | Capability statement | No auth required |

## Key Source Files

| File | Purpose |
|------|---------|
| `cr-frontend/src/config/auth.js` | Auth mode validation; `authMode` and `authConfigError` exports |
| `cr-frontend/src/auth/AuthContext.jsx` | Dual-mode auth provider (OIDC / simulated) with bridge token creation |
| `cr-frontend/src/auth/ProtectedRoute.jsx` | Route guard redirecting unauthenticated users to `/login` |
| `cr-frontend/src/api/client.js` | API client attaching `Authorization` and `X-User-Id` headers |
| `cr-frontend/src/pages/LoginPage.jsx` | Login UI (OIDC redirect button or simulated form) |
| `cr-frontend/.env.example` | Template for environment variables |
| `cr-core/auth.bal` | Backend token parsing and authorization logic |
