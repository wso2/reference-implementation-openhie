---
sidebar_position: 3
title: Authentication
---

# Frontend Authentication

The frontend supports two authentication modes selected automatically based on environment variables.

## Development Mode (Simulated)

No configuration needed. Any credentials are accepted at the login screen. All users receive the `admin` role.

```bash
# Just start the dev server — no .env setup required
cd cr-frontend
npm run dev
# Login with any email + password at http://localhost:5173
```

## Production Mode (Asgardeo)

### Setup Steps

1. Create a [free Asgardeo account](https://console.asgardeo.io)
2. Create a **Single Page Application** in your organization
3. Configure the application:
   - **Authorized Redirect URL**: your app origin (e.g. `http://localhost:5173`)
   - **Allowed Logout URL**: same as above
4. Copy `.env.example` to `.env` and fill in:

```env
VITE_ASGARDEO_CLIENT_ID=your-client-id
VITE_ASGARDEO_BASE_URL=https://api.asgardeo.io/t/your-org-name
```

### (Optional) Role-Based Access via Groups

1. Create groups named `admin` and `viewer` in Asgardeo
2. Assign users to appropriate groups
3. Enable the `groups` **User Attribute** on the application in Asgardeo Console

The `viewer` role is the default when no groups are configured.

## Role Permissions

| Role | Label | Permissions |
|------|-------|-------------|
| `admin` | MPI Admin | Full access: create, edit, delete, merge, run dedup, reject matches |
| `viewer` | MPI Viewer | Read-only: search, view, run $match, view dedup results |

## How the Bridge Token Works

When a user signs in via Asgardeo, `AuthContext.jsx` creates a **bridge token** — a base64-encoded JSON object — from the Asgardeo session:

```json
{
  "sub": "user@example.com",
  "role": "admin",
  "exp": 1999999999999
}
```

This token is stored in `localStorage` and attached to all API requests as `Authorization: Bearer <token>`. The backend (`cr-core/auth.bal`) decodes this token to authorize requests.

:::info
A future phase will replace the bridge token with real Asgardeo JWT validation via the JWKS endpoint.
:::
