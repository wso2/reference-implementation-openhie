import { useState, useCallback, useEffect, useRef } from 'react';
import { fetchAuditLogs as apiFetchAuditLogs } from '../api/auditService';
import { getPreferences } from './useUserPreferences';
const DEFAULT_LIMIT = 50;
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

// Module-level cache — survives component unmount/remount
const _cache = new Map();

function _key(filters, sortOrder) {
  const { subtype = null, since = null, before = null } = filters || {};
  return `${sortOrder}:${JSON.stringify({ subtype, since, before })}`;
}

function _get(key) {
  const e = _cache.get(key);
  if (!e) return null;
  if (Date.now() - e.cachedAt > CACHE_TTL) { _cache.delete(key); return null; }
  return e;
}

function _set(key, logs, offset, hasMore) {
  _cache.set(key, { logs, offset, hasMore, cachedAt: Date.now() });
}

export function useAuditLog() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState(null);
  const [hasMore, setHasMore] = useState(true);
  const [sortOrder, setSortOrder] = useState('desc');

  const filtersRef = useRef({});
  const intervalRef = useRef(null);
  const offsetRef = useRef(0);
  const logsRef = useRef([]);
  const sortOrderRef = useRef(sortOrder);

  // Keep refs in sync
  logsRef.current = logs;
  sortOrderRef.current = sortOrder;

  const fetchLogs = useCallback(async (filters = {}) => {
    filtersRef.current = filters;
    const cacheKey = _key(filters, sortOrderRef.current);
    const cached = _get(cacheKey);

    if (cached) {
      // Instant restore from cache — no loading spinner
      setLogs(cached.logs);
      offsetRef.current = cached.offset;
      setHasMore(cached.hasMore);

      // Background refresh: silently fetch new items since the newest cached log
      if (sortOrderRef.current === 'desc' && !filters.since && !filters.before) {
        const newestTs = cached.logs.length > 0 ? cached.logs[0].timestamp : undefined;
        if (newestTs) {
          apiFetchAuditLogs({ ...filters, limit: DEFAULT_LIMIT, offset: 0, sortOrder: 'desc', since: newestTs })
            .then(result => {
              if (Array.isArray(result) && result.length > 0) {
                setLogs(prev => {
                  const updated = [...result, ...prev];
                  _set(cacheKey, updated, cached.offset + result.length, cached.hasMore);
                  return updated;
                });
              }
            })
            .catch(() => {});
        }
      }
      return;
    }

    // Cache miss — full fetch
    offsetRef.current = 0;
    setLoading(true);
    setError(null);
    try {
      const result = await apiFetchAuditLogs({
        ...filters,
        limit: DEFAULT_LIMIT,
        offset: 0,
        sortOrder: sortOrderRef.current,
      });
      const data = Array.isArray(result) ? result : [];
      setLogs(data);
      offsetRef.current = data.length;
      const more = data.length === DEFAULT_LIMIT;
      setHasMore(more);
      _set(cacheKey, data, data.length, more);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []); // stable reference — reads sortOrder from ref

  const loadMore = useCallback(async () => {
    if (!hasMore || loadingMore) return;
    setLoadingMore(true);
    setError(null);
    try {
      const result = await apiFetchAuditLogs({
        ...filtersRef.current,
        limit: DEFAULT_LIMIT,
        offset: offsetRef.current,
        sortOrder: sortOrderRef.current,
      });
      if (Array.isArray(result)) {
        const newOffset = offsetRef.current + result.length;
        const newHasMore = result.length === DEFAULT_LIMIT;
        offsetRef.current = newOffset;
        setHasMore(newHasMore);
        setLogs(prev => {
          const updated = [...prev, ...result];
          _set(_key(filtersRef.current, sortOrderRef.current), updated, newOffset, newHasMore);
          return updated;
        });
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingMore(false);
    }
  }, [hasMore, loadingMore]);

  const toggleSort = useCallback(() => {
    setSortOrder(prev => {
      const next = prev === 'desc' ? 'asc' : 'desc';
      sortOrderRef.current = next;
      return next;
    });
  }, []);

  // Re-fetch when sortOrder changes
  useEffect(() => {
    fetchLogs(filtersRef.current);
  }, [sortOrder]); // eslint-disable-line react-hooks/exhaustive-deps

  // Poll for new audit events (only in desc mode, without date range filter)
  useEffect(() => {
    if (sortOrder !== 'desc') return;

    const { auditAutoRefresh, auditRefreshInterval } = getPreferences();
    if (!auditAutoRefresh) return;

    intervalRef.current = setInterval(() => {
      // Skip polling when a date range filter is active
      const filters = filtersRef.current;
      if (filters.since || filters.before) return;

      const currentLogs = logsRef.current;
      const newestTimestamp = currentLogs.length > 0 ? currentLogs[0].timestamp : undefined;

      const params = {
        ...filters,
        limit: DEFAULT_LIMIT,
        offset: 0,
        sortOrder: 'desc',
      };
      if (newestTimestamp) {
        params.since = newestTimestamp;
      }

      apiFetchAuditLogs(params)
        .then((result) => {
          if (Array.isArray(result) && result.length > 0) {
            setLogs(prev => {
              const updated = [...result, ...prev];
              const cacheKey = _key(filters, sortOrderRef.current);
              const existing = _get(cacheKey);
              if (existing) _set(cacheKey, updated, existing.offset, existing.hasMore);
              return updated;
            });
          }
        })
        .catch(() => {
          // Silent fail on polling
        });
    }, auditRefreshInterval * 1000);

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [sortOrder]); // stable deps — no logs dependency

  return { logs, loading, loadingMore, error, hasMore, sortOrder, fetchLogs, loadMore, toggleSort };
}
