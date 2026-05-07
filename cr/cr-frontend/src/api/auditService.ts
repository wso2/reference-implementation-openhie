import type { AuditLogEntry, AuditLogFilters } from '../types';

const AUDIT_BASE = '/audit-api';

export async function postAuditEvent(auditEvent: unknown): Promise<Response> {
  const response = await fetch(`${AUDIT_BASE}/audits`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(auditEvent),
  });
  if (!response.ok) {
    console.warn('Failed to post audit event', response.status);
  }
  return response;
}

interface FhirAuditEvent {
  id: string;
  recorded: string;
  action?: string;
  outcome?: string;
  outcomeDesc?: string;
  subtype?: { code: string }[];
  agent?: { who?: { display?: string }; network?: { address?: string } }[];
  entity?: { what?: { reference?: string }; role?: { code?: string } }[];
}

/**
 * Transform a FHIR R4 AuditEvent into the flat shape the UI expects.
 */
function transformAuditEvent(fhirEvent: FhirAuditEvent): AuditLogEntry {
  const subtype = fhirEvent.subtype?.[0]?.code || fhirEvent.action || 'unknown';

  // Collect all entities (merge events carry 2)
  const entities = (fhirEvent.entity || []).map((e) => ({
    reference: e.what?.reference || '',
    role: e.role?.code === '24' ? 'Query' : 'Record',
  }));

  return {
    id: fhirEvent.id,
    timestamp: fhirEvent.recorded,
    user: fhirEvent.agent?.[0]?.who?.display || 'unknown',
    clientIp: fhirEvent.agent?.[0]?.network?.address || '',
    action: subtype.toUpperCase(),
    actionCode: fhirEvent.action || '',   // raw FHIR code: R / C / U / D / E
    details: entities[0]?.reference || '',
    entities,
    outcome: fhirEvent.outcome === '0' ? 'success' : 'failure',
    reason: fhirEvent.outcomeDesc || '',
  };
}

export async function fetchAuditLogs(filters: AuditLogFilters = {}): Promise<AuditLogEntry[]> {
  try {
    const query = new URLSearchParams(
      Object.fromEntries(
        Object.entries(filters)
          .filter(([, v]) => v != null)
          .map(([k, v]) => [k, String(v)])
      )
    ).toString();
    const response = await fetch(
      `${AUDIT_BASE}/audits${query ? '?' + query : ''}`
    );
    if (!response.ok) {
      throw new Error(`Audit fetch failed with status ${response.status}`);
    }
    const fhirEvents = await response.json() as FhirAuditEvent[];
    return Array.isArray(fhirEvents)
      ? fhirEvents.map(transformAuditEvent)
      : [];
  } catch (error) {
    console.error('Failed to fetch audit logs:', error);
    throw error;
  }
}
