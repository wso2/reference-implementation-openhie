import { useState } from 'react';
import { Card, Box, Avatar, Typography, IconButton, Collapse } from '@wso2/oxygen-ui';
import { ChevronDown, ChevronUp } from 'lucide-react';
import { getPatientName, getPatientCRUID } from '../utils/fhirHelpers';
import { formatDate, formatDateTime } from '../utils/formatters';
import type { FhirPatient } from '../types';

interface Props {
  patient: FhirPatient;
}

interface FieldProps {
  label: string;
  value?: string;
}

function Field({ label, value }: FieldProps) {
  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.25 }}>
      <Typography variant="caption" color="text.disabled">
        {label}
      </Typography>
      <Typography sx={{ fontSize: 13, fontWeight: 500, color: 'text.primary' }}>
        {value || '\u2014'}
      </Typography>
    </Box>
  );
}

export default function PatientCard({ patient }: Props) {
  const [expanded, setExpanded] = useState(false);
  const name = getPatientName(patient);

  return (
    <Card>
      <Box
        sx={{
          display: 'flex',
          alignItems: 'center',
          gap: 1.5,
          p: 2,
          borderBottom: '1px solid',
          borderColor: 'divider',
        }}
      >
        <Avatar
          sx={{
            width: 44,
            height: 44,
            bgcolor: '#e0e7ff',
            color: '#4f46e5',
            fontSize: 18,
            fontWeight: 600,
          }}
        >
          {name.charAt(0)}
        </Avatar>
        <Box sx={{ flex: 1 }}>
          <Typography sx={{ fontSize: 15, fontWeight: 600, color: 'text.primary' }}>
            {name}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
            {'CRUID'} &middot; {getPatientCRUID(patient)}
          </Typography>
        </Box>
        <IconButton onClick={() => setExpanded(!expanded)} size="small">
          {expanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
        </IconButton>
      </Box>

      <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', px: 2, py: 1.5 }}>
        <Field label="DOB" value={formatDate(patient.birthDate)} />
        <Field label="Gender" value={patient.gender} />
        <Field label="City" value={patient.address?.[0]?.city} />
      </Box>

      <Collapse in={expanded}>
        <Box
          sx={{
            px: 2,
            py: 1.5,
            borderTop: '1px solid',
            borderColor: 'divider',
            bgcolor: 'background.default',
            display: 'flex',
            flexDirection: 'column',
            gap: 1,
          }}
        >
          <Field
            label="Phone"
            value={patient.telecom?.find((t) => t.system === 'phone')?.value}
          />
          <Field
            label="Address"
            value={patient.address?.[0]?.line?.join(', ')}
          />
          <Field
            label="Last Updated"
            value={formatDateTime(patient.meta?.lastUpdated)}
          />
        </Box>
      </Collapse>
    </Card>
  );
}
