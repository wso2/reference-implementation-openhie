import ballerina/http;
import ballerina/test;
import ballerinax/health.fhir.r4.international401;

http:Client testClient = check new ("http://localhost:9093");

// Test functions
@test:Config {}
function testSendingAuditEvent1() {
    international401:AuditEvent auditEvent = {
        resourceType: "AuditEvent",
        id: "test-audit-event-1",
        'type: {
            system: "http://terminology.hl7.org/CodeSystem/audit-event-type",
            code: "rest"
        },
        subtype: [{
            system: "http://hl7.org/fhir/restful-interaction",
            code: "read"
        }],
        action: "R",
        outcome: "0",
        recorded: "2023-10-23T17:36:35.395477Z",
        agent: [{
            'type: {
                coding: [{
                    system: "http://terminology.hl7.org/CodeSystem/extra-security-role-type",
                    code: "humanuser"
                }]
            },
            who: {
                display: "Unknown"
            },
            requestor: true
        }],
        entity: [{
            'type: {
                system: "http://terminology.hl7.org/CodeSystem/audit-entity-type",
                code: "1"
            },
            role: {
                system: "http://terminology.hl7.org/CodeSystem/object-role",
                code: "1"
            },
            what: {
                reference: "Patient/test"
            }
        }],
        'source: {
            observer: {
                display: "test-client-registry"
            },
            'type: [{
                system: "http://terminology.hl7.org/CodeSystem/security-source-type",
                code: "4"
            }]
        }
    };
    international401:AuditEvent|error response = testClient->/audits.post(auditEvent);
    test:assertEquals(response is international401:AuditEvent, true);
}
