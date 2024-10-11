import ballerina/http;
import ballerina/log;
import ballerina/time;

configurable string AUDIT_SERVICE = ?;
final http:Client AuditClient;

function init() returns error? {
    AuditClient = check new (AUDIT_SERVICE);
    log:printInfo("AuditClient created successfully.");
    return;
}

public isolated function audit_request(workflow workflow, string username, string patientID, string sysname) returns error? {

    match workflow {
        PATIENT_DEMOGRAPHICS_QUERY => {
            check audit_PDQ_Request(username, patientID, sysname, "0");
        }

        // Add more cases for other workflows
        _ => {
            log:printError("Invalid workflow.");
        }
    }
}

// audit events for each workflow 
public isolated function audit_PDQ_Request(string username, string patientID, string sysname, string outcome) returns error? {
    InternalAuditEvent auditEvent = {
        typeCode: "110112",
        subTypeCode: "READ",
        actionCode: "R",
        outcomeCode: outcome,
        recordedTime: time:utcToString(time:utcNow(3)),
        agentType: "User",
        agentName: username,
        agentIsRequestor: true,
        sourceObserverName: sysname,
        sourceObserverType: "3", // Assuming "3" is the appropriate type for the source observer
        entityType: "2", // Object type for a person (patient)
        entityRole: "1", // 1 for patient role
        entityWhatReference: patientID
    };
    check sendAuditEvent(auditEvent);
}

// public isolated function audit_PDQ_Response(string username, string patientID, string sysname, string outcome) returns error? {
//     InternalAuditEvent auditEvent = {
//         typeCode: "110112",
//         subTypeCode: "READ",
//         actionCode: "E",
//         outcomeCode: outcome,
//         recordedTime: time:utcToString(time:utcNow(3)),
//         agentType: "User",
//         agentName: username,
//         agentIsRequestor: true,
//         sourceObserverName: sysname,
//         sourceObserverType: "3", // Assuming "3" is the appropriate type for the source observer
//         entityType: "2", // Object type for a person (patient)
//         entityRole: "1", // 1 for patient role
//         entityWhatReference: patientID
//     };
//     check sendAuditEvent(auditEvent);
// }

isolated function sendAuditEvent(InternalAuditEvent auditEvent) returns error? {
    InternalAuditEvent auditmsg = auditEvent.cloneReadOnly();
    http:STATUS_CREATED|http:STATUS_INTERNAL_SERVER_ERROR response = check AuditClient->/audits.post(auditmsg);
    if (response is http:STATUS_CREATED) {
        log:printInfo("Audit event sent successfully.");
    }
    if (response is http:STATUS_INTERNAL_SERVER_ERROR) {
        log:printError("Something went wrong with audit service.");
    }
}
