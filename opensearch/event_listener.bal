import ballerina/http;
import ballerina/log;
import ballerina/websub;

string OPEN_SEARCH_URL = "https://localhost:9200";
string OPEN_SEARCH_USERNAME = "admin";
string OPEN_SEARCH_PASSWORD = "534535345345!Mp";
final string OPEN_SEARCH_INDEX = "openhie-ref-impl-audit";
string WEB_SUB_HUB_URL = "http://localhost:9090/hub";
string WEB_SUB_TOPIC = "audit-fhir";
int PORT = 9097;

final http:Client openSearchClient = check new (OPEN_SEARCH_URL,
    // Disable SSL verification for testing purposes (not recommended for production)
    secureSocket = {
        enable: false
    },
    auth = {
        username: OPEN_SEARCH_USERNAME,
        password: OPEN_SEARCH_PASSWORD
    }
);

// json sample_data = {
//     "resourceType": "AuditEvent",
//     "agent": [
//         {
//             "type": {
//                 "coding": [
//                     {
//                         "system": "http://terminology.hl7.org/CodeSystem/extra-security-role-type",
//                         "code": "User",
//                         "display": "Unknown"
//                     }
//                 ]
//             },
//             "requestor": true,
//             "who": {
//                 "display": "test-username"
//             }
//         }
//     ],
//     "source": {
//         "observer": {
//             "display": "IOL-ref-impl"
//         },
//         "type": [
//             {
//                 "system": "http://terminology.hl7.org/CodeSystem/security-source-type",
//                 "code": "3",
//                 "display": "Web Server"
//             }
//         ]
//     },
//     "recorded": "2024-10-21T09:50:44.711Z",
//     "type": {
//         "system": "http://terminology.hl7.org/CodeSystem/audit-event-type",
//         "code": "110112",
//         "display": "Unknown"
//     },
//     "subtype": [
//         {
//             "system": "http://hl7.org/fhir/restful-interaction",
//             "code": "UPDATE",
//             "display": "Unknown"
//         }
//     ],
//     "action": "C",
//     "id": "01ef8f91-853a-1606-b154-d99c43b3a483",
//     "entity": [
//         {
//             "role": {
//                 "system": "http://terminology.hl7.org/CodeSystem/object-role",
//                 "code": "1",
//                 "display": "Patient"
//             },
//             "what": {
//                 "reference": "test-patientId"
//             },
//             "type": {
//                 "system": "http://terminology.hl7.org/CodeSystem/audit-entity-type",
//                 "code": "2",
//                 "display": "System Object"
//             }
//         }
//     ],
//     "outcome": "0"
// };

@websub:SubscriberServiceConfig {
    target: [WEB_SUB_HUB_URL, WEB_SUB_TOPIC],
    leaseSeconds: 36000,
    unsubscribeOnShutdown: true
}
service /openSearch on new websub:Listener(PORT) {
    function init() {
        log:printInfo("Open Search web sub listener is started...", port = PORT);
    }

    isolated remote function onEventNotification(readonly & websub:ContentDistributionMessage msg) returns websub:Acknowledgement {
        log:printInfo("Received content ");
        do {
            json data = <json>msg.content;
            http:Response response = check openSearchClient->post(string `/${OPEN_SEARCH_INDEX}/_doc`, data);
            log:printInfo("Response from OpenSearch: ", response.getTextPayload().ensureType());
        } on fail error e {
            log:printError("Failed to send event to open search.", 'error = e);
        }
        return websub:ACKNOWLEDGEMENT;
    }
}
