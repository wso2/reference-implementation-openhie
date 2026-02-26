import { useState, useCallback, useEffect, useRef } from 'react';
import { startDedupJob, getDedupJobStatus, getLatestDedupResults, rejectDedupMatch } from '../api/matchService';
import { resolvePatient } from '../api/patientService';

const SESSION_KEY = 'matchGroups';
const POLL_INTERVAL_MS = 2000;
const MAX_POLL_DURATION_MS = 5 * 60 * 1000; // 5 minutes

function loadFromSession() {
  try {
    const stored = sessionStorage.getItem(SESSION_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch {
    return [];
  }
}

export function useMatchGroups() {
  const [matchGroups, setMatchGroups] = useState(loadFromSession);
  useEffect(() => {
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(matchGroups));
  }, [matchGroups]);

  const [loading, setLoading] = useState(false);
  const [merging, setMerging] = useState(false);
  const [error, setError] = useState(null);
  const [dedupStatus, setDedupStatus] = useState(null); // 'pending' | 'running' | 'completed' | 'failed'

  const mountedRef = useRef(true);
  const pollTimerRef = useRef(null);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      if (pollTimerRef.current) clearTimeout(pollTimerRef.current);
    };
  }, []);

  const pollJob = useCallback((startTime) => {
    if (!mountedRef.current) return;

    // Timeout check
    if (Date.now() - startTime > MAX_POLL_DURATION_MS) {
      setError('Deduplication is taking too long. Please try again later.');
      setLoading(false);
      setDedupStatus(null);
      return;
    }

    pollTimerRef.current = setTimeout(async () => {
      if (!mountedRef.current) return;
      try {
        const status = await getDedupJobStatus();
        if (!mountedRef.current) return;

        setDedupStatus(status.status);

        if (status.status === 'completed') {
          // Fetch full results from the dedup endpoint
          const results = await getLatestDedupResults();
          if (!mountedRef.current) return;
          setMatchGroups(results?.groups || []);
          setLoading(false);
          setDedupStatus(null);
          return;
        }
        if (status.status === 'failed') {
          setError(status.error || 'Deduplication failed');
          setLoading(false);
          setDedupStatus(null);
          return;
        }
        // Still running — poll again
        pollJob(startTime);
      } catch (err) {
        if (!mountedRef.current) return;
        // 404 means no jobs found
        if (err.status === 404) {
          setError('Dedup job was lost (server may have restarted). Please run again.');
        } else {
          setError(err.message);
        }
        setLoading(false);
        setDedupStatus(null);
      }
    }, POLL_INTERVAL_MS);
  }, []);

  const runDedup = useCallback(async () => {
    setLoading(true);
    setError(null);
    setDedupStatus('pending');
    try {
      await startDedupJob();
      setDedupStatus('running');
      pollJob(Date.now());
    } catch (err) {
      // 409 Conflict — a job is already running, resume polling it
      if (err.status === 409) {
        setDedupStatus('running');
        pollJob(Date.now());
      } else {
        setError(err.message);
        setLoading(false);
        setDedupStatus(null);
      }
    }
  }, [pollJob]);

  /**
   * Approve a match group: mark subsumed patients as inactive via ITI-104 Resolve Duplicate.
   * The surviving patient is patients[0]; all others are subsumed.
   */
  const approveGroup = useCallback(async (groupId, resolvedBy) => {
    const group = matchGroups.find((g) => g.id === groupId);
    if (!group || group.patients.length < 2) return;

    setMerging(true);
    setError(null);

    try {
      const survivingPatient = group.patients[0];
      const survivingId = survivingPatient.identifier?.[0];
      if (!survivingId) throw new Error('Surviving patient has no identifier');

      // For each subsumed patient (all except first), call resolve
      const subsumedPatients = group.patients.slice(1);
      await Promise.all(
        subsumedPatients.map((p) =>
          resolvePatient(p, {
            system: survivingId.system,
            value: survivingId.value,
          })
        )
      );

      // Update local state
      setMatchGroups((prev) =>
        prev.map((g) =>
          g.id === groupId
            ? {
                ...g,
                status: 'approved',
                resolvedAt: new Date().toISOString(),
                resolvedBy,
              }
            : g
        )
      );
    } catch (err) {
      setError(err.message);
    } finally {
      setMerging(false);
    }
  }, [matchGroups]);

  const rejectGroup = useCallback(async (groupId, resolvedBy) => {
    const group = matchGroups.find((g) => g.id === groupId);
    if (!group || group.patients.length < 2) return;

    setError(null);

    try {
      // Call backend for each pair in the group to persist exclusion codes
      const patients = group.patients;
      const rejectPromises = [];
      for (let i = 0; i < patients.length; i++) {
        for (let j = i + 1; j < patients.length; j++) {
          rejectPromises.push(
            rejectDedupMatch(patients[i].id, patients[j].id)
          );
        }
      }
      await Promise.all(rejectPromises);

      // Update local state
      setMatchGroups((prev) =>
        prev.map((g) =>
          g.id === groupId
            ? {
                ...g,
                status: 'rejected',
                resolvedAt: new Date().toISOString(),
                resolvedBy,
              }
            : g
        )
      );
    } catch (err) {
      setError(err.message);
    }
  }, [matchGroups]);

  /**
   * Remove specific patients from a group (mark as unique / after partial merge).
   * If <2 patients remain, auto-resolve the group.
   */
  const removeFromGroup = useCallback((groupId, patientIdsToRemove) => {
    setMatchGroups((prev) =>
      prev.map((g) => {
        if (g.id !== groupId) return g;
        const remaining = g.patients.filter(
          (p) => !patientIdsToRemove.includes(p.id)
        );
        if (remaining.length < 2) {
          return {
            ...g,
            patients: remaining,
            status: 'resolved',
            resolvedAt: new Date().toISOString(),
          };
        }
        return { ...g, patients: remaining };
      })
    );
  }, []);

  /**
   * Merge a subset of patients within a group, then remove merged patients from group.
   * patients[0] of the subset is the surviving patient; rest are subsumed.
   */
  const mergeSubset = useCallback(async (groupId, patientsToMerge, resolvedBy) => {
    if (patientsToMerge.length < 2) return;

    setMerging(true);
    setError(null);

    try {
      const survivingPatient = patientsToMerge[0];
      const survivingId = survivingPatient.identifier?.[0];
      if (!survivingId) throw new Error('Surviving patient has no identifier');

      const subsumedPatients = patientsToMerge.slice(1);
      await Promise.all(
        subsumedPatients.map((p) =>
          resolvePatient(p, {
            system: survivingId.system,
            value: survivingId.value,
          })
        )
      );

      // Remove all merged patients (including surviving) from the group
      const mergedIds = patientsToMerge.map((p) => p.id);
      removeFromGroup(groupId, mergedIds);
    } catch (err) {
      setError(err.message);
    } finally {
      setMerging(false);
    }
  }, [removeFromGroup]);

  return {
    matchGroups, loading, merging, error,
    dedupStatus,
    runDedup, approveGroup, rejectGroup, removeFromGroup, mergeSubset,
  };
}
