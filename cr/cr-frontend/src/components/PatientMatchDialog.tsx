import { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Box,
  Typography,
  CircularProgress,
  Alert,
  Chip,
  Divider,
} from '@wso2/oxygen-ui';
import { runPatientMatch } from '../api/matchService';
import { getPatientName, getPatientCRUID } from '../utils/fhirHelpers';
import { formatDate } from '../utils/formatters';
import { getScoreColor } from '../utils/matchUtils';
import type { FhirPatient, MatchResult, MatchGrade } from '../types';

interface Props {
  open: boolean;
  patient: FhirPatient | null;
  onClose: () => void;
}

const gradeLabels: Record<MatchGrade, string> = {
  certain: 'Certain',
  probable: 'Probable',
  possible: 'Possible',
  'certainly-not': 'No Match',
};

export default function PatientMatchDialog({ open, patient, onClose }: Props) {
  const [results, setResults] = useState<MatchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open || !patient) return;
    let cancelled = false;

    const run = async () => {
      setLoading(true);
      setError(null);
      setResults([]);
      try {
        const matches = await runPatientMatch(patient, { count: 10, onlyCertainMatches: false });
        if (!cancelled) setResults(matches);
      } catch (err) {
        if (!cancelled) setError((err as Error).message || 'Match failed.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    run();
    return () => { cancelled = true; };
  }, [open, patient]);

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>
        Patient Match Results
        {patient && (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
            Query: {getPatientName(patient)}
          </Typography>
        )}
      </DialogTitle>

      <DialogContent dividers>
        {loading && (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
            <CircularProgress />
          </Box>
        )}

        {error && <Alert severity="error">{error}</Alert>}

        {!loading && !error && results.length === 0 && (
          <Box sx={{ textAlign: 'center', py: 5, color: 'text.disabled' }}>
            <Typography>No matching patients found.</Typography>
          </Box>
        )}

        {!loading && results.map((match, i) => {
          const scoreColor = getScoreColor(match.score);
          return (
            <Box key={match.patient?.id ?? i}>
              {i > 0 && <Divider sx={{ my: 1 }} />}
              <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2, py: 0.5 }}>
                <Box
                  sx={{
                    minWidth: 52,
                    height: 52,
                    borderRadius: '50%',
                    border: `3px solid ${scoreColor}`,
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <Typography sx={{ fontSize: 13, fontWeight: 700, color: scoreColor, lineHeight: 1 }}>
                    {Math.round(match.score * 100)}%
                  </Typography>
                </Box>

                <Box sx={{ flex: 1 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
                    <Typography sx={{ fontWeight: 600, fontSize: 14 }}>
                      {getPatientName(match.patient)}
                    </Typography>
                    <Chip
                      label={gradeLabels[match.matchGrade] ?? match.matchGrade}
                      size="small"
                      sx={{
                        bgcolor: scoreColor + '22',
                        color: scoreColor,
                        border: `1px solid ${scoreColor}55`,
                        fontWeight: 600,
                        fontSize: 11,
                      }}
                    />
                  </Box>
                  <Typography variant="body2" color="text.secondary">
                    CRUID: {getPatientCRUID(match.patient)}
                    {match.patient?.gender ? ` · ${match.patient.gender}` : ''}
                    {match.patient?.birthDate ? ` · ${formatDate(match.patient.birthDate)}` : ''}
                  </Typography>
                  {match.patient?.address?.[0]?.city && (
                    <Typography variant="body2" color="text.secondary">
                      {match.patient.address[0].city}
                    </Typography>
                  )}
                </Box>
              </Box>
            </Box>
          );
        })}
      </DialogContent>

      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
}
