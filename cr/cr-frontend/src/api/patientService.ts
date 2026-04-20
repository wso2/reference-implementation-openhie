import { fetchApi } from './client';
import type { FhirPatient, ListPatientsParams, ListPatientsResult, PatientSearchParams } from '../types';

export async function searchPatients(params: PatientSearchParams = {}): Promise<FhirPatient[]> {
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
  const bundle = await fetchApi(`/Patient${queryStr ? '?' + queryStr : ''}`) as { entry?: { resource: FhirPatient }[] };
  return (bundle.entry || []).map((e) => e.resource);
}

export async function listPatients({ page = 1, pageSize = 20, ...filters }: ListPatientsParams = {}): Promise<ListPatientsResult> {
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

  const bundle = await fetchApi(`/Patient?${query.toString()}`) as { entry?: { resource: FhirPatient }[]; total?: number };
  const patients = (bundle.entry || []).map((e) => e.resource);
  return { patients, total: bundle.total ?? patients.length, page, pageSize };
}

export async function getPatient(id: string): Promise<FhirPatient> {
  return fetchApi(`/Patient/${id}`) as Promise<FhirPatient>;
}

export async function createPatient(patientResource: FhirPatient): Promise<FhirPatient> {
  return fetchApi('/Patient', {
    method: 'POST',
    body: JSON.stringify(patientResource),
  }) as Promise<FhirPatient>;
}

export async function updatePatient(system: string, value: string, patientResource: FhirPatient): Promise<FhirPatient> {
  return fetchApi(
    `/Patient?identifier=${encodeURIComponent(system + '|' + value)}`,
    {
      method: 'PUT',
      body: JSON.stringify(patientResource),
    }
  ) as Promise<FhirPatient>;
}

export async function deletePatient(patient: FhirPatient): Promise<unknown> {
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
export async function reactivatePatient(patient: FhirPatient): Promise<FhirPatient> {
  const id = patient.identifier?.[0];
  if (!id) throw new Error('Patient has no identifier');
  const reactivated: FhirPatient = { ...patient, active: true };
  delete reactivated.link;
  return fetchApi(
    `/Patient?identifier=${encodeURIComponent(id.system + '|' + id.value)}`,
    { method: 'PUT', body: JSON.stringify(reactivated) }
  ) as Promise<FhirPatient>;
}

/**
 * ITI-104 Resolve Duplicate Patient.
 * Marks the subsumed patient as inactive with a replaced-by link to the surviving patient.
 */
export async function resolvePatient(
  subsumedPatient: FhirPatient,
  survivingIdentifier: { system: string; value: string }
): Promise<FhirPatient> {
  const id = subsumedPatient.identifier?.[0];
  if (!id) throw new Error('Subsumed patient has no identifier');

  const resolvedResource: FhirPatient = {
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
  ) as Promise<FhirPatient>;
}
