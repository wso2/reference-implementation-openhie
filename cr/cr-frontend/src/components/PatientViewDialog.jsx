import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Box,
  Typography,
  Chip,
  Divider,
} from '@wso2/oxygen-ui';
import { getPatientName, getPatientCRUID } from '../utils/fhirHelpers';
import { formatDate, formatDateTime } from '../utils/formatters';

function Section({ title, children }) {
  return (
    <Box sx={{ mb: 2 }}>
      <Typography
        variant="caption"
        sx={{ fontWeight: 700, textTransform: 'uppercase', color: 'text.disabled', letterSpacing: 0.8 }}
      >
        {title}
      </Typography>
      <Box sx={{ mt: 1, display: 'flex', flexDirection: 'column', gap: 0.75 }}>
        {children}
      </Box>
    </Box>
  );
}

function Field({ label, value }) {
  return (
    <Box sx={{ display: 'flex', gap: 1 }}>
      <Typography variant="body2" sx={{ color: 'text.secondary', minWidth: 130 }}>
        {label}
      </Typography>
      <Typography variant="body2" sx={{ fontWeight: 500, color: 'text.primary', wordBreak: 'break-all' }}>
        {value || '—'}
      </Typography>
    </Box>
  );
}

export default function PatientViewDialog({ open, patient, onClose }) {
  if (!patient) return null;

  const phone = patient.telecom?.find((t) => t.system === 'phone')?.value;
  const email = patient.telecom?.find((t) => t.system === 'email')?.value;
  const addr = patient.address?.[0];
  const isInactive = patient.active === false;
  const replacedBy = patient.link?.find((l) => l.type === 'replaced-by');

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Typography variant="h6" sx={{ flex: 1 }}>
            {getPatientName(patient)}
          </Typography>
          <Chip
            label={isInactive ? 'Inactive' : 'Active'}
            color={isInactive ? 'error' : 'success'}
            size="small"
          />
        </Box>
      </DialogTitle>

      <DialogContent dividers>
        <Section title="Identity">
          <Field label="CRUID" value={getPatientCRUID(patient)} />
          {(patient.identifier || []).map((id, i) => (
            <Field key={i} label={id.system || `Identifier ${i + 1}`} value={id.value} />
          ))}
        </Section>

        <Divider sx={{ my: 1.5 }} />

        <Section title="Demographics">
          <Field label="Full Name" value={getPatientName(patient)} />
          <Field label="Gender" value={patient.gender} />
          <Field label="Date of Birth" value={formatDate(patient.birthDate)} />
        </Section>

        <Divider sx={{ my: 1.5 }} />

        <Section title="Contact">
          <Field label="Phone" value={phone} />
          <Field label="Email" value={email} />
          {addr && (
            <>
              <Field label="Address" value={addr.line?.join(', ')} />
              <Field label="City" value={addr.city} />
              <Field label="State" value={addr.state} />
              <Field label="Postal Code" value={addr.postalCode} />
              <Field label="Country" value={addr.country} />
            </>
          )}
        </Section>

        <Divider sx={{ my: 1.5 }} />

        <Section title="Registry">
          <Field label="Status" value={isInactive ? 'Inactive' : 'Active'} />
          <Field label="Last Updated" value={formatDateTime(patient.meta?.lastUpdated)} />
          {replacedBy && (
            <Field
              label="Replaced By"
              value={`${replacedBy.other?.identifier?.system} | ${replacedBy.other?.identifier?.value}`}
            />
          )}
        </Section>
      </DialogContent>

      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
}
