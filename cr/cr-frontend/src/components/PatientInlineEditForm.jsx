import { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Button,
  Typography,
  Alert,
  CircularProgress,
  Divider,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  Chip,
} from '@wso2/oxygen-ui';
import { Pencil, X } from 'lucide-react';
import { updatePatient } from '../api/patientService';
import { getPatientName } from '../utils/fhirHelpers';
import { formatDate } from '../utils/formatters';

// ── helpers ────────────────────────────────────────────────────────────────

function formFromPatient(patient) {
  if (!patient) return {};
  const name = patient.name?.[0] || {};
  const addr = patient.address?.[0] || {};
  const id = patient.identifier?.[0] || {};
  return {
    givenNames: name.given?.join(', ') || '',
    familyName: name.family || '',
    gender: patient.gender || '',
    birthDate: patient.birthDate || '',
    identifierSystem: id.system || '',
    identifierValue: id.value || '',
    addressLine: addr.line?.join(', ') || '',
    city: addr.city || '',
    state: addr.state || '',
    postalCode: addr.postalCode || '',
    country: addr.country || '',
    phone: patient.telecom?.find((t) => t.system === 'phone')?.value || '',
    email: patient.telecom?.find((t) => t.system === 'email')?.value || '',
  };
}

function buildFhirPatient(form, existingPatient) {
  const resource = { ...existingPatient, active: existingPatient?.active ?? true };

  resource.name = [
    {
      family: form.familyName || undefined,
      given: form.givenNames
        ? form.givenNames.split(',').map((s) => s.trim()).filter(Boolean)
        : undefined,
    },
  ];

  if (form.gender) resource.gender = form.gender;
  else delete resource.gender;

  if (form.birthDate) resource.birthDate = form.birthDate;
  else delete resource.birthDate;

  if (form.addressLine || form.city || form.state || form.postalCode || form.country) {
    resource.address = [
      {
        line: form.addressLine ? [form.addressLine] : undefined,
        city: form.city || undefined,
        state: form.state || undefined,
        postalCode: form.postalCode || undefined,
        country: form.country || undefined,
      },
    ];
  } else {
    delete resource.address;
  }

  const telecom = [];
  if (form.phone) telecom.push({ system: 'phone', value: form.phone });
  if (form.email) telecom.push({ system: 'email', value: form.email });
  resource.telecom = telecom.length ? telecom : undefined;

  return resource;
}

// ── read-only field ─────────────────────────────────────────────────────────

function ReadField({ label, value }) {
  return (
    <Box>
      <Typography variant="caption" color="text.disabled" sx={{ display: 'block', mb: 0.25 }}>
        {label}
      </Typography>
      <Typography variant="body2" sx={{ fontWeight: 500 }}>
        {value || '—'}
      </Typography>
    </Box>
  );
}

// ── main component ──────────────────────────────────────────────────────────

