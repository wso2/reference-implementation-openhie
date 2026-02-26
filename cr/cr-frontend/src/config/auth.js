/**
 * Asgardeo authentication configuration.
 *
 * Set VITE_ASGARDEO_CLIENT_ID and VITE_ASGARDEO_BASE_URL in a .env file
 * to enable Asgardeo authentication. When these are not set, the app
 * falls back to simulated (dev-mode) authentication.
 *
 * See .env.example for details.
 */
export const asgardeoConfig = {
  clientId: import.meta.env.VITE_ASGARDEO_CLIENT_ID,
  baseUrl: import.meta.env.VITE_ASGARDEO_BASE_URL,
  scopes: ['openid', 'profile', 'email', 'groups'],
  afterSignInUrl: window.location.origin,
  afterSignOutUrl: window.location.origin,
};

/** True when Asgardeo env vars are configured */
export const isAsgardeoEnabled =
  !!asgardeoConfig.clientId && !!asgardeoConfig.baseUrl;
