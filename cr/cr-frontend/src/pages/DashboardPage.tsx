import { useState, useEffect, useMemo } from 'react';
import { Alert, Box, Button, CircularProgress, TablePagination, Typography } from '@wso2/oxygen-ui';
import { Play, RefreshCw, AlertCircle } from 'lucide-react';
import SearchToolbar from '../components/SearchToolbar';
import StatsGrid from '../components/StatsGrid';
import MatchGroupCard from '../components/MatchGroupCard';
import MergeModal from '../components/MergeModal';
import NotificationSnackbar from '../components/NotificationSnackbar';
import { useMatchGroups } from '../hooks/useMatchGroups';
import { useNotification } from '../hooks/useNotification';
import { useAuth } from '../auth/AuthContext';
import { getPatientName } from '../utils/fhirHelpers';
import type { MatchGroup, FhirPatient } from '../types';

const filterOptions = [
  { value: 'all', label: 'All Match Groups' },
  { value: 'pending', label: 'Pending' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
];

export default function DashboardPage() {
  const { user } = useAuth();
  const {
    matchGroups, merging,
    isStarting, isRetrieving, isJobRunning,
    startError, retrieveError, mergeError,
    lastRunTime,
    totalGroups, totalGroupedPatients, approvedCount, rejectedCount,
    currentPage, pageSize,
    runDedup, retrieveResults, loadPage, handlePageSizeChange,
    approveGroup, rejectGroup, removeFromGroup, mergeSubset,
  } = useMatchGroups();
  const { notification, showNotification, dismissNotification } = useNotification();

  const [searchQuery, setSearchQuery] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [expandedMatch, setExpandedMatch] = useState<string | null>(null);
  const [mergeModalOpen, setMergeModalOpen] = useState(false);
  const [selectedGroup, setSelectedGroup] = useState<MatchGroup | null>(null);
  const [mergeSelections, setMergeSelections] = useState<Record<string, number>>({});
  const [mergePatients, setMergePatients] = useState<FhirPatient[] | null>(null);
  const [survivingIndex, setSurvivingIndex] = useState(0);

  const filteredGroups = useMemo(() => {
    return matchGroups.filter((group) => {
      if (filterStatus !== 'all' && group.status !== filterStatus) return false;
      if (searchQuery) {
        const query = searchQuery.toLowerCase();
        return group.patients.some((p) => getPatientName(p).toLowerCase().includes(query));
      }
      return true;
    });
  }, [matchGroups, filterStatus, searchQuery]);

  const stats = useMemo(
    () => [
      { value: Math.max(0, totalGroups - approvedCount - rejectedCount), label: 'Pending Review' },
      { value: approvedCount, label: 'Approved', color: '#059669' },
      { value: rejectedCount, label: 'Rejected', color: '#dc2626' },
      { value: totalGroupedPatients, label: 'Total Records' },
    ],
    [totalGroups, totalGroupedPatients, approvedCount, rejectedCount]
  );

  const openMergeModal = (group: MatchGroup) => {
    setSelectedGroup(group);
    setMergePatients(null);
    setSurvivingIndex(0);
    const initialSelections: Record<string, number> = {};
    ['name', 'identifier', 'birthDate', 'gender', 'phone', 'email', 'address'].forEach((f) => {
      initialSelections[f] = 0;
    });
    setMergeSelections(initialSelections);
    setMergeModalOpen(true);
  };

  const handleApprove = async (groupId: string) => {
    setMergeModalOpen(false);
    const patientsToMerge = mergePatients;
    const group = selectedGroup;
    setSelectedGroup(null);
    setMergePatients(null);

    if (patientsToMerge) {
      await mergeSubset(groupId, patientsToMerge, user?.email || 'unknown', survivingIndex);
      if (!mergeError) {
        showNotification(`${patientsToMerge.length} records merged`);
      }
    } else {
      await approveGroup(groupId, user?.email || 'unknown', survivingIndex);
      if (!mergeError) {
        showNotification(
          `Match group approved \u2014 ${group?.patients?.length || 0} records merged`
        );
      }
    }
  };

  const handleReject = (group: MatchGroup) => {
    rejectGroup(group.id, user?.email || 'unknown');
    showNotification('Match group rejected', 'info');
  };

  const handleMarkUnique = (group: MatchGroup, uniquePatientIds: string[]) => {
    removeFromGroup(group.id, uniquePatientIds);
    showNotification(`${uniquePatientIds.length} patient(s) marked as unique`, 'info');
  };

  const handleMergeSelected = (group: MatchGroup, selectedPatients: FhirPatient[]) => {
    const tempGroup: MatchGroup = { ...group, patients: selectedPatients };
    setSelectedGroup(tempGroup);
    setMergePatients(selectedPatients);
    setSurvivingIndex(0);
    const initialSelections: Record<string, number> = {};
    ['name', 'identifier', 'birthDate', 'gender', 'phone', 'email', 'address'].forEach((f) => {
      initialSelections[f] = 0;
    });
    setMergeSelections(initialSelections);
    setMergeModalOpen(true);
  };

  const handleRunDedup = async () => {
    await runDedup();
    if (!startError) {
      showNotification('Deduplication job started on the server.');
    }
  };

  const handleRetrieveResults = async () => {
    await retrieveResults();
  };

  useEffect(() => {
    if (!merging && mergeError) {
      showNotification(mergeError, 'error');
    }
  }, [merging, mergeError, showNotification]);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
      <NotificationSnackbar notification={notification} onDismiss={dismissNotification} />

      <SearchToolbar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        placeholder="Search by patient name..."
        filterValue={filterStatus}
        onFilterChange={setFilterStatus}
        filterOptions={filterOptions}
      >
        <Button
          variant="contained"
          startIcon={isStarting ? <CircularProgress size={18} color="inherit" /> : <Play size={18} />}
          onClick={handleRunDedup}
          disabled={isStarting || isRetrieving || isJobRunning}
          sx={{ opacity: 0.75 }}
        >
          {isStarting ? 'Starting...' : 'Run Deduplication'}
        </Button>
        <Button
          variant="outlined"
          startIcon={isRetrieving ? <CircularProgress size={18} color="inherit" /> : <RefreshCw size={18} />}
          onClick={handleRetrieveResults}
          disabled={isStarting || isRetrieving}
          sx={{ opacity: 0.75 }}
        >
          {isRetrieving ? 'Retrieving...' : 'Retrieve Results'}
        </Button>
      </SearchToolbar>

      <Typography variant="body2" color="text.secondary" sx={{ px: 0.5 }}>
        {lastRunTime
          ? `Last run: ${new Date(lastRunTime).toLocaleString()}`
          : 'No deduplication has been run yet.'}
      </Typography>

      <StatsGrid stats={stats} />

      {startError && (
        <Alert severity="error" onClose={() => {}}>
          Failed to start deduplication: {startError}
        </Alert>
      )}

      {retrieveError && (
        <Alert
          severity={
            retrieveError.includes('Run the process first') || retrieveError.includes('still in progress')
              ? 'info'
              : 'error'
          }
          onClose={() => {}}
        >
          {retrieveError}
        </Alert>
      )}

      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        {filteredGroups.length === 0 ? (
          <Box sx={{ textAlign: 'center', py: 7.5, color: 'text.disabled' }}>
            <AlertCircle size={40} style={{ marginBottom: 8 }} />
            <Typography>
              {matchGroups.length === 0
                ? lastRunTime
                  ? 'No duplicate groups found in the last run.'
                  : 'No data yet. Click "Run Deduplication" to start, then "Retrieve Results" to load the data.'
                : 'No match groups found matching your filters.'}
            </Typography>
          </Box>
        ) : (
          filteredGroups.map((group) => (
            <MatchGroupCard
              key={group.id}
              group={group}
              isExpanded={expandedMatch === group.id}
              onToggle={() => setExpandedMatch(expandedMatch === group.id ? null : group.id)}
              onApprove={() => openMergeModal(group)}
              onReject={() => handleReject(group)}
              onMarkUnique={handleMarkUnique}
              onMergeSelected={handleMergeSelected}
            />
          ))
        )}
      </Box>

      {totalGroups > 0 && (
        <TablePagination
          component="div"
          count={totalGroups}
          page={currentPage}
          rowsPerPage={pageSize}
          rowsPerPageOptions={[10, 20, 50]}
          onPageChange={(_e, page) => loadPage(page)}
          onRowsPerPageChange={(e) => handlePageSizeChange(Number(e.target.value))}
        />
      )}

      {mergeModalOpen && selectedGroup && (
        <MergeModal
          group={selectedGroup}
          selections={mergeSelections}
          onSelectionChange={(field, idx) => setMergeSelections({ ...mergeSelections, [field]: idx })}
          survivingIndex={survivingIndex}
          onSurvivingIndexChange={setSurvivingIndex}
          onConfirm={() => handleApprove(selectedGroup.id)}
          onCancel={() => {
            setMergeModalOpen(false);
            setSelectedGroup(null);
            setMergePatients(null);
          }}
        />
      )}
    </Box>
  );
}
