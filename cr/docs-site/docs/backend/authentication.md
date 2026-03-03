---
sidebar_position: 2
title: Authentication
---

# Authentication

The system supports two authentication modes: **Asgardeo** (production) and **Simulated** (development). The mode is selected automatically based on environment variables in the frontend.

## Authentication Modes

### Asgardeo (WSO2 Identity Provider)

When `VITE_ASGARDEO_CLIENT_ID` and `VITE_ASGARDEO_BASE_URL` are set in `cr-frontend/.env`, the app uses [WSO2 Asgardeo](https://wso2.com/asgardeo/) for authentication via OpenID Connect.

**Flow:**
1. User visits the app → `ProtectedRoute` redirects to `/login`
2. User clicks "Sign in with Asgardeo" → redirected to Asgardeo hosted login page
3. After successful login → Asgardeo redirects back to the app origin
4. The `@asgardeo/react` SDK reads the session and populates user info (SCIM2 profile)
5. `AuthContext` creates a **bridge token** (base64-encoded `{ sub, role, exp }`) for backend compatibility
6. Token and user info are synced to `localStorage` for the API client to use
7. On sign-out → Asgardeo session is cleared and user is redirected to the app origin

### Simulated (Development Mode)

When Asgardeo env vars are not set, the app uses a simulated auth provider. Any email/password combination is accepted, and the user is assigned the `admin` role automatically.

## Token Format

The backend (`cr-core`) expects a `Authorization: Bearer <token>` header where `<token>` is a **base64-encoded JSON** string:

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
The backend will validate real Asgardeo JWTs via the JWKS endpoint in a future phase, replacing the bridge token approach.
:::

## Asgardeo Setup (Production)

1. Create a free account at [Asgardeo Console](https://console.asgardeo.io)
2. Create a **Single Page Application** in your Asgardeo organization
3. Configure the application:
   - **Authorized Redirect URL**: `http://localhost:5173` (or your production URL)
   - **Allowed Logout URL**: `http://localhost:5173` (must match `afterSignOutUrl`)
4. Copy `cr-frontend/.env.example` to `cr-frontend/.env` and fill in:
   ```env
   VITE_ASGARDEO_CLIENT_ID=your-client-id
   VITE_ASGARDEO_BASE_URL=https://api.asgardeo.io/t/your-org-name
   ```
5. (Optional) For role-based access control:
   - Create groups `admin` and `viewer` in Asgardeo
   - Assign users to appropriate groups
   - Enable the `groups` claim in the application's **User Attributes**

## Role-Based Access Control

| Role | Label | Source |
|------|-------|--------|
| `admin` | MPI Admin | User belongs to the `admin` group in Asgardeo; or any user in simulated mode |
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
| `cr-frontend/src/config/auth.js` | Asgardeo SDK configuration and `isAsgardeoEnabled` flag |
| `cr-frontend/src/auth/AuthContext.jsx` | Dual-mode auth provider with bridge token creation |
| `cr-frontend/src/auth/ProtectedRoute.jsx` | Route guard redirecting unauthenticated users to `/login` |
| `cr-frontend/src/api/client.js` | API client attaching `Authorization` and `X-User-Id` headers |
| `cr-frontend/src/pages/LoginPage.jsx` | Login UI (Asgardeo button or simulated form) |
| `cr-frontend/.env.example` | Template for Asgardeo environment variables |
| `cr-core/auth.bal` | Backend token parsing and authorization logic |
