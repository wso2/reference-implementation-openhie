import { createContext, useContext, useState, useCallback, useEffect, useMemo } from 'react';
import { useAsgardeo } from '@asgardeo/react';
import { isAsgardeoEnabled } from '../config/auth';

const AuthContext = createContext(null);

/**
 * Creates a bridge token in the format the backend expects (base64-encoded JSON).
 * Phase 2 will migrate the backend to validate real Asgardeo JWTs directly.
 */
function createBridgeToken(email, role) {
  return btoa(
    JSON.stringify({ sub: email, role, exp: Date.now() + 86400000 })
  );
}

/**
 * Maps Asgardeo groups to application roles.
 * Users in the "admin" group get the admin role; everyone else is a viewer.
 */
function mapGroupsToRole(groups) {
  if (!groups || !Array.isArray(groups) || groups.length === 0) return 'admin';
  return groups.some((g) => g.toLowerCase() === 'admin') ? 'admin' : 'viewer';
}

/** Safely extract a string value (Asgardeo may return objects or arrays). */
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
// Asgardeo-backed AuthProvider
// ---------------------------------------------------------------------------
function AsgardeoAuthProvider({ children }) {
  const asgardeo = useAsgardeo();

  const user = useMemo(() => {
    if (!asgardeo.isSignedIn || !asgardeo.user) return null;

    const u = asgardeo.user;

    // Asgardeo SCIM2 user object fields:
    //   userName: "user@org.com"
    //   name: { givenName: "...", familyName: "..." }
    //   displayName, email, groups — may or may not be present
    const email = safeStr(u.email) || safeStr(u.userName) || safeStr(u.username) || safeStr(u.sub) || '';
    const givenName = safeStr(u.givenName) || safeStr(u.name?.givenName);
    const familyName = safeStr(u.familyName) || safeStr(u.name?.familyName);
    const displayName = safeStr(u.displayName);
    const name = displayName || [givenName, familyName].filter(Boolean).join(' ') || '';
    const groups = Array.isArray(u.groups) ? u.groups : [];
    const role = mapGroupsToRole(groups);

    return {
      email,
      name: name || (typeof email === 'string' ? email.split('@')[0] : ''),
      initials: getInitials(name, email),
      role,
      groups,
    };
  }, [asgardeo.isSignedIn, asgardeo.user]);

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

  const login = useCallback(() => {
    asgardeo.signIn();
  }, [asgardeo]);

  const logout = useCallback(() => {
    asgardeo.signOut();
  }, [asgardeo]);

  const value = useMemo(
    () => ({
      user,
      token,
      isAuthenticated: asgardeo.isSignedIn,
      isLoading: asgardeo.isLoading,
      login,
      logout,
    }),
    [user, token, asgardeo.isSignedIn, asgardeo.isLoading, login, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// ---------------------------------------------------------------------------
// Simulated AuthProvider (fallback for dev without Asgardeo)
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
  if (isAsgardeoEnabled) {
    return <AsgardeoAuthProvider>{children}</AsgardeoAuthProvider>;
  }
  return <SimulatedAuthProvider>{children}</SimulatedAuthProvider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}
