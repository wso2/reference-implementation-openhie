import { useState, useEffect, useCallback, Fragment } from 'react';
import {
  Box,
  Typography,
  CircularProgress,
  Alert,
  Chip,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  ListingTable,
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
  TablePagination,
} from '@wso2/oxygen-ui';

import StatsGrid from '../components/StatsGrid';
import PatientSearchPanel from '../components/PatientSearchPanel';
import PatientViewDialog from '../components/PatientViewDialog';
import PatientInlineEditForm from '../components/PatientInlineEditForm';
import PatientMatchDialog from '../components/PatientMatchDialog';
import NotificationSnackbar from '../components/NotificationSnackbar';
import { usePatients } from '../hooks/usePatients';
import { useNotification } from '../hooks/useNotification';
import { getPreferences } from '../hooks/useUserPreferences';
import { deletePatient, reactivatePatient, listPatients } from '../api/patientService';
import { getPatientName, getPatientCRUID } from '../utils/fhirHelpers';
import { formatDate } from '../utils/formatters';
import type { FhirPatient, ListPatientsParams } from '../types';

export default function PatientsPage() {
  const { patients, total, page, pageSize, loading, error, search, goToPage, changePageSize } =
    usePatients(getPreferences().defaultPageSize);
  const { notification, showNotification, dismissNotification } = useNotification();

  const [stats, setStats] = useState<{ active: number | null; inactive: number | null }>({ active: null, inactive: null });
  const [activeFilters, setActiveFilters] = useState<ListPatientsParams>({ active: true });

  const [expandedRow, setExpandedRow] = useState<string | null>(null);

  const [viewPatient, setViewPatient] = useState<FhirPatient | null>(null);
  const [matchPatient, setMatchPatient] = useState<FhirPatient | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<FhirPatient | null>(null);
  const [deleting, setDeleting] = useState(false);

  const loadStats = useCallback(async () => {
    try {
      const [activeResult, inactiveResult] = await Promise.all([
        listPatients({ active: true, pageSize: 1 }),
        listPatients({ active: false, pageSize: 1 }),
      ]);
      setStats({ active: activeResult.total, inactive: inactiveResult.total });
    } catch {
      // stats are non-critical
    }
  }, []);

  useEffect(() => {
    search({ active: true });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  const handleSearch = (filters: ListPatientsParams) => {
    setActiveFilters(filters);
    setExpandedRow(null);
    search(filters);
  };

  const handlePageChange = (newPage: number) => {
    setExpandedRow(null);
    goToPage(newPage + 1, activeFilters);
  };

  const handleRowsPerPageChange = (newSize: number) => {
    setExpandedRow(null);
    changePageSize(newSize, activeFilters);
  };

  const toggleExpand = (patientId: string | undefined) => {
    if (!patientId) return;
    setExpandedRow((prev) => (prev === patientId ? null : patientId));
  };

  const handleDeleteConfirm = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await deletePatient(deleteTarget);
      showNotification(`Patient "${getPatientName(deleteTarget)}" deleted.`, 'success');
      setDeleteTarget(null);
      search(activeFilters);
      loadStats();
    } catch (err) {
      showNotification((err as Error).message || 'Failed to delete patient.', 'error');
    } finally {
      setDeleting(false);
    }
  };

  const handleReactivate = async (patient: FhirPatient) => {
    try {
      await reactivatePatient(patient);
      showNotification(`Patient "${getPatientName(patient)}" restored.`, 'success');
      search(activeFilters);
      loadStats();
    } catch (err) {
      showNotification((err as Error).message || 'Failed to restore patient.', 'error');
    }
  };

  const statCards = [
    {
      label: 'Total Patients',
      value:
        stats.active !== null && stats.inactive !== null
          ? stats.active + stats.inactive
          : total,
      color: '#4f46e5',
    },
    { label: 'Active', value: stats.active ?? '—', color: '#059669' },
    { label: 'Inactive (Merged)', value: stats.inactive ?? '—', color: '#dc2626' },
  ];

  const expandedPatient = patients.find((p) => p.id === expandedRow) ?? null;

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
      <StatsGrid stats={statCards} />
      <PatientSearchPanel onSearch={handleSearch} />

      {error && <Alert severity="error">{error}</Alert>}

      <ListingTable.Provider loading={loading}>
        <ListingTable.Container>
          <ListingTable.Toolbar />

          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Name</TableCell>
                <TableCell>CRUID</TableCell>
                <TableCell>Gender</TableCell>
                <TableCell>Date of Birth</TableCell>
                <TableCell>City</TableCell>
                <TableCell>Status</TableCell>
              </TableRow>
            </TableHead>

            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={6}>
                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
                      <CircularProgress />
                    </Box>
                  </TableCell>
                </TableRow>
              ) : patients.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6}>
                    <Box sx={{ textAlign: 'center', py: 4, color: 'text.disabled' }}>
                        <Typography>No patients match your search.</Typography>
                      </Box>
                  </TableCell>
                </TableRow>
              ) : (
                patients.map((patient) => {
                  const isExpanded = expandedRow === patient.id;
                  return (
                    <Fragment key={patient.id}>
                      <TableRow
                        onClick={() => toggleExpand(patient.id)}
                        sx={{
                          cursor: 'pointer',
                          bgcolor: isExpanded ? 'action.selected' : undefined,
                          borderBottom: isExpanded ? 'none' : undefined,
                          '&:hover': { bgcolor: isExpanded ? 'action.selected' : 'action.hover' },
                        }}
                      >
                        <TableCell>
                          <Typography sx={{ fontSize: 14, fontWeight: 600 }}>
                            {getPatientName(patient)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
                            {getPatientCRUID(patient)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          {patient.gender
                            ? patient.gender.charAt(0).toUpperCase() + patient.gender.slice(1)
                            : '—'}
                        </TableCell>
                        <TableCell>{formatDate(patient.birthDate)}</TableCell>
                        <TableCell>{patient.address?.[0]?.city || '—'}</TableCell>
                        <TableCell>
                          <Chip
                            label={patient.active === false ? 'Inactive' : 'Active'}
                            color={patient.active === false ? 'error' : 'success'}
                            size="small"
                          />
                        </TableCell>
                      </TableRow>

                      {isExpanded && (
                        <TableRow>
                          <TableCell colSpan={6} sx={{ p: 0, borderBottom: 'none' }}>
                            <PatientInlineEditForm
                              patient={expandedPatient || patient}
                              onCancel={() => setExpandedRow(null)}
                              onSuccess={() => {
                                showNotification('Patient updated successfully.', 'success');
                                setExpandedRow(null);
                                search(activeFilters);
                              }}
                              onView={() => setViewPatient(patient)}
                              onMatch={() => setMatchPatient(patient)}
                              onDelete={patient.active !== false ? () => setDeleteTarget(patient) : undefined}
                              onReactivate={patient.active === false ? () => handleReactivate(patient) : undefined}
                            />
                          </TableCell>
                        </TableRow>
                      )}
                    </Fragment>
                  );
                })
              )}
            </TableBody>
          </Table>

          <TablePagination
            component="div"
            count={total}
            page={page - 1}
            rowsPerPage={pageSize}
            onPageChange={(_e, newPage) => handlePageChange(newPage)}
            onRowsPerPageChange={(e) => handleRowsPerPageChange(parseInt(e.target.value, 10))}
            rowsPerPageOptions={[5, 10, 25, 50]}
          />
        </ListingTable.Container>
      </ListingTable.Provider>

      <PatientViewDialog open={!!viewPatient} patient={viewPatient} onClose={() => setViewPatient(null)} />
      <PatientMatchDialog open={!!matchPatient} patient={matchPatient} onClose={() => setMatchPatient(null)} />

      <Dialog open={!!deleteTarget} onClose={() => setDeleteTarget(null)} maxWidth="xs" fullWidth>
        <DialogTitle>Delete Patient</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Delete <strong>{deleteTarget ? getPatientName(deleteTarget) : ''}</strong>? The record
            will be marked inactive and hidden from active searches. You can restore it later using
            the Inactive filter.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteTarget(null)} disabled={deleting}>Cancel</Button>
          <Button variant="contained" color="error" onClick={handleDeleteConfirm} disabled={deleting}>
            {deleting ? 'Deleting...' : 'Delete'}
          </Button>
        </DialogActions>
      </Dialog>

      <NotificationSnackbar notification={notification} onDismiss={dismissNotification} />
    </Box>
  );
}
