import { useState, useEffect, useMemo } from 'react';
import {
  Box,
  Typography,
  Chip,
  CircularProgress,
  Alert,
  ListingTable,
  Button,
  IconButton,
  DatePickers,
  AdapterDateFns,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
} from '@wso2/oxygen-ui';
import { CheckCircle, XCircle, AlertCircle, ArrowUpDown, ChevronDown, X, Eye } from 'lucide-react';
import SearchToolbar from '../components/SearchToolbar';
import { useAuditLog } from '../hooks/useAuditLog';
import { getActionColor } from '../utils/matchUtils';
import { formatDateTime } from '../utils/formatters';

function AuditDetailDialog({ entry, onClose }) {
  if (!entry) return null;
  const actionColor = getActionColor(entry.action);
  return (
    <Dialog open onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: '1px solid',
          borderColor: 'divider',
          pb: 1.5,
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Eye size={18} />
          <Typography variant="h6" sx={{ fontWeight: 700 }}>
            Audit Event Details
          </Typography>
        </Box>
        <IconButton size="small" onClick={onClose} title="Close">
          <X size={18} />
        </IconButton>
      </DialogTitle>

      <DialogContent sx={{ p: 0 }}>
        {/* Event Metadata */}
        <Box sx={{ px: 3, pt: 2.5, pb: 2 }}>
          <Typography variant="overline" sx={{ color: 'text.secondary', fontWeight: 700, letterSpacing: '0.08em' }}>
            Event Metadata
          </Typography>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, mt: 1.5 }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>Event ID</Typography>
              <Typography sx={{ fontSize: 12, fontFamily: 'monospace', bgcolor: 'action.hover', px: 1, py: 0.25, borderRadius: 1 }}>
                {entry.id || '—'}
              </Typography>
            </Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>Timestamp</Typography>
              <Typography sx={{ fontSize: 13 }}>{formatDateTime(entry.timestamp)}</Typography>
            </Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>Action</Typography>
              <Chip
                label={entry.action?.replace(/_/g, ' ')}
                size="small"
                sx={{ bgcolor: actionColor.bg, color: actionColor.text, fontWeight: 600, fontSize: '11px' }}
              />
            </Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>Status</Typography>
              {entry.outcome === 'success' ? (
                <Chip
                  icon={<CheckCircle size={14} />}
                  label="Success"
                  size="small"
                  sx={{ bgcolor: '#dcfce7', color: '#166534', fontWeight: 600, fontSize: '11px' }}
                />
              ) : (
                <Chip
                  icon={<XCircle size={14} />}
                  label="Failed"
                  size="small"
                  sx={{ bgcolor: '#fee2e2', color: '#991b1b', fontWeight: 600, fontSize: '11px' }}
                />
              )}
            </Box>
            {entry.actionCode && (
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>FHIR Action</Typography>
                <Typography sx={{ fontSize: 12, fontFamily: 'monospace', bgcolor: 'action.hover', px: 1, py: 0.25, borderRadius: 1 }}>
                  {entry.actionCode}
                </Typography>
              </Box>
            )}
          </Box>
        </Box>

        <Box sx={{ height: '1px', bgcolor: 'divider' }} />

        {/* Agent */}
        <Box sx={{ px: 3, py: 2 }}>
          <Typography variant="overline" sx={{ color: 'text.secondary', fontWeight: 700, letterSpacing: '0.08em' }}>
            Agent
          </Typography>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, mt: 1.5 }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>User</Typography>
              <Typography sx={{ fontSize: 13 }}>{entry.user || '—'}</Typography>
            </Box>
            {entry.clientIp && (
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>IP Address</Typography>
                <Typography sx={{ fontSize: 12, fontFamily: 'monospace', bgcolor: 'action.hover', px: 1, py: 0.25, borderRadius: 1 }}>
                  {entry.clientIp}
                </Typography>
              </Box>
            )}
          </Box>
        </Box>

        <Box sx={{ height: '1px', bgcolor: 'divider' }} />

        {/* Resource */}
        <Box sx={{ px: 3, py: 2 }}>
          <Typography variant="overline" sx={{ color: 'text.secondary', fontWeight: 700, letterSpacing: '0.08em' }}>
            Resource
          </Typography>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, mt: 1.5 }}>
            {entry.entities?.length > 0 ? (
              entry.entities.map((e, i) => (
                <Box key={i} sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>
                    {entry.entities.length > 1 ? `${e.role} ${i + 1}` : 'Reference'}
                  </Typography>
                  <Typography sx={{ fontSize: 13, textAlign: 'right', maxWidth: '60%' }}>
                    {e.reference || '—'}
                  </Typography>
                </Box>
              ))
            ) : (
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <Typography sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}>Reference</Typography>
                <Typography sx={{ fontSize: 13, textAlign: 'right', maxWidth: '60%' }}>{entry.details || '—'}</Typography>
              </Box>
            )}
            {entry.reason && (
              <Box
                sx={{
                  bgcolor: entry.outcome === 'success' ? '#f0fdf4' : '#fef2f2',
                  border: '1px solid',
                  borderColor: entry.outcome === 'success' ? '#86efac' : '#fca5a5',
                  borderRadius: 2,
                  px: 2,
                  py: 1.25,
                }}
              >
                <Typography
                  sx={{
                    fontSize: 11,
                    fontWeight: 700,
                    textTransform: 'uppercase',
                    letterSpacing: '0.06em',
                    color: entry.outcome === 'success' ? '#166534' : '#991b1b',
                    mb: 0.5,
                  }}
                >
                  Reason
                </Typography>
                <Typography sx={{ fontSize: 13, color: entry.outcome === 'success' ? '#166534' : '#b91c1c' }}>
                  {entry.reason}
                </Typography>
              </Box>
            )}
          </Box>
        </Box>
      </DialogContent>

      <DialogActions sx={{ px: 3, py: 1.5, borderTop: '1px solid', borderColor: 'divider', bgcolor: 'background.default' }}>
        <Button onClick={onClose} sx={{ color: 'text.secondary', textTransform: 'none' }}>
          Close
        </Button>
      </DialogActions>
    </Dialog>
  );
}

