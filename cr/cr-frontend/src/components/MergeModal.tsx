import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Box,
  Typography,
  Button,
  Radio,
} from '@wso2/oxygen-ui';
import { GitMerge, Check, X, User, FileText } from 'lucide-react';
import { getPatientName } from '../utils/fhirHelpers';
import { formatDate } from '../utils/formatters';
import type { MatchGroup, FhirPatient } from '../types';

function abbreviateSystem(system: string | null | undefined): string {
  if (!system) return 'Identifier';
  try {
    const url = new URL(system);
    const segments = url.pathname.split('/').filter(Boolean);
    return segments[segments.length - 1] || url.hostname;
  } catch {
    const parts = system.split('/').filter(Boolean);
    return parts[parts.length - 1] || system;
  }
}

interface FieldDef {
  key: string;
  label: string;
  getValue: (patient: FhirPatient) => string;
}

interface Props {
  group: MatchGroup | null;
  selections: Record<string, number>;
  onSelectionChange: (field: string, idx: number) => void;
  survivingIndex: number;
  onSurvivingIndexChange: (idx: number) => void;
  onConfirm: () => void;
  onCancel: () => void;
}

export default function MergeModal({
  group,
  selections,
  onSelectionChange,
  survivingIndex,
  onSurvivingIndexChange,
  onConfirm,
  onCancel,
}: Props) {
  if (!group) return null;

  const patientCount = group.patients.length;

  const allSystems: string[] = [];
  const seenSystems = new Set<string>();
  group.patients.forEach((patient) => {
    (patient.identifier || []).forEach((id) => {
      const sys = id.system ?? '__bare__';
      if (!seenSystems.has(sys)) {
        seenSystems.add(sys);
        allSystems.push(sys);
      }
    });
  });

  const identifierFieldDefs: FieldDef[] = allSystems.map((sys, i) => ({
    key: `identifier__${sys}`,
    label: `Identifier ${i + 1}`,
    getValue: (patient) => {
      const match = (patient.identifier || []).find(
        (id) => (id.system ?? '__bare__') === sys
      );
      return match?.value || '\u2014';
    },
  }));

  const fieldDefs: FieldDef[] = [
    { key: 'name', label: 'Name', getValue: (p) => getPatientName(p) },
    ...identifierFieldDefs,
    { key: 'birthDate', label: 'Birth Date', getValue: (p) => formatDate(p.birthDate) ?? '' },
    { key: 'gender', label: 'Gender', getValue: (p) => p.gender ?? '\u2014' },
    {
      key: 'phone',
      label: 'Phone',
      getValue: (p) => p.telecom?.find((t) => t.system === 'phone')?.value || '\u2014',
    },
    {
      key: 'address',
      label: 'Address',
      getValue: (p) =>
        `${p.address?.[0]?.line?.join(', ') || ''}, ${p.address?.[0]?.city || ''}`,
    },
  ];

  const cruIdKey = identifierFieldDefs.find((f) =>
    group.patients.some((p) => f.getValue(p).startsWith('Patient/'))
  )?.key ?? null;

  const mergedPreview: Record<string, string> = {};
  fieldDefs.forEach((f) => {
    const selectedIdx = selections[f.key] ?? 0;
    mergedPreview[f.key] = f.getValue(group.patients[selectedIdx]);
  });

  return (
    <Dialog
      open
      onClose={onCancel}
      maxWidth={patientCount > 3 ? 'xl' : 'lg'}
      fullWidth
    >
      <DialogTitle
        sx={{
          display: 'flex',
          flexDirection: 'column',
          gap: 1,
          borderBottom: '1px solid',
          borderColor: 'divider',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <GitMerge size={20} />
          <Typography variant="h6" sx={{ fontWeight: 700 }}>
            Merge {patientCount} Records
          </Typography>
        </Box>
        <Typography variant="body2" color="text.secondary">
          Select which value to keep for each field from {patientCount} matching
          records. The merged patient preview is shown on the right.
        </Typography>
      </DialogTitle>

      <DialogContent sx={{ p: 3 }}>
        <Box sx={{ display: 'flex', gap: 3 }}>
          <Box sx={{ flex: 1, minWidth: 0, display: 'flex' }}>
            <Box sx={{ flexShrink: 0, width: 100 }}>
              <Box
                sx={{
                  p: '10px 12px',
                  bgcolor: 'background.default',
                  borderRadius: '8px 0 0 0',
                  borderRight: '2px solid',
                  borderColor: 'divider',
                  height: 40,
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <Typography variant="caption" color="text.secondary">
                  Field
                </Typography>
              </Box>
              {fieldDefs.map((field) => (
                <Box
                  key={field.key}
                  sx={{
                    px: 1.5,
                    py: 1,
                    borderBottom: '1px solid',
                    borderColor: 'divider',
                    height: 52,
                    display: 'flex',
                    alignItems: 'center',
                    borderRight: '2px solid',
                    borderRightColor: 'divider',
                    bgcolor: 'background.paper',
                  }}
                >
                  <Typography sx={{ fontSize: 12, fontWeight: 600, color: 'text.secondary' }}>
                    {field.label}
                  </Typography>
                </Box>
              ))}
            </Box>

            <Box sx={{ flex: 1, overflowX: 'auto', minWidth: 0 }}>
              <Box
                sx={{
                  display: 'grid',
                  gridTemplateColumns: `repeat(${patientCount}, minmax(180px, 1fr))`,
                  gap: 1,
                  p: '10px 12px',
                  bgcolor: 'background.default',
                  borderRadius: '0 8px 0 0',
                  height: 40,
                  alignItems: 'center',
                  minWidth: patientCount > 3 ? `${patientCount * 190}px` : undefined,
                }}
              >
                {group.patients.map((p, i) => (
                  <Typography
                    key={p.id ?? i}
                    variant="caption"
                    color="text.secondary"
                    sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}
                  >
                    <FileText size={14} /> M{i + 1}
                  </Typography>
                ))}
              </Box>

              {fieldDefs.map((field) => (
                <Box
                  key={field.key}
                  sx={{
                    display: 'grid',
                    gridTemplateColumns: `repeat(${patientCount}, minmax(180px, 1fr))`,
                    gap: 1,
                    px: 1.5,
                    py: 1,
                    borderBottom: '1px solid',
                    borderColor: 'divider',
                    alignItems: 'center',
                    height: 52,
                    minWidth: patientCount > 3 ? `${patientCount * 190}px` : undefined,
                  }}
                >
                  {group.patients.map((patient, idx) => {
                    const isSelected = selections[field.key] === idx;
                    return (
                      <Box
                        key={patient.id ?? idx}
                        component="label"
                        sx={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 1,
                          px: 1.25,
                          py: 1,
                          bgcolor: isSelected ? '#eff6ff' : 'background.default',
                          borderRadius: 2,
                          cursor: 'pointer',
                          fontSize: 12,
                          color: 'text.primary',
                          border: '2px solid',
                          borderColor: isSelected ? 'primary.main' : 'transparent',
                          transition: 'all 0.15s',
                        }}
                      >
                        <Radio
                          size="small"
                          checked={isSelected}
                          onChange={() => {
                            onSelectionChange(field.key, idx);
                            if (field.key === cruIdKey) onSurvivingIndexChange(idx);
                          }}
                          sx={{ p: 0 }}
                        />
                        <Typography noWrap sx={{ fontSize: 12 }}>
                          {field.getValue(patient)}
                        </Typography>
                      </Box>
                    );
                  })}
                </Box>
              ))}
            </Box>
          </Box>

          <Box
            sx={{
              width: 280,
              flexShrink: 0,
              bgcolor: 'success.light',
              borderRadius: 3,
              border: '2px solid #86efac',
              overflow: 'hidden',
              alignSelf: 'flex-start',
              position: 'sticky',
              top: 0,
            }}
          >
            <Box
              sx={{
                px: 2,
                py: 1.75,
                bgcolor: 'success.main',
                color: 'white',
                display: 'flex',
                alignItems: 'center',
                gap: 1.25,
              }}
            >
              <User size={20} />
              <Box>
                <Typography sx={{ fontWeight: 700, fontSize: 14 }}>
                  Merged Patient
                </Typography>
                <Typography sx={{ fontSize: 11, opacity: 0.85 }}>
                  Golden Record Preview
                </Typography>
              </Box>
            </Box>
            <Box sx={{ px: 2, py: 1.5 }}>
              <Box sx={{ py: 1, borderBottom: '1px solid #dcfce7' }}>
                <Typography sx={{ fontSize: 10, color: 'success.main', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  Surviving CRUID
                </Typography>
                <Typography sx={{ fontSize: 12, color: 'text.secondary', fontFamily: 'monospace', mt: 0.25 }} noWrap>
                  {group.patients[survivingIndex]?.id ?? '—'}
                </Typography>
              </Box>
              {fieldDefs.map((f) => (
                <Box key={f.key} sx={{ py: 1, borderBottom: '1px solid #dcfce7' }}>
                  <Typography
                    sx={{
                      fontSize: 10,
                      color: 'success.main',
                      fontWeight: 600,
                      textTransform: 'uppercase',
                      letterSpacing: '0.05em',
                    }}
                  >
                    {f.label}
                  </Typography>
                  <Typography sx={{ fontSize: 13, color: 'text.primary', fontWeight: 500, mt: 0.25 }}>
                    {mergedPreview[f.key]}
                  </Typography>
                </Box>
              ))}
            </Box>
          </Box>
        </Box>
      </DialogContent>

      <DialogActions
        sx={{
          px: 3,
          py: 2.5,
          borderTop: '1px solid',
          borderColor: 'divider',
          bgcolor: 'background.default',
        }}
      >
        <Button onClick={onCancel} sx={{ color: 'text.secondary' }}>
          Cancel
        </Button>
        <Button
          variant="contained"
          onClick={onCancel}
          startIcon={<X size={16} />}
          sx={{
            bgcolor: 'error.light',
            color: 'error.main',
            '&:hover': { bgcolor: '#fecaca' },
          }}
        >
          Deny
        </Button>
        <Button
          variant="contained"
          color="success"
          onClick={onConfirm}
          startIcon={<Check size={16} />}
        >
          Approve &amp; Merge
        </Button>
      </DialogActions>
    </Dialog>
  );
}
