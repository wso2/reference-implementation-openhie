import { fetchApi, fetchApiResponse, ApiError } from './client';
import type { FhirPatient, MatchGrade, MatchResult, DedupResult, DedupJobMeta } from '../types';

function classifyScore(score: number): MatchGrade {
  if (score >= 0.95) return 'certain';
  if (score >= 0.80) return 'probable';
  if (score >= 0.60) return 'possible';
  return 'certainly-not';
}

export async function runPatientMatch(
  patientResource: FhirPatient,
  { count = 10, onlyCertainMatches = false }: { count?: number; onlyCertainMatches?: boolean } = {}
): Promise<MatchResult[]> {
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
  }) as { entry?: { resource: FhirPatient; search?: { score?: number } }[] };

  return (bundle.entry || []).map((e) => ({
    patient: e.resource,
    score: e.search?.score ?? 0,
    matchGrade: classifyScore(e.search?.score ?? 0),
  }));
}

// Starts a dedup job. Returns { contentLocation } from the 202 Content-Location header.
// Both a fresh start and an already-running job return 202 (FHIR async pattern).
export async function startDedupJob(): Promise<{ contentLocation: string | null }> {
  const response = await fetchApiResponse('/Patient/dedupstart');
  if (response.status !== 202) {
    const body = await response.json().catch(() => null);
    throw new ApiError(response.status, response.statusText, body);
  }
  const contentLocation = response.headers.get('Content-Location');
  return { contentLocation };
}

// Polls the Content-Location URL from dedupstart.
// Returns { done: false } while running (202), { done: true, meta } when complete (200).
// meta contains totals/timestamp but NO groups array — fetch groups via fetchDedupPage().
// Throws on failure (5xx).
export async function pollDedupStatus(
  contentLocation: string
): Promise<{ done: false } | { done: true; meta: DedupJobMeta }> {
  const response = await fetchApiResponse(contentLocation);
  if (response.status === 202) {
    return { done: false };
  }
  if (response.status === 200) {
    const meta = await response.json() as DedupJobMeta;
    return { done: true, meta };
  }
  const body = await response.json().catch(() => null);
  throw new ApiError(response.status, response.statusText, body);
}

// Fetch one page of dedup groups.
export async function fetchDedupPage(offset = 0, count = 20): Promise<DedupResult> {
  return fetchApi(`/Patient/dedup?_count=${count}&_offset=${offset}`) as Promise<DedupResult>;
}

export async function rejectDedupMatch(patientId1: string, patientId2: string): Promise<unknown> {
  return fetchApi(`/Patient/dedupreject?patient1=${encodeURIComponent(patientId1)}&patient2=${encodeURIComponent(patientId2)}`);
}
