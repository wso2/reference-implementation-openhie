export const getPatientName = (patient) => {
  if (!patient?.name?.[0]) return 'Unknown';
  const name = patient.name[0];
  const given = name.given?.join(' ') || '';
  return `${given} ${name.family || ''}`.trim();
};

export const getPatientCRUID = (patient) => {
  return patient?.id || 'No CRUID';
};

export const getPatientIdentifier = (patient) => {
  if (!patient?.identifier?.[0]) return 'No ID';
  return patient.identifier[0].value;
};

