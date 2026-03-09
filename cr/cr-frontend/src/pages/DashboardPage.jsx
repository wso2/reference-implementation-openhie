import { useState, useEffect, useMemo } from 'react';
import { Alert, Box, Button, CircularProgress, Typography } from '@wso2/oxygen-ui';
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
    runDedup, retrieveResults,
    approveGroup, rejectGroup, removeFromGroup, mergeSubset,
  } = useMatchGroups();
  const { notification, showNotification, dismissNotification } =
    useNotification();

  const [searchQuery, setSearchQuery] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [expandedMatch, setExpandedMatch] = useState(null);
  const [mergeModalOpen, setMergeModalOpen] = useState(false);
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [mergeSelections, setMergeSelections] = useState({});
  // Track which patients are being merged (for partial merge within a group)
  const [mergePatients, setMergePatients] = useState(null);

  const filteredGroups = useMemo(() => {
    return matchGroups.filter((group) => {
      if (filterStatus !== 'all' && group.status !== filterStatus) return false;
      if (searchQuery) {
        const query = searchQuery.toLowerCase();
        return group.patients.some((p) =>
          getPatientName(p).toLowerCase().includes(query)
        );
      }
      return true;
    });
  }, [matchGroups, filterStatus, searchQuery]);

  const stats = useMemo(
    () => [
      {
        value: matchGroups.filter((m) => m.status === 'pending').length,
        label: 'Pending Review',
      },
      {
        value: matchGroups.filter((m) => m.status === 'approved').length,
        label: 'Approved',
        color: '#059669',
      },
      {
        value: matchGroups.filter((m) => m.status === 'rejected').length,
        label: 'Rejected',
        color: '#dc2626',
      },
      {
        value: matchGroups.reduce((sum, g) => sum + g.patients.length, 0),
        label: 'Total Records',
      },
    ],
    [matchGroups]
  );

  // Open merge modal for a full group (2-patient groups)
  const openMergeModal = (group) => {
    setSelectedGroup(group);
    setMergePatients(null);
    const initialSelections = {};
    const fields = ['name', 'identifier', 'birthDate', 'gender', 'phone', 'email', 'address'];
    fields.forEach((field) => { initialSelections[field] = 0; });
    setMergeSelections(initialSelections);
    setMergeModalOpen(true);
  };

  // Handle approve from MergeModal
  const handleApprove = async (groupId) => {
    setMergeModalOpen(false);
    const patientsToMerge = mergePatients;
    const group = selectedGroup;
    setSelectedGroup(null);
    setMergePatients(null);

    if (patientsToMerge) {
      // Partial merge — merge subset then remove from group
      await mergeSubset(groupId, patientsToMerge, user?.email || 'unknown');
      if (!error) {
        showNotification(`${patientsToMerge.length} records merged`);
      }
    } else {
      // Full group merge (2-patient groups)
      await approveGroup(groupId, user?.email || 'unknown');
      if (!error) {
        showNotification(
          `Match group approved \u2014 ${group?.patients?.length || 0} records merged`
        );
      }
    }
  };

  // Reject entire group (2-patient groups only)
  const handleReject = (group) => {
    rejectGroup(group.id, user?.email || 'unknown');
    showNotification('Match group rejected', 'info');
  };

  // Mark selected patients as unique (remove from group)
  const handleMarkUnique = (group, uniquePatientIds) => {
    removeFromGroup(group.id, uniquePatientIds);
    showNotification(`${uniquePatientIds.length} patient(s) marked as unique`, 'info');
  };

  // Open merge modal for a subset of patients within a multi-patient group
  const handleMergeSelected = (group, selectedPatients) => {
    // Create a temporary group object with only the selected patients
    const tempGroup = {
      ...group,
      patients: selectedPatients,
    };
    setSelectedGroup(tempGroup);
    setMergePatients(selectedPatients);
    const initialSelections = {};
    const fields = ['name', 'identifier', 'birthDate', 'gender', 'phone', 'email', 'address'];
    fields.forEach((field) => { initialSelections[field] = 0; });
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

  // Show merge errors via notification
  useEffect(() => {
    if (!merging && mergeError) {
      showNotification(mergeError, 'error');
    }
  }, [merging, mergeError]);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
      <NotificationSnackbar
        notification={notification}
        onDismiss={dismissNotification}
      />

      {/* Toolbar */}
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
        >
          {isStarting ? 'Starting...' : 'Run Deduplication'}
        </Button>
        <Button
          variant="outlined"
          startIcon={isRetrieving ? <CircularProgress size={18} color="inherit" /> : <RefreshCw size={18} />}
          onClick={handleRetrieveResults}
          disabled={isStarting || isRetrieving}
        >
          {isRetrieving ? 'Retrieving...' : 'Retrieve Results'}
        </Button>
      </SearchToolbar>

      {/* Last run time + running indicator */}
      <Typography variant="body2" color="text.secondary" sx={{ px: 0.5 }}>
        {lastRunTime
          ? `Last run: ${new Date(lastRunTime).toLocaleString()}`
          : 'No deduplication has been run yet.'}
      </Typography>

      {/* Stats */}
      <StatsGrid stats={stats} />

      {/* Start error */}
      {startError && (
        <Alert severity="error" onClose={() => {}}>
          Failed to start deduplication: {startError}
        </Alert>
      )}

      {/* Retrieve error / info */}
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

      {/* Match Group Cards */}
      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        {filteredGroups.length === 0 ? (
          <Box
            sx={{
              textAlign: 'center',
              py: 7.5,
              color: 'text.disabled',
            }}
          >
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
              onToggle={() =>
                setExpandedMatch(
                  expandedMatch === group.id ? null : group.id
                )
              }
              onApprove={() => openMergeModal(group)}
              onReject={() => handleReject(group)}
              onMarkUnique={handleMarkUnique}
              onMergeSelected={handleMergeSelected}
            />
          ))
        )}
      </Box>

      {/* Merge Modal */}
      {mergeModalOpen && selectedGroup && (
        <MergeModal
          group={selectedGroup}
          selections={mergeSelections}
          onSelectionChange={(field, idx) =>
            setMergeSelections({ ...mergeSelections, [field]: idx })
          }
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
