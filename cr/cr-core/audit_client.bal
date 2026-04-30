// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0

// Audit Service Client for Client Registry
// =========================================
// Integrates with FHIR Audit Service for ITI-20 ATNA compliance

import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.ihe.pdqm320 as pdqm;

// ============================================================
// CONFIGURATION
// ============================================================

// Audit service URL - matches your api_config.bal auditConfig
configurable string auditServiceUrl = ?;
configurable boolean auditEnabled = ?;
configurable string sourceObserverName = ?;

// HTTP client for audit service
final http:Client auditClient = check new (auditServiceUrl);

// ============================================================
// AUDIT HELPER FUNCTIONS
// ============================================================

# Send audit event to the audit service
#
# + auditEvent - The audit event to send
isolated function sendAuditEvent(international401:AuditEvent auditEvent) {
    if !auditEnabled {
        return;
    }

    do {
        string auditId = auditEvent.id is string ? <string>auditEvent.id : "";
        http:Response|http:ClientError response = auditClient->post("/audits", auditEvent);
        if response is http:ClientError {
            log:printWarn("Failed to send audit event", 'error = response, auditId = auditId);
        } else if response.statusCode >= 400 {
            log:printWarn("Audit service returned error", statusCode = response.statusCode, auditId = auditId);
        } else {
            log:printDebug("Audit event sent successfully", auditId = auditId);
        }
    } on fail error e {
        // Log but don't fail the main operation
        log:printWarn("Exception sending audit event", 'error = e);
    }
}

isolated function sendPdqmQueryAuditEvent(pdqm:AuditPdqmQuerySupplier auditEvent) {
    if !auditEnabled {
        return;
    }
    do {
        string auditId = auditEvent.id is string ? <string>auditEvent.id : "";
        http:Response|http:ClientError response = auditClient->post("/audits", auditEvent);
        if response is http:ClientError {
            log:printWarn("Failed to send audit event", 'error = response, auditId = auditId);
        } else if response.statusCode >= 400 {
            log:printWarn("Audit service returned error", statusCode = response.statusCode, auditId = auditId);
        } else {
            log:printDebug("Audit event sent successfully", auditId = auditId);
        }
    } on fail error e {
        log:printWarn("Exception sending audit event", 'error = e);
    }
}

isolated function sendPdqmMatchAuditEvent(pdqm:AuditPdqmMatchSupplier auditEvent) {
    if !auditEnabled {
        return;
    }
    do {
        string auditId = auditEvent.id is string ? <string>auditEvent.id : "";
        http:Response|http:ClientError response = auditClient->post("/audits", auditEvent);
        if response is http:ClientError {
            log:printWarn("Failed to send audit event", 'error = response, auditId = auditId);
        } else if response.statusCode >= 400 {
            log:printWarn("Audit service returned error", statusCode = response.statusCode, auditId = auditId);
        } else {
            log:printDebug("Audit event sent successfully", auditId = auditId);
        }
    } on fail error e {
        log:printWarn("Exception sending audit event", 'error = e);
    }
}

# Get current timestamp in ISO format
# + return - Current time as ISO 8601 string
isolated function getCurrentTimestamp() returns string {
    return time:utcToString(time:utcNow());
}

isolated function getCoding(string system, string code) returns r4:Coding => {
    system: system,
    code: code
};

isolated function getAgent(string agentName) returns international401:AuditEventAgent {
    return {
        'type: {
            coding: [getCoding("http://terminology.hl7.org/CodeSystem/extra-security-role-type", "humanuser")]
        },
        who: {
            display: agentName
        },
        requestor: true
    };
}

isolated function getEntity(string entityType, string entityRole, string entityWhatReference)
        returns international401:AuditEventEntity {
    return {
        'type: getCoding("http://terminology.hl7.org/CodeSystem/audit-entity-type", entityType),
        role: getCoding("http://terminology.hl7.org/CodeSystem/object-role", entityRole),
        what: {
            reference: entityWhatReference
        }
    };
}

isolated function buildAuditEvent(string subTypeCode, string actionCode, boolean success, string outcomeDesc,
        string agentName, international401:AuditEventEntity[] entities) returns international401:AuditEvent => {
    resourceType: "AuditEvent",
    id: uuid:createType1AsString(),
    'type: getCoding("http://terminology.hl7.org/CodeSystem/audit-event-type", "rest"),
    subtype: [getCoding("http://hl7.org/fhir/restful-interaction", subTypeCode)],
    action: actionCode,
    outcome: success ? "0" : "4",
    outcomeDesc: outcomeDesc != "" ? outcomeDesc : (),
    recorded: getCurrentTimestamp(),
    agent: [getAgent(agentName)],
    entity: entities,
    'source: {
        observer: {
            display: sourceObserverName
        },
        'type: [getCoding("http://terminology.hl7.org/CodeSystem/security-source-type", "4")]
    }
};

// ============================================================
// AUDIT EVENT BUILDERS
// ============================================================

# Create audit event for Patient Read (ITI-78)
#
# + patientId - The patient ID being read
# + agentName - Name of the user/system performing the read
# + success - Whether the operation succeeded
# + reason - Optional failure reason
# + return - Configured audit event
public isolated function auditPatientRead(string patientId, string agentName, boolean success, string reason = "")
        returns international401:AuditEvent {
    return buildAuditEvent("read", "R", success, reason, agentName, [
        getEntity("1", "1", string `Patient/${patientId}`)
    ]);
}

# Create audit event for Patient Search (ITI-78) — IHE.PDQm.Query.Audit.Supplier profile
#
# + queryString - The URL query parameters (e.g. "family=Smith&given=John")
# + agentName - Identity of the PDQm Consumer (requesting client)
# + patientId - First matched patient ID, empty string when no results or on failure
# + success - Whether the operation succeeded
# + reason - Optional failure reason
# + return - Configured ITI-78 Supplier audit event
public isolated function auditPatientSearch(string queryString, string agentName, string patientId,
        boolean success, string reason = "") returns pdqm:AuditPdqmQuerySupplier {
    pdqm:AuditPdqmQuerySupplierSubtypeIti78 iti78Subtype = {};
    pdqm:AuditPdqmQuerySupplierType auditType = {};

    string base64Query = (string `Patient?${queryString}`).toBytes().toBase64();
    pdqm:AuditPdqmQuerySupplierEntity queryEntity = {
        'type: {system: "http://terminology.hl7.org/CodeSystem/audit-entity-type", code: "2", display: "System Object"},
        role: {system: "http://terminology.hl7.org/CodeSystem/object-role", code: "24", display: "Query"},
        query: base64Query
    };
    pdqm:AuditPdqmQuerySupplierEntity[] entities = [queryEntity];
    if patientId != "" {
        entities.push({
            'type: {system: "http://terminology.hl7.org/CodeSystem/audit-entity-type", code: "1", display: "Person"},
            role: {system: "http://terminology.hl7.org/CodeSystem/object-role", code: "1", display: "Patient"},
            what: {reference: string `Patient/${patientId}`}
        });
    }

    return {
        id: uuid:createType1AsString(),
        meta: {profile: [pdqm:PROFILE_BASE_AUDITPDQMQUERYSUPPLIER]},
        'type: auditType,
        subtype: [
            iti78Subtype,
            {system: "http://hl7.org/fhir/restful-interaction", code: "search", display: "search"}
        ],
        action: "E",
        outcome: success ? "0" : "4",
        outcomeDesc: reason != "" ? reason : (),
        recorded: getCurrentTimestamp(),
        agent: [
            // PDQm Consumer — source of the request
            {
                'type: {coding: [{system: "http://dicom.nema.org/resources/ontology/DCM", code: "110153", display: "Source Role ID"}]},
                who: {display: agentName},
                requestor: false
            },
            // PDQm Supplier — our server receiving the request
            {
                'type: {coding: [{system: "http://dicom.nema.org/resources/ontology/DCM", code: "110152", display: "Destination Role ID"}]},
                who: {display: baseUrl},
                requestor: false,
                network: {address: baseUrl, 'type: "5"}
            }
        ],
        'source: {
            observer: {display: sourceObserverName},
            'type: [{system: "http://terminology.hl7.org/CodeSystem/security-source-type", code: "4", display: "Application Server"}]
        },
        entity: entities
    };
}

# Create audit event for Patient Match (ITI-119) — IHE.PDQm.Match.Audit.Supplier profile
#
# + agentName - Identity of the PDQm Consumer (requesting client)
# + queryBody - JSON string of the Parameters resource sent in the $match request
# + patientId - Matched patient ID, empty string when no match or on failure
# + success - Whether the operation succeeded
# + reason - Optional failure reason
# + return - Configured ITI-119 Supplier audit event
public isolated function auditPatientMatch(string agentName, string queryBody, string patientId,
        boolean success, string reason = "") returns pdqm:AuditPdqmMatchSupplier {
    pdqm:AuditPdqmMatchSupplierSubtypeIti119 iti119Subtype = {};
    pdqm:AuditPdqmMatchSupplierType auditType = {};

    string base64Query = queryBody.toBytes().toBase64();
    pdqm:AuditPdqmMatchSupplierEntity queryEntity = {
        'type: {system: "http://terminology.hl7.org/CodeSystem/audit-entity-type", code: "2", display: "System Object"},
        role: {system: "http://terminology.hl7.org/CodeSystem/object-role", code: "24", display: "Query"},
        query: base64Query
    };
    pdqm:AuditPdqmMatchSupplierEntity[] entities = [queryEntity];
    if patientId != "" {
        entities.push({
            'type: {system: "http://terminology.hl7.org/CodeSystem/audit-entity-type", code: "1", display: "Person"},
            role: {system: "http://terminology.hl7.org/CodeSystem/object-role", code: "1", display: "Patient"},
            what: {reference: string `Patient/${patientId}`}
        });
    }

    return {
        id: uuid:createType1AsString(),
        meta: {profile: [pdqm:PROFILE_BASE_AUDITPDQMMATCHSUPPLIER]},
        'type: auditType,
        subtype: [
            iti119Subtype,
            {system: "http://hl7.org/fhir/restful-interaction", code: "search", display: "search"}
        ],
        action: "E",
        outcome: success ? "0" : "4",
        outcomeDesc: reason != "" ? reason : (),
        recorded: getCurrentTimestamp(),
        agent: [
            // PDQm Consumer — source of the request
            {
                'type: {coding: [{system: "http://dicom.nema.org/resources/ontology/DCM", code: "110153", display: "Source Role ID"}]},
                who: {display: agentName},
                requestor: false
            },
            // PDQm Supplier — our server receiving the request
            {
                'type: {coding: [{system: "http://dicom.nema.org/resources/ontology/DCM", code: "110152", display: "Destination Role ID"}]},
                who: {display: baseUrl},
                requestor: false,
                network: {address: baseUrl, 'type: "5"}
            }
        ],
        'source: {
            observer: {display: sourceObserverName},
            'type: [{system: "http://terminology.hl7.org/CodeSystem/security-source-type", code: "4", display: "Application Server"}]
        },
        entity: entities
    };
}

# Create audit event for Patient Create (ITI-104)
#
# + patientId - The newly created patient ID
# + agentName - Name of the user/system creating the patient
# + success - Whether the operation succeeded
# + reason - Optional failure reason
# + return - Configured audit event
public isolated function auditPatientCreate(string patientId, string agentName, boolean success, string reason = "")
        returns international401:AuditEvent {
    return buildAuditEvent("create", "C", success, reason, agentName, [
        getEntity("1", "1", string `Patient/${patientId}`)
    ]);
}

# Create audit event for Patient Update (ITI-104)
#
# + patientId - The patient ID being updated
# + agentName - Name of the user/system updating the patient
# + success - Whether the operation succeeded
# + reason - Optional failure reason
# + return - Configured audit event
public isolated function auditPatientUpdate(string patientId, string agentName, boolean success, string reason = "")
        returns international401:AuditEvent {
    return buildAuditEvent("update", "U", success, reason, agentName, [
        getEntity("1", "1", string `Patient/${patientId}`)
    ]);
}

# Create audit event for Patient Delete (ITI-104)
#
# + patientId - The patient ID being deleted
# + agentName - Name of the user/system deleting the patient
# + success - Whether the operation succeeded
# + reason - Optional failure reason
# + return - Configured audit event
public isolated function auditPatientDelete(string patientId, string agentName, boolean success, string reason = "")
        returns international401:AuditEvent {
    return buildAuditEvent("delete", "D", success, reason, agentName, [
        getEntity("1", "1", string `Patient/${patientId}`)
    ]);
}

# Create audit event for Patient Deduplication
#
# + agentName - Name of the user/system running dedup
# + groupCount - Number of match groups found
# + success - Whether the operation succeeded
# + reason - Optional failure reason
# + return - Configured audit event
public isolated function auditPatientDedup(string agentName, int groupCount, boolean success, string reason = "")
        returns international401:AuditEvent {
    string outcomeDesc = reason != "" ? reason : (success ? string `Dedup found ${groupCount} group(s)` : "");
    return buildAuditEvent("operation", "E", success, outcomeDesc, agentName, [
        getEntity("1", "24", "Patient/dedup")
    ]);
}

// ============================================================
// CONVENIENCE FUNCTIONS (Fire-and-forget)
// ============================================================

# Audit a patient read operation (fire-and-forget)
#
# + patientId - The patient ID
# + agentName - The agent performing the action
# + success - Whether the operation succeeded
# + reason - Optional failure reason
public function auditRead(string patientId, string agentName, boolean success, string reason = "") {
    _ = start sendAuditEvent(auditPatientRead(patientId, agentName, success, reason));
}

# Audit a patient search operation (fire-and-forget, ITI-78 Supplier profile)
#
# + queryString - The URL query parameters
# + agentName - Identity of the PDQm Consumer (requesting client)
# + patientId - First matched patient ID, empty string when no results or on failure
# + resultCount - Number of results
# + success - Whether the operation succeeded
# + reason - Optional failure reason
public function auditSearch(string queryString, string agentName, string patientId, int resultCount, boolean success,
        string reason = "") {
    _ = start sendPdqmQueryAuditEvent(auditPatientSearch(queryString, agentName, patientId, success, reason));
}

# Audit a patient match operation (fire-and-forget, ITI-119 Supplier profile)
#
# + agentName - Identity of the PDQm Consumer (requesting client)
# + queryBody - JSON string of the Parameters resource sent in the $match request
# + patientId - Matched patient ID, empty string when no match or on failure
# + matchCount - Number of matches found
# + success - Whether the operation succeeded
# + reason - Optional failure reason
public function auditMatch(string agentName, string queryBody, string patientId,
        int matchCount, boolean success, string reason = "") {
    _ = start sendPdqmMatchAuditEvent(auditPatientMatch(agentName, queryBody, patientId, success, reason));
}
# Audit a patient create operation (fire-and-forget)
#
# + patientId - The patient ID
# + agentName - The agent performing the action
# + success - Whether the operation succeeded
# + reason - Optional failure reason
public function auditCreate(string patientId, string agentName, boolean success, string reason = "") {
    _ = start sendAuditEvent(auditPatientCreate(patientId, agentName, success, reason));
}

# Audit a patient update operation (fire-and-forget)
#
# + patientId - The patient ID
# + agentName - The agent performing the action
# + success - Whether the operation succeeded
# + reason - Optional failure reason
public function auditUpdate(string patientId, string agentName, boolean success, string reason = "") {
    _ = start sendAuditEvent(auditPatientUpdate(patientId, agentName, success, reason));
}

# Audit a patient delete operation (fire-and-forget)
#
# + patientId - The patient ID
# + agentName - The agent performing the action
# + success - Whether the operation succeeded
# + reason - Optional failure reason
public function auditDelete(string patientId, string agentName, boolean success, string reason = "") {
    _ = start sendAuditEvent(auditPatientDelete(patientId, agentName, success, reason));
}

# Audit a patient dedup operation (fire-and-forget)
#
# + agentName - The agent performing the action
# + groupCount - Number of match groups found
# + success - Whether the operation succeeded
# + reason - Optional failure reason
public function auditDedup(string agentName, int groupCount, boolean success, string reason = "") {
    _ = start sendAuditEvent(auditPatientDedup(agentName, groupCount, success, reason));
}

# Audit a patient merge/resolve duplicate operation (fire-and-forget)
#
# + subsumedId - The patient ID being subsumed (marked inactive)
# + survivingId - The patient ID that survives
# + agentName - The agent performing the action
# + success - Whether the operation succeeded
# + reason - Optional failure reason
public function auditMerge(string subsumedId, string survivingId, string agentName, boolean success, string reason = "") {
    _ = start sendAuditEvent(buildAuditEvent("update", "U", success,
        reason != "" ? reason : string `Merge: Patient/${subsumedId} replaced-by Patient/${survivingId}`,
        agentName, [
            getEntity("1", "1", string `Patient/${subsumedId}`),
            getEntity("1", "1", string `Patient/${survivingId}`)
        ]));
}
