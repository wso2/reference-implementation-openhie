/**
 * Authentication configuration.
 *
 * VITE_AUTH_MODE must be set in your .env file:
 *   VITE_AUTH_MODE=oidc        — use any OIDC-compliant provider (Asgardeo, Keycloak, Auth0, Okta, ...)
 *   VITE_AUTH_MODE=simulated   — use dev email/password login
 *
 * The app will not start if this variable is missing or invalid.
 * See .env.example for full setup instructions.
 */

export type AuthMode = 'oidc' | 'simulated';

const rawMode = import.meta.env.VITE_AUTH_MODE?.trim().toLowerCase();
const VALID_MODES: AuthMode[] = ['oidc', 'simulated'];

let _authConfigError: string | null = null;

if (!rawMode) {
  _authConfigError =
    'VITE_AUTH_MODE is not set. Set it to "oidc" or "simulated" in your .env file.';
} else if (!VALID_MODES.includes(rawMode as AuthMode)) {
  _authConfigError = `VITE_AUTH_MODE="${rawMode}" is not valid. Use "oidc" or "simulated".`;
} else if (rawMode === 'oidc') {
  const missing = [
    !import.meta.env.VITE_OIDC_CLIENT_ID && 'VITE_OIDC_CLIENT_ID',
    !import.meta.env.VITE_OIDC_AUTHORITY && 'VITE_OIDC_AUTHORITY',
  ].filter(Boolean);
  if (missing.length) {
    _authConfigError = `VITE_AUTH_MODE=oidc requires: ${missing.join(', ')}`;
  }
}

/** Non-null when auth is misconfigured; contains a human-readable message. */
export const authConfigError: string | null = _authConfigError;

/** 'oidc' | 'simulated' | null (null only when authConfigError is set) */
export const authMode: AuthMode | null = _authConfigError ? null : (rawMode as AuthMode);

// Build scope: base is always openid profile email; add extras if the IdP requires them
// e.g. Asgardeo needs "groups" to include group membership in the token
const _extraScopes = import.meta.env.VITE_OIDC_EXTRA_SCOPES?.trim() || '';
const _scope = ['openid', 'profile', 'email', _extraScopes].filter(Boolean).join(' ');

// Redirect URIs — configurable for providers that require an exact callback path
const _redirectUri =
  import.meta.env.VITE_OIDC_REDIRECT_URI?.trim() || window.location.origin;
const _postLogoutRedirectUri =
  import.meta.env.VITE_OIDC_POST_LOGOUT_REDIRECT_URI?.trim() || window.location.origin;

/**
 * ID token claim that contains group membership.
 * Default: "groups" (Asgardeo, Keycloak, Okta).
 * Override with VITE_OIDC_GROUPS_CLAIM for Auth0 custom claims or other providers.
 */
export const groupsClaim: string = import.meta.env.VITE_OIDC_GROUPS_CLAIM?.trim() || 'groups';

const _metadataUrl: string | undefined = import.meta.env.VITE_OIDC_METADATA_URL?.trim() || undefined;

/** Standard OIDC config — works with any OIDC-compliant provider. */
export const oidcConfig = {
  authority: import.meta.env.VITE_OIDC_AUTHORITY as string,
  client_id: import.meta.env.VITE_OIDC_CLIENT_ID as string,
  redirect_uri: _redirectUri,
  post_logout_redirect_uri: _postLogoutRedirectUri,
  scope: _scope,
  // Fetch additional profile claims (email, name, etc.) from the userinfo endpoint.
  // Many providers (including Asgardeo) only include basic claims in the ID token;
  // the full profile is available via userinfo.
  loadUserInfo: true,
  ...(_metadataUrl && { metadataUrl: _metadataUrl }),
};
