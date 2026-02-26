import { useState, useCallback, useEffect, useRef } from 'react';
import { fetchAuditLogs as apiFetchAuditLogs } from '../api/auditService';

const POLL_INTERVAL = 30000; // 30 seconds
const DEFAULT_LIMIT = 50;

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
      setHasMore(data.length === DEFAULT_LIMIT);
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
        setLogs(prev => [...prev, ...result]);
        offsetRef.current += result.length;
        setHasMore(result.length === DEFAULT_LIMIT);
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
            setLogs(prev => [...result, ...prev]);
            // Don't change offsetRef — polling prepends, doesn't affect pagination position
          }
        })
        .catch(() => {
          // Silent fail on polling
        });
    }, POLL_INTERVAL);

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [sortOrder]); // stable deps — no logs dependency

  return { logs, loading, loadingMore, error, hasMore, sortOrder, fetchLogs, loadMore, toggleSort };
}
