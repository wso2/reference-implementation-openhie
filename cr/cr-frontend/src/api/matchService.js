import { fetchApi } from './client.js';

function classifyScore(score) {
  if (score >= 0.95) return 'certain';
  if (score >= 0.80) return 'probable';
  if (score >= 0.60) return 'possible';
  return 'certainly-not';
}

export async function runPatientMatch(
  patientResource,
  { count = 10, onlyCertainMatches = false } = {}
) {
  const parameters = {
    resourceType: 'Parameters',
    parameter: [
      { name: 'resource', resource: patientResource },
      { name: 'count', valueInteger: count },
      ...(onlyCertainMatches
        ? [{ name: 'onlyCertainMatches', valueBoolean: true }]
        : []),
    ],
  };

  const bundle = await fetchApi('/Patient/$match', {
    method: 'POST',
    body: JSON.stringify(parameters),
  });

  return (bundle.entry || []).map((e) => ({
    patient: e.resource,
    score: e.search?.score ?? 0,
    matchGrade: classifyScore(e.search?.score ?? 0),
  }));
}

export async function startDedupJob() {
  return fetchApi('/Patient/dedupstart');
}

export async function getDedupJobStatus() {
  return fetchApi('/Patient/dedupstatus');
}

export async function getLatestDedupResults() {
  return fetchApi('/Patient/dedup');
}

export async function rejectDedupMatch(patientId1, patientId2) {
  return fetchApi(`/Patient/dedupreject?patient1=${encodeURIComponent(patientId1)}&patient2=${encodeURIComponent(patientId2)}`);
}
