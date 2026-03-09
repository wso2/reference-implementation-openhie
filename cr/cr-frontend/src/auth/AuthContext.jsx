import { createContext, useContext, useState, useCallback, useEffect, useMemo } from 'react';
import { useAuth as useOidcAuth } from 'react-oidc-context';
import { authMode, groupsClaim } from '../config/auth';

const AuthContext = createContext(null);

/**
 * Creates a bridge token in the format the backend expects (base64-encoded JSON).
 * Phase 2 will migrate the backend to validate real OIDC JWTs directly.
 */
function createBridgeToken(email, role) {
  return btoa(
    JSON.stringify({ sub: email, role, exp: Date.now() + 86400000 })
  );
}

/**
 * Maps OIDC groups claim to application roles.
 * Users in the "admin" group get the admin role; everyone else is a viewer.
 */
function mapGroupsToRole(groups) {
  if (!groups || !Array.isArray(groups) || groups.length === 0) return 'admin';
  return groups.some((g) => g.toLowerCase() === 'admin') ? 'admin' : 'viewer';
}

/** Safely extract a string value (OIDC claims may return objects or arrays). */
function safeStr(val) {
  if (typeof val === 'string') return val;
  if (Array.isArray(val)) return val[0] || '';
  return '';
}

function getInitials(name, email) {
  if (typeof name === 'string' && name.trim()) {
    const parts = name.trim().split(/\s+/);
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }
  if (typeof email === 'string' && email) {
    return email.substring(0, 2).toUpperCase();
  }
  return 'U';
}

// ---------------------------------------------------------------------------
// OIDC-backed AuthProvider (works with any OIDC-compliant provider)
// ---------------------------------------------------------------------------
function OidcAuthProvider({ children }) {
  const oidc = useOidcAuth();
  const [loginError, setLoginError] = useState(null);

  const user = useMemo(() => {
    if (!oidc.isAuthenticated || !oidc.user) return null;

    const p = oidc.user.profile;

    // Standard OIDC claims + common provider-specific alternatives:
    //   email, preferred_username, username (Asgardeo), upn (Azure AD)
    const email = safeStr(p.email)
      || safeStr(p.preferred_username)
      || safeStr(p.username)
      || safeStr(p.upn)
      || safeStr(p.sub)
      || '';
    const givenName = safeStr(p.given_name);
    const familyName = safeStr(p.family_name);
    const displayName = safeStr(p.name);
    const name = displayName
      || [givenName, familyName].filter(Boolean).join(' ')
      || safeStr(p.username)
      || '';
    const groups = Array.isArray(p[groupsClaim]) ? p[groupsClaim] : [];
    const role = mapGroupsToRole(groups);

    // Warn when the provider didn't return usable profile claims
    if (!p.email && !p.preferred_username && !p.username && !p.name) {
      console.warn(
        '[AuthContext] OIDC profile is missing email/name claims. '
        + 'Ensure your IdP application is configured to share email and profile '
        + 'user attributes (e.g. Asgardeo → Application → User Attributes).\n'
        + 'Available claims:', Object.keys(p),
      );
    }

    return {
      email,
      name: name || (email.includes('@') ? email.split('@')[0] : ''),
      initials: getInitials(name, email),
      role,
      groups,
    };
  }, [oidc.isAuthenticated, oidc.user]);

  const token = useMemo(() => {
    if (!user) return null;
    return createBridgeToken(user.email, user.role);
  }, [user]);

  // Sync bridge token & user to localStorage so the API client (client.js)
  // can read them without needing React context access.
  useEffect(() => {
    if (token && user) {
      localStorage.setItem('auth_token', token);
      localStorage.setItem('auth_user', JSON.stringify(user));
    } else {
      localStorage.removeItem('auth_token');
      localStorage.removeItem('auth_user');
    }
  }, [token, user]);

  const login = useCallback(async () => {
    setLoginError(null);
    try {
      await oidc.signinRedirect();
    } catch (err) {
      setLoginError(err?.message || 'Sign-in failed. Check your OIDC configuration.');
    }
  }, [oidc]);

  const logout = useCallback(() => {
    oidc.signoutRedirect();
  }, [oidc]);

  const value = useMemo(
    () => ({
      user,
      token,
      isAuthenticated: oidc.isAuthenticated,
      isLoading: oidc.isLoading,
      error: oidc.error?.message || loginError,
      login,
      logout,
    }),
    [user, token, oidc.isAuthenticated, oidc.isLoading, oidc.error, loginError, login, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// ---------------------------------------------------------------------------
// Simulated AuthProvider (dev mode — requires VITE_AUTH_MODE=simulated)
// ---------------------------------------------------------------------------
function SimulatedAuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const stored = localStorage.getItem('auth_user');
    return stored ? JSON.parse(stored) : null;
  });

  const [token, setToken] = useState(() => localStorage.getItem('auth_token'));

  const login = useCallback(async (email, _password) => {
    const fakeToken = createBridgeToken(email, 'admin');
    const userObj = {
      email,
      name: email.split('@')[0],
      initials: email.substring(0, 2).toUpperCase(),
      role: 'admin',
    };

    localStorage.setItem('auth_token', fakeToken);
    localStorage.setItem('auth_user', JSON.stringify(userObj));
    setToken(fakeToken);
    setUser(userObj);
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');
    setToken(null);
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({
      user,
      token,
      isAuthenticated: !!token,
      isLoading: false,
      error: null,
      login,
      logout,
    }),
    [user, token, login, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------
export function AuthProvider({ children }) {
  if (authMode === 'oidc') {
    return <OidcAuthProvider>{children}</OidcAuthProvider>;
  }
  return <SimulatedAuthProvider>{children}</SimulatedAuthProvider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}
