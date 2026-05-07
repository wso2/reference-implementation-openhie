import { Box, Typography } from '@wso2/oxygen-ui';
import { getPatientName } from '../utils/fhirHelpers';
import { formatDate } from '../utils/formatters';
import type { FhirPatient } from '../types';

interface Props {
  patient: FhirPatient;
  matchedFields?: string[];
}

export default function PatientDetailsList({ patient, matchedFields }: Props) {
  const matchedFieldKeys = matchedFields || [];

  const identifierFields = (patient.identifier || []).map((id, index) => ({
    key: `identifier_${index}`,
    matchKey: 'identifier',
    label: `Identifier ${index + 1}`,
    value: [id.system, id.value].filter(Boolean).join(' | '),
  }));

  const fields: { key: string; matchKey?: string; label: string; value?: string }[] = [
    { key: 'name', label: 'Name', value: getPatientName(patient) },
    ...identifierFields,
    { key: 'family_name', label: 'Family Name', value: patient.name?.[0]?.family },
    { key: 'given_name', label: 'Given Name', value: patient.name?.[0]?.given?.join(' ') },
    { key: 'birth_date', label: 'Birth Date', value: formatDate(patient.birthDate) },
    { key: 'gender', label: 'Gender', value: patient.gender },
    { key: 'phone', label: 'Phone', value: patient.telecom?.find((t) => t.system === 'phone')?.value },
    { key: 'city', label: 'City', value: patient.address?.[0]?.city },
    { key: 'postal_code', label: 'Postal Code', value: patient.address?.[0]?.postalCode },
    { key: 'address', label: 'Address', value: patient.address?.[0]?.line?.join(', ') },
  ];

  return (
    <Box sx={{ p: 1 }}>
      {fields.map((field) => (
        <Box
          key={field.key}
          sx={{
            display: 'flex',
            justifyContent: 'space-between',
            px: 1.5,
            py: 1,
            borderRadius: 1,
            mb: 0.5,
            bgcolor: matchedFieldKeys.includes(field.matchKey || field.key)
              ? 'success.light'
              : 'background.paper',
          }}
        >
          <Typography
            sx={{ fontSize: 12, color: 'text.secondary', fontWeight: 500 }}
          >
            {field.label}
          </Typography>
          <Typography
            sx={{ fontSize: 13, color: 'text.primary', fontWeight: 500 }}
          >
            {field.value || '\u2014'}
          </Typography>
        </Box>
      ))}
    </Box>
  );
}
