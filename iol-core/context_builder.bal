import ballerina/http;

public isolated function buildRequestContextForHTTP(http:Request originalReq, http:Request transformedReq) returns HTTPRequstContext|error {
    // TODO:extract user details
    // var userDetails = check extractUserDetails(req);
    HTTPRequstContext reqCtx = {
        username: "test_username",
        patientId: "test_patientId",
        contentType: originalReq.getContentType(),
        httpRequest: transformedReq
    };

    return reqCtx;
}

public isolated function buildRequestContextForTCP(string data, json transformedData, string in_contentType) returns TcpRequestContext|error {
    // TODO: extract user details
    TcpRequestContext reqCtx = {
        contentType: in_contentType,
        username: "test-username",
        fhirMessage: transformedData,
        msgId: extractHL7MessageId(data),
        eventCode: extractHL7MessageType(data),
        patientId: extractPatientId(data),
        sendingFacility: extractSendingFacility(data),
        receivingFacility: extractReceivingFacility(data),
        sendingApplication: extractSendingApplication(data),
        receivingApplication: extractRecievingApplication(data)
    };
    return reqCtx;
}
