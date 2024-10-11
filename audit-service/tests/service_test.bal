import ballerina/http;
import ballerina/io;
import ballerina/test;

http:Client testClient = check new (string `http://localhost:9094`);

// Test functions
@test:Config {}
function testSendingAuditEvent1() {
    InternalAuditEvent auditEvent = {"typeCode": "rest", "subTypeCode": "READ", "actionCode": "R", "outcomeCode": "0", "recordedTime": "2023-10-23T17:36:35.395477Z", "agentType": "", "agentName": "Unknown", "agentIsRequestor": true, "sourceObserverName": "", "sourceObserverType": "3", "entityType": "2", "entityRole": "1", "entityWhatReference": ""};
    http:STATUS_CREATED|http:STATUS_INTERNAL_SERVER_ERROR|http:ClientError response = testClient->/audits.post(auditEvent);

    io:println(response);
    test:assertEquals(response is http:STATUS_CREATED, true);
}
