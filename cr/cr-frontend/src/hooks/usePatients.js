import { useState, useCallback } from 'react';
import { listPatients as apiListPatients } from '../api/patientService';
import { ApiError } from '../api/client';

export function usePatients(initialPageSize = 20) {
  const [patients, setPatients] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(initialPageSize);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchPage = useCallback(async (pageNum, size, filters = {}) => {
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
          ? err.body?.issue?.[0]?.diagnostics || err.message
          : err.message;
      setError(message);
    } finally {
      setLoading(false);
    }
  }, []);

  const search = useCallback(
    (filters = {}) => fetchPage(1, pageSize, filters),
    [fetchPage, pageSize]
  );

  const goToPage = useCallback(
    (newPage, filters = {}) => fetchPage(newPage, pageSize, filters),
    [fetchPage, pageSize]
  );

  const totalPages = Math.ceil(total / pageSize);

  return { patients, total, page, pageSize, totalPages, loading, error, search, goToPage, setPageSize: setPageSize };
}
