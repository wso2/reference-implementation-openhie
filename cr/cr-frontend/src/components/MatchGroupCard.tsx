import React, { useState, useEffect } from 'react';
import {
  Card,
  Box,
  Typography,
  Button,
  Chip,
  Collapse,
  IconButton,
  Grid,
} from '@wso2/oxygen-ui';
import { Check, X, ChevronDown, ChevronUp, ArrowRight, User, GitMerge, UserX } from 'lucide-react';
import ScoreCircle from './ScoreCircle';
import PatientDetailsList from './PatientDetailsList';
import { getPatientName, getPatientCRUID } from '../utils/fhirHelpers';
import { getGradeBadge, getScoreColor } from '../utils/matchUtils';
import { formatDateTime } from '../utils/formatters';
import type { MatchGroup, FhirPatient } from '../types';

interface Props {
  group: MatchGroup;
  isExpanded: boolean;
  onToggle: () => void;
  onApprove: () => void;
  onReject: (group: MatchGroup) => void;
  onMarkUnique: (group: MatchGroup, ids: string[]) => void;
  onMergeSelected: (group: MatchGroup, patients: FhirPatient[]) => void;
}

export default function MatchGroupCard({
  group,
  isExpanded,
  onToggle,
  onApprove,
  onReject,
  onMarkUnique,
  onMergeSelected,
}: Props) {
  const gradeBadge = getGradeBadge(group.matchGrade);
  const isPending = group.status === 'pending';
  const patientCount = group.patients.length;
  const isMulti = patientCount > 2;

  const [selected, setSelected] = useState<Set<string>>(new Set());

  useEffect(() => {
    setSelected(new Set());
  }, [group.id, group.patients.length, isExpanded]);

  const togglePatient = (patientId: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(patientId)) {
        next.delete(patientId);
      } else {
        next.add(patientId);
      }
      return next;
    });
  };

  const selectedCount = selected.size;

  return (
    <Card
      sx={{
        borderLeft: `4px solid ${getScoreColor(group.score)}`,
        opacity: group.status === 'rejected' ? 0.6 : 1,
      }}
    >
      <Box
        onClick={onToggle}
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          p: 2.5,
          cursor: 'pointer',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2.5 }}>
          <ScoreCircle score={group.score} />
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
              {group.patients.map((p, i) => (
                <React.Fragment key={p.id ?? i}>
                  {i > 0 && (
                    <ArrowRight size={16} style={{ color: 'var(--mui-palette-text-disabled)' }} />
                  )}
                  <Typography sx={{ fontSize: 15, fontWeight: 600 }}>
                    {getPatientName(p)}
                  </Typography>
                </React.Fragment>
              ))}
            </Box>

            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.25, flexWrap: 'wrap' }}>
              <Chip
                label={`${patientCount} records`}
                size="small"
                sx={{
                  bgcolor: patientCount > 2 ? 'warning.light' : '#e0e7ff',
                  color: patientCount > 2 ? 'warning.dark' : '#3730a3',
                  fontWeight: 700,
                  fontSize: '11px',
                }}
              />
              <Chip
                label={group.matchGrade}
                size="small"
                variant="outlined"
                sx={{
                  bgcolor: gradeBadge.bg,
                  color: gradeBadge.color,
                  borderColor: gradeBadge.border,
                  fontWeight: 600,
                  fontSize: '11px',
                  textTransform: 'uppercase',
                }}
              />
              <Typography variant="body2" color="text.disabled">
                Detected: {formatDateTime(group.createdAt)}
              </Typography>
              {group.status !== 'pending' && (
                <Chip
                  label={group.status}
                  size="small"
                  sx={{
                    bgcolor: group.status === 'approved' ? 'success.light' : 'error.light',
                    color: group.status === 'approved' ? 'success.dark' : 'error.dark',
                    textTransform: 'uppercase',
                    fontWeight: 600,
                    fontSize: '11px',
                  }}
                />
              )}
            </Box>
          </Box>
        </Box>

        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          {isPending && !isMulti && (
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Button
                variant="contained"
                color="success"
                size="small"
                startIcon={<Check size={16} />}
                onClick={(e) => {
                  e.stopPropagation();
                  onApprove();
                }}
                sx={{ fontSize: 13 }}
              >
                Review &amp; Merge
              </Button>
              <Button
                variant="contained"
                size="small"
                startIcon={<X size={16} />}
                onClick={(e) => {
                  e.stopPropagation();
                  onReject(group);
                }}
                sx={{
                  fontSize: 13,
                  bgcolor: 'error.light',
                  color: 'error.main',
                  '&:hover': { bgcolor: '#fecaca' },
                }}
              >
                Reject
              </Button>
            </Box>
          )}
          <IconButton size="small">
            {isExpanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
          </IconButton>
        </Box>
      </Box>

      <Collapse in={isExpanded}>
        <Box
          sx={{
            borderTop: '1px solid',
            borderColor: 'divider',
            p: 2.5,
            bgcolor: 'background.default',
          }}
        >
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
            <Box sx={{ display: 'flex', gap: 3 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Box sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: 'success.main' }} />
                <Typography sx={{ fontSize: 13, fontWeight: 600, color: 'success.main' }}>
                  Matched Fields ({group.matchedFields.length})
                </Typography>
              </Box>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Box sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: 'error.main' }} />
                <Typography sx={{ fontSize: 13, fontWeight: 600, color: 'error.main' }}>
                  Unmatched Fields ({group.unmatchedFields?.length ?? 0})
                </Typography>
              </Box>
            </Box>
            {isPending && isMulti && (
              <Typography variant="body2" color="text.secondary" sx={{ fontSize: 12 }}>
                Click patient cards to select, then choose an action below
              </Typography>
            )}
          </Box>

          <Grid container spacing={2}>
            {group.patients.map((patient, idx) => {
              const isSelected = selected.has(patient.id ?? '');
              const isSelectable = isPending && isMulti;

              return (
                <Grid key={patient.id ?? idx} size={{ xs: 12, md: 12 / patientCount }}>
                  <Card
                    variant="outlined"
                    onClick={isSelectable ? () => togglePatient(patient.id ?? '') : undefined}
                    sx={{
                      overflow: 'hidden',
                      cursor: isSelectable ? 'pointer' : 'default',
                      border: isSelected ? '2px solid' : '1px solid',
                      borderColor: isSelected ? 'primary.main' : 'divider',
                      transition: 'all 0.15s',
                      position: 'relative',
                      ...(isSelectable && !isSelected && {
                        '&:hover': {
                          borderColor: 'primary.light',
                          boxShadow: '0 0 0 1px rgba(25, 118, 210, 0.2)',
                        },
                      }),
                    }}
                  >
                    {isSelected && (
                      <Box
                        sx={{
                          position: 'absolute',
                          top: 8,
                          right: 8,
                          width: 24,
                          height: 24,
                          borderRadius: '50%',
                          bgcolor: 'primary.main',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          zIndex: 1,
                        }}
                      >
                        <Check size={14} style={{ color: 'white' }} />
                      </Box>
                    )}

                    <Box
                      sx={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 1.25,
                        p: 1.5,
                        bgcolor: isSelected ? '#eff6ff' : idx === 0 ? '#eff6ff' : 'background.default',
                        borderBottom: '1px solid',
                        borderColor: 'divider',
                      }}
                    >
                      <User size={20} style={{ color: 'var(--mui-palette-text-secondary)' }} />
                      <Box>
                        <Typography sx={{ fontWeight: 600, fontSize: 13 }}>
                          M{idx + 1}: {getPatientCRUID(patient)}
                        </Typography>
                        <Typography sx={{ fontSize: 11, color: 'text.disabled', fontWeight: 400 }}>
                          CRUID
                        </Typography>
                      </Box>
                    </Box>
                    <PatientDetailsList
                      patient={patient}
                      matchedFields={group.matchedFields}
                    />
                  </Card>
                </Grid>
              );
            })}
          </Grid>

          {isPending && isMulti && (
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                mt: 2,
                pt: 2,
                borderTop: '1px solid',
                borderColor: 'divider',
              }}
            >
              <Typography variant="body2" color="text.secondary" sx={{ fontWeight: 600 }}>
                {selectedCount === 0
                  ? 'Select patients to take action'
                  : `${selectedCount} of ${patientCount} selected`}
              </Typography>
              <Box sx={{ display: 'flex', gap: 1 }}>
                <Button
                  variant="contained"
                  size="small"
                  startIcon={<UserX size={16} />}
                  disabled={selectedCount === 0 || selectedCount === patientCount}
                  onClick={() => {
                    const uniqueIds = [...selected];
                    onMarkUnique(group, uniqueIds);
                    setSelected(new Set());
                  }}
                  sx={{
                    fontSize: 13,
                    bgcolor: 'error.light',
                    color: 'error.main',
                    '&:hover': { bgcolor: '#fecaca' },
                    '&.Mui-disabled': { bgcolor: '#f5f5f5', color: '#bdbdbd' },
                  }}
                >
                  Mark as Unique ({selectedCount})
                </Button>
                <Button
                  variant="contained"
                  color="success"
                  size="small"
                  startIcon={<GitMerge size={16} />}
                  disabled={selectedCount < 2}
                  onClick={() => {
                    const selectedPatients = group.patients.filter((p) => selected.has(p.id ?? ''));
                    onMergeSelected(group, selectedPatients);
                    setSelected(new Set());
                  }}
                  sx={{ fontSize: 13 }}
                >
                  Merge Selected ({selectedCount})
                </Button>
              </Box>
            </Box>
          )}
        </Box>
      </Collapse>
    </Card>
  );
}
