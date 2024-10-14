import ballerina/log;
import ballerina/websub;

configurable int PORT = ?;
configurable string WEB_SUB_HUB_URL = ?;
final string topic = "audit";

// service / on new http:Listener(PORT) {
//     isolated resource function post audits(InternalAuditEvent audit) returns http:STATUS_CREATED|http:STATUS_INTERNAL_SERVER_ERROR {
//         do {
//             check save(audit);
//             return http:STATUS_CREATED;
//         } on fail error e {
//             log:printError("Failed to save the audit event to the mongodb.", 'error = e);
//             return http:STATUS_INTERNAL_SERVER_ERROR;
//         }
//     }
// }

@websub:SubscriberServiceConfig {
    target: [WEB_SUB_HUB_URL, topic],
    leaseSeconds: 36000,
    unsubscribeOnShutdown: true
}
service /audit on new websub:Listener(PORT) {
    function init() {
        log:printInfo("FHIR Audit Service is started...", port = PORT);
    }

    remote function onEventNotification(readonly & websub:ContentDistributionMessage msg) returns websub:Acknowledgement {
        log:printInfo("Received content ");
        do {
            json content = <json>msg.content;
            InternalAuditEvent auditEvent = check content.fromJsonWithType(InternalAuditEvent);
            check save(auditEvent);
        } on fail error e {
            log:printError("Failed to audit the event.", 'error = e);
        }
        return websub:ACKNOWLEDGEMENT;
    }
}

