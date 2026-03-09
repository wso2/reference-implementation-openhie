import { useState, useCallback, useEffect, useRef } from 'react';
import { startDedupJob, pollDedupStatus, rejectDedupMatch } from '../api/matchService';
import { resolvePatient } from '../api/patientService';

const SESSION_KEY = 'matchGroups';
const LAST_RUN_KEY = 'dedupLastRunTime';

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

  const [merging, setMerging] = useState(false);
  const [isStarting, setIsStarting] = useState(false);     // dedupstart request in flight
  const [isRetrieving, setIsRetrieving] = useState(false); // dedupstatus request in flight
  const [isJobRunning, setIsJobRunning] = useState(false); // server confirmed job is running (202)
  const [startError, setStartError] = useState(null);
  const [retrieveError, setRetrieveError] = useState(null);
  const [mergeError, setMergeError] = useState(null);
  const [lastRunTime, setLastRunTime] = useState(
    () => sessionStorage.getItem(LAST_RUN_KEY) || null
  );

  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    return () => { mountedRef.current = false; };
  }, []);

  // Fire-and-forget: start the dedup job, return immediately. No polling.
  const runDedup = useCallback(async () => {
    setIsStarting(true);
    setStartError(null);
    try {
      await startDedupJob(); // 202 for both fresh start and already-running
      setIsJobRunning(true);
    } catch (err) {
      setStartError(err.message);
    } finally {
      if (mountedRef.current) setIsStarting(false);
    }
  }, []);

  // One-shot fetch: check dedupstatus once, load results if ready.
  const retrieveResults = useCallback(async () => {
    setIsRetrieving(true);
    setRetrieveError(null);
    try {
      const { done, result } = await pollDedupStatus('/Patient/dedupstatus');
      if (!mountedRef.current) return;
      if (done) {
        setMatchGroups(result?.groups || []);
        setIsJobRunning(false);
        const runTime = result?.timestamp || new Date().toISOString();
        setLastRunTime(runTime);
        sessionStorage.setItem(LAST_RUN_KEY, runTime);
      } else {
        // 202 — job still running on server
        setIsJobRunning(true);
        setRetrieveError('Deduplication is still in progress. Please try again later.');
      }
    } catch (err) {
      if (!mountedRef.current) return;
      if (err.status === 404) {
        setRetrieveError('No deduplication data found. Run the process first.');
      } else if (err.status === 500) {
        setRetrieveError('The last deduplication run failed on the server. Run it again.');
      } else {
        setRetrieveError(err.message);
      }
    } finally {
      if (mountedRef.current) setIsRetrieving(false);
    }
  }, []);

  /**
   * Approve a match group: mark subsumed patients as inactive via ITI-104 Resolve Duplicate.
   * The surviving patient is patients[0]; all others are subsumed.
   */
  const approveGroup = useCallback(async (groupId, resolvedBy) => {
    const group = matchGroups.find((g) => g.id === groupId);
    if (!group || group.patients.length < 2) return;

    setMerging(true);
    setMergeError(null);

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
      setMergeError(err.message);
    } finally {
      setMerging(false);
    }
  }, [matchGroups]);

  const rejectGroup = useCallback(async (groupId, resolvedBy) => {
    const group = matchGroups.find((g) => g.id === groupId);
    if (!group || group.patients.length < 2) return;

    setMergeError(null);

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
      setMergeError(err.message);
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
    setMergeError(null);

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
      setMergeError(err.message);
    } finally {
      setMerging(false);
    }
  }, [removeFromGroup]);

  return {
    matchGroups, merging,
    isStarting, isRetrieving, isJobRunning,
    startError, retrieveError, mergeError,
    lastRunTime,
    runDedup, retrieveResults,
    approveGroup, rejectGroup, removeFromGroup, mergeSubset,
  };
}
