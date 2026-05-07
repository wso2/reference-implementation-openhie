import { useState, useCallback } from 'react';
import type { UserPreferences } from '../types';

const STORAGE_KEY = 'user_preferences';

export const defaultPreferences: UserPreferences = {
  defaultPageSize: 10,
  dateFormat: 'relative',
  auditAutoRefresh: true,
  auditRefreshInterval: 30,
  identifierSystemBaseUrl: '',
};

/** Plain (non-React) helper to read preferences — safe to call inside hooks/intervals. */
export function getPreferences(): UserPreferences {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored ? { ...defaultPreferences, ...JSON.parse(stored) } : { ...defaultPreferences };
  } catch {
    return { ...defaultPreferences };
  }
}

export function useUserPreferences() {
  const [preferences, setPreferences] = useState<UserPreferences>(getPreferences);

  const updatePreference = useCallback(<K extends keyof UserPreferences>(key: K, value: UserPreferences[K]) => {
    setPreferences((prev) => {
      const updated = { ...prev, [key]: value };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
      return updated;
    });
  }, []);

  const resetPreferences = useCallback(() => {
    localStorage.removeItem(STORAGE_KEY);
    setPreferences({ ...defaultPreferences });
  }, []);

  return { preferences, updatePreference, resetPreferences };
}