export default function PatientInlineEditForm({ patient, onSuccess, onCancel, onView, onMatch, onDelete, onReactivate }) {
  const [form, setForm] = useState({});
  const [editing, setEditing] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setForm(formFromPatient(patient));
    setEditing(false);
    setError(null);
  }, [patient]);

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));

  const handleEditClick = () => {
    setError(null);
    setEditing(true);
  };

  const handleCancelEdit = () => {
    setForm(formFromPatient(patient)); // reset to original
    setEditing(false);
    setError(null);
  };

  const handleSaveClick = () => {
    if (!form.familyName && !form.givenNames) {
      setError('At least a given or family name is required.');
      return;
    }
    setConfirmOpen(true);
  };

  const handleConfirmSave = async () => {
    const id = patient.identifier?.[0];
    if (!id) {
      setError('Patient has no identifier to update by.');
      setConfirmOpen(false);
      return;
    }
    setSubmitting(true);
    setConfirmOpen(false);
    try {
      const resource = buildFhirPatient(form, patient);
      await updatePatient(id.system, id.value, resource);
      onSuccess();
    } catch (err) {
      setError(err.message || 'Failed to save changes.');
    } finally {
      setSubmitting(false);
    }
  };

  const isInactive = patient?.active === false;

  return (
    <>
      <Box
        sx={{
          bgcolor: 'background.default',
          borderTop: '2px solid',
          borderColor: 'primary.main',
          px: 3,
          py: 2,
        }}
      >
        {/* Header row */}
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
              {getPatientName(patient)}
            </Typography>
            <Chip
              label={isInactive ? 'Inactive' : 'Active'}
              color={isInactive ? 'error' : 'success'}
              size="small"
            />
            {editing && (
              <Chip label="Editing" color="warning" size="small" variant="outlined" />
            )}
          </Box>

          <Box sx={{ display: 'flex', gap: 1, alignItems: 'center', flexWrap: 'wrap' }}>
            {/* Record actions */}
            {onView && (
              <Button size="small" variant="outlined" onClick={onView}>View Details</Button>
            )}
            {onMatch && (
              <Button size="small" variant="outlined" onClick={onMatch}>Run Match</Button>
            )}
            {onReactivate && (
              <Button size="small" variant="outlined" color="success" onClick={onReactivate}>Restore</Button>
            )}
            {onDelete && (
              <Button size="small" variant="outlined" color="error" onClick={onDelete}>Delete</Button>
            )}
            {(onView || onMatch || onDelete || onReactivate) && (
              <Divider orientation="vertical" flexItem sx={{ mx: 0.5 }} />
            )}

            {/* Form controls */}
            {!editing ? (
              <Button
                size="small"
                variant="outlined"
                startIcon={<Pencil size={14} />}
                onClick={handleEditClick}
              >
                Edit
              </Button>
            ) : (
              <>
                <Button
                  size="small"
                  startIcon={<X size={14} />}
                  onClick={handleCancelEdit}
                  disabled={submitting}
                >
                  Cancel Edit
                </Button>
                <Button
                  size="small"
                  variant="contained"
                  onClick={handleSaveClick}
                  disabled={submitting}
                  startIcon={submitting ? <CircularProgress size={14} /> : null}
                >
                  {submitting ? 'Saving…' : 'Save Changes'}
                </Button>
              </>
            )}
            <Button size="small" color="inherit" onClick={onCancel} disabled={submitting}>
              Close
            </Button>
          </Box>
        </Box>

        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        {/* ── Name & Demographics ── */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            {editing ? (
              <TextField
                fullWidth size="small" label="Given Name(s)"
                helperText="Comma-separated"
                value={form.givenNames || ''} onChange={set('givenNames')}
              />
            ) : (
              <ReadField label="Given Name(s)" value={form.givenNames} />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            {editing ? (
              <TextField
                fullWidth size="small" label="Family Name"
                value={form.familyName || ''} onChange={set('familyName')}
              />
            ) : (
              <ReadField label="Family Name" value={form.familyName} />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            {editing ? (
              <FormControl fullWidth size="small">
                <InputLabel>Gender</InputLabel>
                <Select label="Gender" value={form.gender || ''} onChange={set('gender')}>
                  <MenuItem value="">Unknown</MenuItem>
                  <MenuItem value="male">Male</MenuItem>
                  <MenuItem value="female">Female</MenuItem>
                  <MenuItem value="other">Other</MenuItem>
                </Select>
              </FormControl>
            ) : (
              <ReadField
                label="Gender"
                value={form.gender ? form.gender.charAt(0).toUpperCase() + form.gender.slice(1) : null}
              />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            {editing ? (
              <TextField
                fullWidth size="small" label="Date of Birth" type="date"
                value={form.birthDate || ''} onChange={set('birthDate')}
                InputLabelProps={{ shrink: true }}
              />
            ) : (
              <ReadField label="Date of Birth" value={formatDate(form.birthDate)} />
            )}
          </Grid>
        </Grid>

        <Divider sx={{ my: 2 }} />

        {/* ── Address ── */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, sm: 6, md: 4 }}>
            {editing ? (
              <TextField fullWidth size="small" label="Address Line" value={form.addressLine || ''} onChange={set('addressLine')} />
            ) : (
              <ReadField label="Address Line" value={form.addressLine} />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 2 }}>
            {editing ? (
              <TextField fullWidth size="small" label="City" value={form.city || ''} onChange={set('city')} />
            ) : (
              <ReadField label="City" value={form.city} />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 2 }}>
            {editing ? (
              <TextField fullWidth size="small" label="State" value={form.state || ''} onChange={set('state')} />
            ) : (
              <ReadField label="State" value={form.state} />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 2 }}>
            {editing ? (
              <TextField fullWidth size="small" label="Postal Code" value={form.postalCode || ''} onChange={set('postalCode')} />
            ) : (
              <ReadField label="Postal Code" value={form.postalCode} />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 2 }}>
            {editing ? (
              <TextField fullWidth size="small" label="Country" value={form.country || ''} onChange={set('country')} />
            ) : (
              <ReadField label="Country" value={form.country} />
            )}
          </Grid>
        </Grid>

        <Divider sx={{ my: 2 }} />

        {/* ── Contact & Identifier ── */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            {editing ? (
              <TextField fullWidth size="small" label="Phone" value={form.phone || ''} onChange={set('phone')} />
            ) : (
              <ReadField label="Phone" value={form.phone} />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            {editing ? (
              <TextField fullWidth size="small" label="Email" type="email" value={form.email || ''} onChange={set('email')} />
            ) : (
              <ReadField label="Email" value={form.email} />
            )}
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            <ReadField label="Identifier System" value={form.identifierSystem} />
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            <ReadField label="Identifier Value" value={form.identifierValue} />
          </Grid>
        </Grid>
      </Box>

      {/* ── Confirm save dialog ── */}
      <Dialog open={confirmOpen} onClose={() => setConfirmOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Confirm Update</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Save changes to <strong>{getPatientName(patient)}</strong>? This will update the
            patient record in the registry.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmOpen(false)}>Cancel</Button>
          <Button variant="contained" onClick={handleConfirmSave}>
            Update
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
}
