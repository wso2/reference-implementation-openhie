const AUDIT_BASE = '/audit-api';

export async function postAuditEvent(auditEvent) {
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

/**
 * Transform a FHIR R4 AuditEvent into the flat shape the UI expects.
 */
function transformAuditEvent(fhirEvent) {
  const subtype = fhirEvent.subtype?.[0]?.code || fhirEvent.action || 'unknown';

  // Collect all entities (merge events carry 2)
  const entities = (fhirEvent.entity || []).map(e => ({
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

export async function fetchAuditLogs(filters = {}) {
  try {
    const query = new URLSearchParams(filters).toString();
    const response = await fetch(
      `${AUDIT_BASE}/audits${query ? '?' + query : ''}`
    );
    if (!response.ok) {
      throw new Error(`Audit fetch failed with status ${response.status}`);
    }
    const fhirEvents = await response.json();
    return Array.isArray(fhirEvents)
      ? fhirEvents.map(transformAuditEvent)
      : [];
  } catch (error) {
    console.error('Failed to fetch audit logs:', error);
    throw error;
  }
}
