---
sidebar_position: 3
title: Authentication
---

# Frontend Authentication

The frontend supports two authentication modes. The mode must be explicitly configured in `.env` — the app will not start without it.

## OIDC Mode (Production)

Use any OIDC-compliant identity provider: Asgardeo, Keycloak, Auth0, Okta, Azure AD, etc.

### Setup Steps

1. Register a **Single Page Application** (SPA) in your identity provider
2. Configure the application:
   - **Authorized Redirect URL**: your app origin (e.g. `http://localhost:5173`)
   - **Allowed Logout URL**: same as above
3. Copy `.env.example` to `.env` and fill in:

```env
VITE_AUTH_MODE=oidc
VITE_OIDC_CLIENT_ID=your-client-id
VITE_OIDC_AUTHORITY=https://your-oidc-provider-base-url
```

Provider-specific `VITE_OIDC_AUTHORITY` examples:

| Provider | Authority URL |
|----------|--------------|
| Asgardeo | `https://api.asgardeo.io/t/your-org-name` |
| Keycloak | `https://your-keycloak-host/realms/your-realm` |
| Auth0 | `https://your-tenant.auth0.com` |
| Okta | `https://your-org.okta.com/oauth2/default` |
| Azure AD | `https://login.microsoftonline.com/your-tenant-id/v2.0` |

The library auto-discovers provider metadata from `{VITE_OIDC_AUTHORITY}/.well-known/openid-configuration`.

### (Optional) Role-Based Access via Groups

1. Configure your IdP to include a `groups` claim in the ID token
2. Create groups named `admin` and `viewer` and assign users accordingly

The `viewer` role is the default when no groups are configured.

## Simulated Mode (Development)

For local development without an IdP. Any email and password are accepted; all users receive the `admin` role.

```env
VITE_AUTH_MODE=simulated
```

```bash
# Copy .env.example, set VITE_AUTH_MODE=simulated, then:
cd cr-frontend
npm run dev
# Login with any email + password at http://localhost:5173
```

## Role Permissions

| Role | Label | Permissions |
|------|-------|-------------|
| `admin` | MPI Admin | Full access: create, edit, delete, merge, run dedup, reject matches |
| `viewer` | MPI Viewer | Read-only: search, view, run $match, view dedup results |

## How the Bridge Token Works

When a user signs in via OIDC, `AuthContext.jsx` creates a **bridge token** — a base64-encoded JSON object — from the OIDC session:

```json
{
  "sub": "user@example.com",
  "role": "admin",
  "exp": 1999999999999
}
```

This token is stored in `localStorage` and attached to all API requests as `Authorization: Bearer <token>`. The backend (`cr-core/auth.bal`) decodes this token to authorize requests.

:::info
A future phase will replace the bridge token with real OIDC JWT validation via the JWKS endpoint.
:::
