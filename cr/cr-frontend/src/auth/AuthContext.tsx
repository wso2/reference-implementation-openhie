import { createContext, useContext, useState, useCallback, useEffect, useMemo } from 'react';
import { useAuth as useOidcAuth } from 'react-oidc-context';
import { authMode, groupsClaim } from '../config/auth';
import type { AuthUser, AuthContextType } from '../types';

const AuthContext = createContext<AuthContextType | null>(null);

function createBridgeToken(email: string, role: string): string {
  return btoa(
    JSON.stringify({ sub: email, role, exp: Date.now() + 86400000 })
  );
}

function mapGroupsToRole(groups: string[]): 'admin' | 'viewer' {
  if (!groups || !Array.isArray(groups) || groups.length === 0) return 'admin';
  return groups.some((g) => g.toLowerCase() === 'admin') ? 'admin' : 'viewer';
}

function safeStr(val: unknown): string {
  if (typeof val === 'string') return val;
  if (Array.isArray(val)) return (val[0] as string) || '';
  return '';
}

function getInitials(name: string, email: string): string {
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
function OidcAuthProvider({ children }: { children: React.ReactNode }) {
  const oidc = useOidcAuth();
  const [loginError, setLoginError] = useState<string | null>(null);

  const user = useMemo((): AuthUser | null => {
    if (!oidc.isAuthenticated || !oidc.user) return null;

    const p = oidc.user.profile;

    const email = safeStr(p.email)
      || safeStr(p.preferred_username)
      || safeStr((p as Record<string, unknown>).username)
      || safeStr((p as Record<string, unknown>).upn)
      || safeStr(p.sub)
      || '';
    const givenName = safeStr(p.given_name);
    const familyName = safeStr(p.family_name);
    const displayName = safeStr(p.name);
    const name = displayName
      || [givenName, familyName].filter(Boolean).join(' ')
      || safeStr((p as Record<string, unknown>).username)
      || '';
    const groups = Array.isArray((p as Record<string, unknown>)[groupsClaim])
      ? (p as Record<string, unknown>)[groupsClaim] as string[]
      : [];
    const role = mapGroupsToRole(groups);

    if (!p.email && !p.preferred_username && !(p as Record<string, unknown>).username && !p.name) {
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

  const token = useMemo((): string | null => {
    if (!user) return null;
    return createBridgeToken(user.email, user.role);
  }, [user]);

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
      setLoginError((err as Error)?.message || 'Sign-in failed. Check your OIDC configuration.');
    }
  }, [oidc]);

  const logout = useCallback(() => {
    oidc.signoutRedirect();
  }, [oidc]);

  const value = useMemo(
    (): AuthContextType => ({
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
function SimulatedAuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => {
    const stored = localStorage.getItem('auth_user');
    return stored ? (JSON.parse(stored) as AuthUser) : null;
  });

  const [token, setToken] = useState<string | null>(() => localStorage.getItem('auth_token'));

  const login = useCallback(async (email: string = '', _password?: string) => {
    const fakeToken = createBridgeToken(email, 'admin');
    const userObj: AuthUser = {
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
    (): AuthContextType => ({
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
export function AuthProvider({ children }: { children: React.ReactNode }) {
  if (authMode === 'oidc') {
    return <OidcAuthProvider>{children}</OidcAuthProvider>;
  }
  return <SimulatedAuthProvider>{children}</SimulatedAuthProvider>;
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}
