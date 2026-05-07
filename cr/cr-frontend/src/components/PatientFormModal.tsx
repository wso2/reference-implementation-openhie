import { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Box,
  Grid,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Typography,
  Alert,
  CircularProgress,
  Divider,
} from '@wso2/oxygen-ui';
import { createPatient, updatePatient } from '../api/patientService';
import type { FhirPatient } from '../types';

interface FormState {
  givenNames: string;
  familyName: string;
  gender: string;
  birthDate: string;
  identifierSystem: string;
  identifierValue: string;
  addressLine: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
  phone: string;
  email: string;
}

const EMPTY_FORM: FormState = {
  givenNames: '',
  familyName: '',
  gender: '',
  birthDate: '',
  identifierSystem: '',
  identifierValue: '',
  addressLine: '',
  city: '',
  state: '',
  postalCode: '',
  country: '',
  phone: '',
  email: '',
};

function formFromPatient(patient: FhirPatient | null): FormState {
  if (!patient) return EMPTY_FORM;
  const name = patient.name?.[0] ?? {};
  const addr = patient.address?.[0] ?? {};
  const id = patient.identifier?.[0] ?? { system: '', value: '' };
  return {
    givenNames: name.given?.join(', ') ?? '',
    familyName: name.family ?? '',
    gender: patient.gender ?? '',
    birthDate: patient.birthDate ?? '',
    identifierSystem: id.system ?? '',
    identifierValue: id.value ?? '',
    addressLine: addr.line?.join(', ') ?? '',
    city: addr.city ?? '',
    state: addr.state ?? '',
    postalCode: addr.postalCode ?? '',
    country: addr.country ?? '',
    phone: patient.telecom?.find((t) => t.system === 'phone')?.value ?? '',
    email: patient.telecom?.find((t) => t.system === 'email')?.value ?? '',
  };
}

function buildFhirPatient(form: FormState, existingPatient: FhirPatient | null): FhirPatient {
  const resource: FhirPatient = {
    resourceType: 'Patient',
    active: true,
  };

  if (form.familyName || form.givenNames) {
    resource.name = [
      {
        family: form.familyName || undefined,
        given: form.givenNames
          ? form.givenNames.split(',').map((s) => s.trim()).filter(Boolean)
          : undefined,
      },
    ];
  }

  if (form.gender) resource.gender = form.gender as FhirPatient['gender'];
  if (form.birthDate) resource.birthDate = form.birthDate;

  if (form.identifierSystem && form.identifierValue) {
    resource.identifier = [{ system: form.identifierSystem, value: form.identifierValue }];
  } else if (existingPatient?.identifier) {
    resource.identifier = existingPatient.identifier;
  }

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
  }

  const telecom: FhirPatient['telecom'] = [];
  if (form.phone) telecom.push({ system: 'phone', value: form.phone });
  if (form.email) telecom.push({ system: 'email', value: form.email });
  if (telecom.length) resource.telecom = telecom;

  if (existingPatient?.id) resource.id = existingPatient.id;
  if (existingPatient?.meta) resource.meta = existingPatient.meta;

  return resource;
}

interface Props {
  open: boolean;
  mode: 'create' | 'edit';
  patient: FhirPatient | null;
  onClose: () => void;
  onSuccess: () => void;
}

