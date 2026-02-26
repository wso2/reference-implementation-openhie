import ballerina/http;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4;
import ballerina/io;
import ballerina/log;
import ballerina/cache;
import ballerina/uuid;
import ballerinax/health.fhir.r4.terminology;
import ballerina/task;

// in Choreo context, this is expected to be a path in a file mount 
configurable string auditLogPath = "/tmp/audit-logs/fhir-audit.log";
// capacity of the cache used to store the failed audit events till they are retried
configurable int cacheCapacity = 1000;
// name of the fhir server. This is used as the source observer name in the FHIR audit event
configurable string fhirServerName = "wso2fhirserver.com";
// agent type of the audit event. This is used as the agent type in the FHIR audit event
configurable string agentType = "humanuser";

// This creates a new cache with the advanced configuration.
final cache:Cache cache = new ({
    capacity: cacheCapacity
});

// Retry failed audit events
class RetryFailedAuditEvents {

    *task:Job;

    public function init() {
        log:printDebug("Initialized the `retry failed audit events` task.");
    }

    // Executes this function when the scheduled trigger fires.
    public function execute() {
        int i = 0;
        if cache.size() > 0 {
            log:printDebug("Retrying to write failed audit events to the log file.", numberOfFailedAuditEvents = cache.size());
        }
        while i < cache.size() {
            // retry to write to the audit log file
            international401:AuditEvent|error auditEvent = cache.get(cache.keys()[i]).ensureType();
            if (auditEvent is international401:AuditEvent) {
                io:Error? result = io:fileWriteLines(auditLogPath, [auditEvent.toJsonString()], option = io:APPEND);
                if !(result is io:Error) {
                    // if retrying is successful, remove from the cache
                    check cache.invalidate(cache.keys()[i]);
                    log:printDebug("Successfully wrote the audit event to the log file.", id = auditEvent.id);
                } else {
                    i += 1;
                    log:printDebug("Failed to retry writing the audit event to the log file. Retrying...", id = auditEvent.id, 'error = result);
                }
            }

        } on fail var e {
            // keep retrying
            log:printDebug("Failed to retry writing the audit event to the log file. Retrying...", e);
        }
    }
}

int port = 9093;

service / on new http:Listener(port) {

    function init() returns error? {
        // this is an internal task, hence the interval does not needs to be a configurable. 
        _ = check task:scheduleJobRecurByFrequency(
                            new RetryFailedAuditEvents(), 30);
        log:printInfo("FHIR Audit Service is started...", port = port);
    }

    // GET /audits - Read audit events from the log file
    isolated resource function get audits(http:Request req, string? action, string? subtype,
            string? since, string? before, int 'limit = 50, int offset = 0, string sortOrder = "desc")
            returns json|http:STATUS_INTERNAL_SERVER_ERROR {
        json[] auditEvents = [];
        do {
            // Check if the log file exists by attempting to read it
            string[] lines = check io:fileReadLines(auditLogPath);
            foreach string line in lines {
                if line.trim().length() == 0 {
                    continue;
                }
                json|error parsed = line.fromJsonString();
                if parsed is json {
                    // Skip framework-generated audit events (source: wso2fhirserver.com)
                    json|error sourceObserver = parsed.'source.observer.display;
                    if sourceObserver is json && sourceObserver.toString() == fhirServerName {
                        continue;
                    }

                    // Apply optional filters
                    boolean include = true;
                    if action is string {
                        json|error eventAction = parsed.action;
                        if eventAction is json {
                            include = eventAction.toString() == action;
                        }
                    }
                    if include && subtype is string {
                        json|error subtypeArr = parsed.subtype;
                        if subtypeArr is json {
                            string subtypeStr = subtypeArr.toString();
                            include = subtypeStr.includes(subtype);
                        }
                    }
                    // Filter by timestamp range
                    if include && (since is string || before is string) {
                        json|error recordedTime = parsed.recorded;
                        if recordedTime is json {
                            string recorded = recordedTime.toString();
                            if since is string {
                                include = recorded > since;
                            }
                            if include && before is string {
                                include = recorded < before;
                            }
                        }
                    }
                    if include {
                        auditEvents.push(parsed);
                    }
                }
            }
        } on fail error e {
            // If the file doesn't exist yet, return empty array
            string errMsg = e.message();
            if errMsg.includes("no such file") || errMsg.includes("does not exist") || errMsg.includes("cannot find") || errMsg.includes("FileNotFound") {
                log:printDebug("Audit log file not found yet, returning empty array.");
                return auditEvents;
            }
            log:printError("Failed to read audit log file.", 'error = e);
            return http:STATUS_INTERNAL_SERVER_ERROR;
        }

        // Sort based on sortOrder (file is chronological, so reverse for desc)
        json[] sorted = [];
        if sortOrder == "asc" {
            sorted = auditEvents;
        } else {
            int i = auditEvents.length() - 1;
            while i >= 0 {
                sorted.push(auditEvents[i]);
                i -= 1;
            }
        }

        // Apply offset and limit for pagination
        json[] paginated = [];
        int startIdx = offset < 0 ? 0 : offset;
        int effectiveLimit = 'limit < 1 ? 50 : 'limit;
        int endIdx = startIdx + effectiveLimit;
        int idx = startIdx;
        while idx < endIdx && idx < sorted.length() {
            paginated.push(sorted[idx]);
            idx += 1;
        }
        return paginated;
    }

    isolated resource function post audits(international401:AuditEvent audit) returns international401:AuditEvent|http:STATUS_ACCEPTED|http:STATUS_INTERNAL_SERVER_ERROR {
        international401:AuditEvent auditEvent = audit;
        if !(auditEvent.id is string) || auditEvent.id == "" {
            auditEvent.id = uuid:createType1AsString();
        }
        io:Error? result = io:fileWriteLines(auditLogPath, [auditEvent.toJsonString()], option = io:APPEND);
        if result is io:Error {
            // keep track of failed audit events in an inmemory buffer and retry to write
            log:printWarn("Failed to write the audit event to the log file. Trying to put to a cache and retry later.", result, id = auditEvent.id, auditEvent = auditEvent.toJson());
            do {
                check cache.put(check auditEvent.id.ensureType(), auditEvent);
                return http:STATUS_ACCEPTED;
            } on fail error e {
                log:printError("[Critical] Failed to write to the log file and failed in adding it to the cache. Audit event will be lost.", 'error = e,
                auditEvent = auditEvent.toJson());
                return http:STATUS_INTERNAL_SERVER_ERROR;
            }
        } else {
            log:printDebug("Successfully wrote the audit event to the log file.", id = auditEvent.id);
        }
        return auditEvent;
    }
}

isolated function toFhirAuditEvent(InternalAuditEvent internalAuditEvent) returns international401:AuditEvent => {
    id: uuid:createType1AsString(),
    'type: getCoding("http://terminology.hl7.org/CodeSystem/audit-event-type", internalAuditEvent.typeCode),
    subtype: [getCoding("http://hl7.org/fhir/restful-interaction", internalAuditEvent.subTypeCode)],
    action: internalAuditEvent.actionCode,
    outcome: internalAuditEvent.outcomeCode,
    outcomeDesc: internalAuditEvent.outcomeDesc != "" ? internalAuditEvent.outcomeDesc : (),
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
