import ballerina/log;
import ballerina/websub;
import ballerina/websubhub;

configurable int PORT = ?;
configurable string WEBSUB_HUB_URL = ?;
configurable string TOPIC = ?;
configurable string OPENSEARCH_TOPIC = ?;

isolated websubhub:PublisherClient websubHubClientEP = check new (WEBSUB_HUB_URL);

@websub:SubscriberServiceConfig {
    target: [WEBSUB_HUB_URL, TOPIC],
    leaseSeconds: 36000,
    unsubscribeOnShutdown: true
}
service /audit on new websub:Listener(PORT) {
    function init() returns error? {
        log:printInfo("FHIR Audit Service is starting...", port = PORT);
    }

    isolated remote function onEventNotification(readonly & websub:ContentDistributionMessage msg) returns websub:Acknowledgement {
        log:printInfo("Received content ");
        do {
            json content = <json>msg.content;
            InternalAuditEvent auditEvent = check content.fromJsonWithType(InternalAuditEvent);
            json fhir_audit = check save(auditEvent);
            lock {
                websubhub:Acknowledgement|websubhub:UpdateMessageError ack = websubHubClientEP->publishUpdate(OPENSEARCH_TOPIC, fhir_audit.cloneReadOnly());
                if (ack is websubhub:UpdateMessageError) {
                    log:printError("Failed to publish the audit event to the OpenSearch topic.");
                }
                log:printInfo("Audit event published to the OpenSearch topic.");
            }

        } on fail error e {
            log:printError("Failed to audit the event.", 'error = e);
        }
        return websub:ACKNOWLEDGEMENT;
    }
}

