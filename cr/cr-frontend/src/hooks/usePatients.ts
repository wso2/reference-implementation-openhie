import { useState, useCallback } from 'react';
import { listPatients as apiListPatients } from '../api/patientService';
import { ApiError } from '../api/client';
import type { FhirPatient, ListPatientsParams } from '../types';

export function usePatients(initialPageSize = 20) {
  const [patients, setPatients] = useState<FhirPatient[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(initialPageSize);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchPage = useCallback(async (pageNum: number, size: number, filters: ListPatientsParams = {}) => {
    setLoading(true);
    setError(null);
    try {
      const result = await apiListPatients({ page: pageNum, pageSize: size, ...filters });
      setPatients(result.patients || []);
      setTotal(result.total || 0);
      setPage(result.page || pageNum);
      setPageSize(result.pageSize || size);
    } catch (err) {
      const message =
        err instanceof ApiError
          ? (err.body as { issue?: { diagnostics?: string }[] })?.issue?.[0]?.diagnostics || err.message
          : (err as Error).message;
      setError(message);
    } finally {
      setLoading(false);
    }
  }, []);

  const search = useCallback(
    (filters: ListPatientsParams = {}) => fetchPage(1, pageSize, filters),
    [fetchPage, pageSize]
  );

  const goToPage = useCallback(
    (newPage: number, filters: ListPatientsParams = {}) => fetchPage(newPage, pageSize, filters),
    [fetchPage, pageSize]
  );

  const changePageSize = useCallback(
    (newSize: number, filters: ListPatientsParams = {}) => {
      setPageSize(newSize);
      return fetchPage(1, newSize, filters);
    },
    [fetchPage]
  );

  const totalPages = Math.ceil(total / pageSize);

  return { patients, total, page, pageSize, totalPages, loading, error, search, goToPage, changePageSize };
}
