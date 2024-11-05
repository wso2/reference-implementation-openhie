// import ballerina/cache;
import ballerina/io;
import ballerina/log;
// import ballerina/task;
import ballerina/uuid;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.terminology;

// import ballerinax/mongodb;

// name of the fhir server. This is used as the source observer name in the FHIR audit event
configurable string fhirServerName = "wso2fhirserver.com";
// agent type of the audit event. This is used as the agent type in the FHIR audit event
configurable string agentType = "humanuser";

// configurable DBConfig dBConfig = ?;
// final mongodb:Client mongoClient;

function init() returns error? {
    // mongoClient = check new ({
    //     connection: {
    //         serverAddress: {
    //             host: dBConfig.host,
    //             port: dBConfig.port
    //         }
    //         // auth: <mongodb:ScramSha256AuthCredential>{
    //         //     username: dBConfig.username,
    //         //     password: dBConfig.password,
    //         //     database: dBConfig.dbname
    //         // }
    //     }
    // });
    // log:printInfo("MongoDB client Created Successfully");
}

isolated function save(InternalAuditEvent audit) returns json|error {
    international401:AuditEvent auditEvent = toFhirAuditEvent(audit);
    // mongodb:Database db = check mongoClient->getDatabase(dBConfig.dbname);
    // mongodb:Collection auditCollection = check db->getCollection("audit");
    // check auditCollection->insertOne(auditEvent);
    // Define the file path to save the audit event
    string:RegExp r1 = re `-`;
    string:RegExp r2 = re `:`;
    json auditEventJson = auditEvent.toJson();
    string filePath = string `./logs/audit_${r2.replaceAll(r1.replaceAll(audit.recordedTime, "_"), "_")}.json`;
    check io:fileWriteString(filePath, auditEventJson.toJsonString());
    log:printInfo("Audit message written to file successfully");
    return auditEventJson;
};

isolated function toFhirAuditEvent(InternalAuditEvent internalAuditEvent) returns international401:AuditEvent => {
    id: uuid:createType1AsString(),
    'type: getCoding("http://terminology.hl7.org/CodeSystem/audit-event-type", internalAuditEvent.typeCode),
    subtype: [getCoding("http://hl7.org/fhir/restful-interaction", internalAuditEvent.subTypeCode)],
    action: internalAuditEvent.actionCode,
    outcome: internalAuditEvent.outcomeCode,
    recorded: internalAuditEvent.recordedTime,
    agent: [getAgent(internalAuditEvent.agentType, internalAuditEvent.agentName, internalAuditEvent.agentIsRequestor)],
    entity: [getEntity(internalAuditEvent.entityType, internalAuditEvent.entityRole, internalAuditEvent.entityWhatReference)],
    'source: {
        observer: {
            display: internalAuditEvent.sourceObserverName == "" ? fhirServerName : internalAuditEvent.sourceObserverName
        },
        'type: [getCoding("http://terminology.hl7.org/CodeSystem/security-source-type", internalAuditEvent.sourceObserverType)]
    }
};

isolated function getCoding(string system, string code) returns r4:Coding {
    r4:Coding|r4:FHIRError fhirCode = terminology:createCoding(system, code);
    if (fhirCode is r4:FHIRError) {
        // means the code system is not available in the terminology server
        // skip the error and mark the value as unknown.
        return {
            system: system,
            code: code,
            display: "Unknown"
        };
    }
    return fhirCode;
};

isolated function getAgent(string 'type, string name, boolean isRequestor) returns international401:AuditEventAgent {
    international401:AuditEventAgent agent = {
        'type: {
            coding:
            [getCoding("http://terminology.hl7.org/CodeSystem/extra-security-role-type", 'type == "" ? agentType : 'type)]
        },
        who: {
            display: name
        },
        requestor: isRequestor
    };
    return agent;
};

isolated function getEntity(string 'type, string role, string whatReference) returns international401:AuditEventEntity {
    international401:AuditEventEntity entity = {
        'type: getCoding("http://terminology.hl7.org/CodeSystem/audit-entity-type", 'type),
        role: getCoding("http://terminology.hl7.org/CodeSystem/object-role", role),
        what: {
            reference: whatReference
        }
    };
    return entity;
};
