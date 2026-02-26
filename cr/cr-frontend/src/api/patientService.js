import { fetchApi } from './client.js';

export async function searchPatients(params = {}) {
  const query = new URLSearchParams();
  if (params.family) query.append('family', params.family);
  if (params.given) query.append('given', params.given);
  if (params.gender) query.append('gender', params.gender);
  if (params.birthdate) query.append('birthdate', params.birthdate);
  if (params.identifier) query.append('identifier', params.identifier);
  if (params.city) query.append('address-city', params.city);
  if (params.state) query.append('address-state', params.state);
  if (params.postalCode) query.append('address-postalcode', params.postalCode);
  if (params.country) query.append('address-country', params.country);
  if (params.phone) query.append('telecom', params.phone);
  if (params.email) query.append('telecom', params.email);

  const queryStr = query.toString();
  const bundle = await fetchApi(`/Patient${queryStr ? '?' + queryStr : ''}`);
  return (bundle.entry || []).map((e) => e.resource);
}

export async function listPatients({ page = 1, pageSize = 20, ...filters } = {}) {
  const query = new URLSearchParams();
  query.append('_count', String(pageSize));
  query.append('_offset', String((page - 1) * pageSize));
  if (filters.family) query.append('family', filters.family);
  if (filters.given) query.append('given', filters.given);
  if (filters.gender) query.append('gender', filters.gender);
  if (filters.birthdate) query.append('birthdate', filters.birthdate);
  if (filters.city) query.append('address-city', filters.city);
  if (filters.state) query.append('address-state', filters.state);
  if (filters.postalCode) query.append('address-postalcode', filters.postalCode);
  if (filters.country) query.append('address-country', filters.country);
  if (filters.phone) query.append('telecom', filters.phone);
  if (filters.active !== undefined) query.append('active', String(filters.active));

  const bundle = await fetchApi(`/Patient?${query.toString()}`);
  const patients = (bundle.entry || []).map((e) => e.resource);
  return { patients, total: bundle.total ?? patients.length, page, pageSize };
}

export async function getPatient(id) {
  return fetchApi(`/Patient/${id}`);
}

export async function createPatient(patientResource) {
  return fetchApi('/Patient', {
    method: 'POST',
    body: JSON.stringify(patientResource),
  });
}

export async function updatePatient(system, value, patientResource) {
  return fetchApi(
    `/Patient?identifier=${encodeURIComponent(system + '|' + value)}`,
    {
      method: 'PUT',
      body: JSON.stringify(patientResource),
    }
  );
}

export async function deletePatient(patient) {
  const id = patient.identifier?.[0];
  if (!id) throw new Error('Patient has no identifier');
  return fetchApi(
    `/Patient?identifier=${encodeURIComponent(id.system + '|' + id.value)}`,
    { method: 'DELETE' }
  );
}

/**
 * Reactivate a patient that was previously deactivated (e.g. incorrectly merged).
 * Sets active=true and removes any replaced-by link.
 */
export async function reactivatePatient(patient) {
  const id = patient.identifier?.[0];
  if (!id) throw new Error('Patient has no identifier');
  const reactivated = { ...patient, active: true };
  delete reactivated.link;
  return fetchApi(
    `/Patient?identifier=${encodeURIComponent(id.system + '|' + id.value)}`,
    { method: 'PUT', body: JSON.stringify(reactivated) }
  );
}

/**
 * ITI-104 Resolve Duplicate Patient.
 * Marks the subsumed patient as inactive with a replaced-by link to the surviving patient.
 *
 * @param {object} subsumedPatient - Full FHIR Patient resource of the duplicate
 * @param {object} survivingIdentifier - { system, value } of the surviving patient
 */
export async function resolvePatient(subsumedPatient, survivingIdentifier) {
  const id = subsumedPatient.identifier?.[0];
  if (!id) throw new Error('Subsumed patient has no identifier');

  const resolvedResource = {
    ...subsumedPatient,
    active: false,
    link: [
      {
        other: {
          identifier: {
            system: survivingIdentifier.system,
            value: survivingIdentifier.value,
          },
        },
        type: 'replaced-by',
      },
    ],
  };

  return fetchApi(
    `/Patient?identifier=${encodeURIComponent(id.system + '|' + id.value)}`,
    {
      method: 'PUT',
      body: JSON.stringify(resolvedResource),
    }
  );
}