export default function PatientFormModal({ open, mode, patient, onClose, onSuccess }: Props) {
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setForm(formFromPatient(patient));
      setError(null);
    }
  }, [open, patient]);

  const set = (key: keyof FormState) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
    setForm((f) => ({ ...f, [key]: e.target.value }));

  const handleSubmit = async () => {
    if (!form.familyName && !form.givenNames) {
      setError('At least a given or family name is required.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const resource = buildFhirPatient(form, patient);
      if (mode === 'create') {
        await createPatient(resource);
      } else {
        const id = patient?.identifier?.[0];
        if (!id) throw new Error('Patient has no identifier to update by.');
        await updatePatient(id.system ?? '', id.value, resource);
      }
      onSuccess();
      onClose();
    } catch (err) {
      setError((err as Error).message || 'Failed to save patient.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>{mode === 'create' ? 'Add Patient' : 'Edit Patient'}</DialogTitle>

      <DialogContent dividers>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        <Typography
          variant="caption"
          sx={{ fontWeight: 700, textTransform: 'uppercase', color: 'text.disabled', letterSpacing: 0.8 }}
        >
          Name
        </Typography>
        <Grid container spacing={2} sx={{ mt: 0.5, mb: 2 }}>
          <Grid size={{ xs: 12, sm: 6 }}>
            <TextField
              fullWidth
              size="small"
              label="Given Name(s)"
              helperText="Comma-separated for multiple"
              value={form.givenNames}
              onChange={set('givenNames')}
            />
          </Grid>
          <Grid size={{ xs: 12, sm: 6 }}>
            <TextField
              fullWidth
              size="small"
              label="Family Name"
              value={form.familyName}
              onChange={set('familyName')}
            />
          </Grid>
        </Grid>

        <Divider sx={{ my: 1.5 }} />

        <Typography
          variant="caption"
          sx={{ fontWeight: 700, textTransform: 'uppercase', color: 'text.disabled', letterSpacing: 0.8 }}
        >
          Demographics
        </Typography>
        <Grid container spacing={2} sx={{ mt: 0.5, mb: 2 }}>
          <Grid size={{ xs: 12, sm: 6 }}>
            <FormControl fullWidth size="small">
              <InputLabel>Gender</InputLabel>
              <Select label="Gender" value={form.gender} onChange={(e) => setForm((f) => ({ ...f, gender: e.target.value as string }))}>
                <MenuItem value="">Unknown</MenuItem>
                <MenuItem value="male">Male</MenuItem>
                <MenuItem value="female">Female</MenuItem>
                <MenuItem value="other">Other</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          <Grid size={{ xs: 12, sm: 6 }}>
            <TextField
              fullWidth
              size="small"
              label="Date of Birth"
              type="date"
              value={form.birthDate}
              onChange={set('birthDate')}
              InputLabelProps={{ shrink: true }}
            />
          </Grid>
        </Grid>

        <Divider sx={{ my: 1.5 }} />

        <Typography
          variant="caption"
          sx={{ fontWeight: 700, textTransform: 'uppercase', color: 'text.disabled', letterSpacing: 0.8 }}
        >
          Identifier
        </Typography>
        <Grid container spacing={2} sx={{ mt: 0.5, mb: 2 }}>
          <Grid size={{ xs: 12, sm: 6 }}>
            <TextField
              fullWidth
              size="small"
              label="System (e.g. http://example.org/nhid)"
              value={form.identifierSystem}
              onChange={set('identifierSystem')}
              disabled={mode === 'edit'}
            />
          </Grid>
          <Grid size={{ xs: 12, sm: 6 }}>
            <TextField
              fullWidth
              size="small"
              label="Value"
              value={form.identifierValue}
              onChange={set('identifierValue')}
              disabled={mode === 'edit'}
            />
          </Grid>
        </Grid>

        <Divider sx={{ my: 1.5 }} />

        <Typography
          variant="caption"
          sx={{ fontWeight: 700, textTransform: 'uppercase', color: 'text.disabled', letterSpacing: 0.8 }}
        >
          Address
        </Typography>
        <Grid container spacing={2} sx={{ mt: 0.5, mb: 2 }}>
          <Grid size={{ xs: 12 }}>
            <TextField
              fullWidth
              size="small"
              label="Address Line"
              value={form.addressLine}
              onChange={set('addressLine')}
            />
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            <TextField fullWidth size="small" label="City" value={form.city} onChange={set('city')} />
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            <TextField fullWidth size="small" label="State" value={form.state} onChange={set('state')} />
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            <TextField
              fullWidth
              size="small"
              label="Postal Code"
              value={form.postalCode}
              onChange={set('postalCode')}
            />
          </Grid>
          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            <TextField
              fullWidth
              size="small"
              label="Country"
              value={form.country}
              onChange={set('country')}
            />
          </Grid>
        </Grid>

        <Divider sx={{ my: 1.5 }} />

        <Typography
          variant="caption"
          sx={{ fontWeight: 700, textTransform: 'uppercase', color: 'text.disabled', letterSpacing: 0.8 }}
        >
          Contact
        </Typography>
        <Grid container spacing={2} sx={{ mt: 0.5 }}>
          <Grid size={{ xs: 12, sm: 6 }}>
            <TextField
              fullWidth
              size="small"
              label="Phone"
              value={form.phone}
              onChange={set('phone')}
            />
          </Grid>
          <Grid size={{ xs: 12, sm: 6 }}>
            <TextField
              fullWidth
              size="small"
              label="Email"
              type="email"
              value={form.email}
              onChange={set('email')}
            />
          </Grid>
        </Grid>
      </DialogContent>

      <DialogActions>
        <Button onClick={onClose} disabled={submitting}>
          Cancel
        </Button>
        <Button
          variant="contained"
          onClick={handleSubmit}
          disabled={submitting}
          startIcon={submitting ? <CircularProgress size={16} /> : null}
        >
          {submitting ? 'Saving...' : mode === 'create' ? 'Add Patient' : 'Save Changes'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