const filterOptions = [
  { value: 'all', label: 'All Actions' },
  { value: 'read', label: 'Read' },
  { value: 'search', label: 'Search' },
  { value: 'create', label: 'Create' },
  { value: 'update', label: 'Update' },
  { value: 'delete', label: 'Delete' },
];

export default function AuditPage() {
  const {
    logs,
    loading,
    loadingMore,
    error,
    hasMore,
    sortOrder,
    fetchLogs,
    loadMore,
    toggleSort,
  } = useAuditLog();
  const [searchQuery, setSearchQuery] = useState('');
  const [filterAction, setFilterAction] = useState('all');
  const [dateFrom, setDateFrom] = useState(null);
  const [dateTo, setDateTo] = useState(null);
  const [selectedEntry, setSelectedEntry] = useState(null);

  useEffect(() => {
    const filters = {};
    if (filterAction !== 'all') {
      filters.subtype = filterAction;
    }
    if (dateFrom) {
      filters.since = dateFrom.toISOString();
    }
    if (dateTo) {
      filters.before = dateTo.toISOString();
    }
    fetchLogs(filters);
  }, [fetchLogs, filterAction, dateFrom, dateTo]);

  const clearDateRange = () => {
    setDateFrom(null);
    setDateTo(null);
  };

  const filteredLogs = useMemo(() => {
    if (!searchQuery) return logs;
    const query = searchQuery.toLowerCase();
    return logs.filter((entry) =>
      entry.details?.toLowerCase().includes(query) ||
      entry.user?.toLowerCase().includes(query) ||
      entry.action?.toLowerCase().includes(query)
    );
  }, [logs, searchQuery]);

  const hasDateFilter = dateFrom || dateTo;

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
      <SearchToolbar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        placeholder="Search audit log..."
        filterValue={filterAction}
        onFilterChange={setFilterAction}
        filterOptions={filterOptions}
      >
        <IconButton
          onClick={toggleSort}
          size="small"
          sx={{
            bgcolor: 'background.paper',
            border: '1px solid',
            borderColor: 'divider',
            '&:hover': { bgcolor: 'action.hover' },
          }}
          title={sortOrder === 'desc' ? 'Sorted: Newest First' : 'Sorted: Oldest First'}
        >
          <ArrowUpDown size={18} />
        </IconButton>
      </SearchToolbar>

      <DatePickers.LocalizationProvider dateAdapter={AdapterDateFns}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, flexWrap: 'wrap' }}>
          <DatePickers.DateTimePicker
            value={dateFrom}
            onChange={setDateFrom}
            label="From"
            maxDateTime={dateTo || undefined}
            slotProps={{
              textField: {
                size: 'small',
                sx: { minWidth: 220, bgcolor: 'background.paper' },
              },
            }}
          />
          <DatePickers.DateTimePicker
            value={dateTo}
            onChange={setDateTo}
            label="To"
            minDateTime={dateFrom || undefined}
            slotProps={{
              textField: {
                size: 'small',
                sx: { minWidth: 220, bgcolor: 'background.paper' },
              },
            }}
          />
          {hasDateFilter && (
            <Button
              variant="text"
              size="small"
              onClick={clearDateRange}
              startIcon={<X size={16} />}
              sx={{ color: 'text.secondary', textTransform: 'none' }}
            >
              Clear dates
            </Button>
          )}
        </Box>
      </DatePickers.LocalizationProvider>

      {error && (
        <Alert severity="error" sx={{ mb: 1 }}>
          {error}
        </Alert>
      )}

      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
          <CircularProgress />
        </Box>
      ) : filteredLogs.length === 0 ? (
        <Box sx={{ textAlign: 'center', py: 7.5, color: 'text.disabled' }}>
          <AlertCircle size={40} style={{ marginBottom: 8 }} />
          <Typography>
            {logs.length === 0
              ? 'No audit logs yet. Perform patient operations and audit events will appear here.'
              : 'No audit entries match your filters.'}
          </Typography>
        </Box>
      ) : (
        <ListingTable.Container>
          <ListingTable>
            <ListingTable.Head>
              <ListingTable.Row>
                <ListingTable.Cell sx={{ fontWeight: 600, width: 180 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                    <Typography variant="caption">Timestamp</Typography>
                    <Typography
                      variant="caption"
                      sx={{ color: 'primary.main', fontSize: '11px' }}
                    >
                      {sortOrder === 'desc' ? '↓' : '↑'}
                    </Typography>
                  </Box>
                </ListingTable.Cell>
                <ListingTable.Cell sx={{ fontWeight: 600, width: 200 }}>
                  <Typography variant="caption">User</Typography>
                </ListingTable.Cell>
                <ListingTable.Cell sx={{ fontWeight: 600, width: 160 }}>
                  <Typography variant="caption">Action</Typography>
                </ListingTable.Cell>
                <ListingTable.Cell sx={{ fontWeight: 600, width: 100 }}>
                  <Typography variant="caption">Status</Typography>
                </ListingTable.Cell>
                <ListingTable.Cell sx={{ fontWeight: 600 }}>
                  <Typography variant="caption">Details</Typography>
                </ListingTable.Cell>
                <ListingTable.Cell sx={{ width: 52 }} />
              </ListingTable.Row>
            </ListingTable.Head>
            <ListingTable.Body>
              {filteredLogs.map((entry) => {
                const actionColor = getActionColor(entry.action);
                return (
                  <ListingTable.Row key={entry.id}>
                    <ListingTable.Cell>
                      <Typography sx={{ fontSize: 13 }}>
                        {formatDateTime(entry.timestamp)}
                      </Typography>
                    </ListingTable.Cell>
                    <ListingTable.Cell>
                      <Typography
                        sx={{ fontSize: 13, color: 'text.secondary' }}
                      >
                        {entry.user}
                      </Typography>
                    </ListingTable.Cell>
                    <ListingTable.Cell>
                      <Chip
                        label={entry.action?.replace(/_/g, ' ')}
                        size="small"
                        sx={{
                          bgcolor: actionColor.bg,
                          color: actionColor.text,
                          fontWeight: 600,
                          fontSize: '11px',
                        }}
                      />
                    </ListingTable.Cell>
                    <ListingTable.Cell>
                      {entry.outcome === 'success' ? (
                        <Chip
                          icon={<CheckCircle size={16} />}
                          label="Success"
                          size="small"
                          sx={{
                            bgcolor: '#dcfce7',
                            color: '#166534',
                            fontWeight: 600,
                            fontSize: '11px',
                          }}
                        />
                      ) : (
                        <Chip
                          icon={<XCircle size={16} />}
                          label="Failed"
                          size="small"
                          sx={{
                            bgcolor: '#fee2e2',
                            color: '#991b1b',
                            fontWeight: 600,
                            fontSize: '11px',
                          }}
                        />
                      )}
                    </ListingTable.Cell>
                    <ListingTable.Cell>
                      <Typography
                        sx={{ fontSize: 13, color: 'text.secondary' }}
                      >
                        {entry.details}
                      </Typography>
                      {entry.reason && (
                        <Typography
                          sx={{
                            fontSize: 12,
                            color: entry.outcome === 'success' ? 'success.main' : 'error.main',
                            mt: 0.5,
                          }}
                        >
                          {entry.reason}
                        </Typography>
                      )}
                    </ListingTable.Cell>
                    <ListingTable.Cell>
                      <IconButton
                        size="small"
                        onClick={() => setSelectedEntry(entry)}
                        title="View details"
                        sx={{ color: 'text.secondary', '&:hover': { color: 'primary.main' } }}
                      >
                        <Eye size={16} />
                      </IconButton>
                    </ListingTable.Cell>
                  </ListingTable.Row>
                );
              })}
            </ListingTable.Body>
          </ListingTable>
        </ListingTable.Container>
      )}

      {!loading && filteredLogs.length > 0 && hasMore && (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 1 }}>
          <Button
            variant="outlined"
            onClick={loadMore}
            disabled={loadingMore}
            startIcon={
              loadingMore
                ? <CircularProgress size={18} color="inherit" />
                : <ChevronDown size={18} />
            }
            sx={{
              minWidth: 200,
              borderColor: 'divider',
              color: 'text.primary',
              '&:hover': {
                borderColor: 'primary.main',
                bgcolor: 'action.hover',
              },
            }}
          >
            {loadingMore ? 'Loading...' : 'Load More'}
          </Button>
        </Box>
      )}

      {!loading && filteredLogs.length > 0 && !hasMore && (
        <Box sx={{ textAlign: 'center', py: 2, color: 'text.disabled' }}>
          <Typography variant="caption">No more audit logs to load</Typography>
        </Box>
      )}

      <AuditDetailDialog
        entry={selectedEntry}
        onClose={() => setSelectedEntry(null)}
      />
    </Box>
  );
}
