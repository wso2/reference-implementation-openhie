import ballerina/http;

public isolated function buildRequestContextForHTTP(http:Request originalReq, http:Request transformedReq) returns HTTPRequstContext|error {
    // TODO:extract user details
    map<string> userDetails = check extractUserDetails(originalReq);
    HTTPRequstContext reqCtx = {
        username: userDetails["username"]?:"",
        patientId: originalReq.getQueryParamValue("Patient") ?: "",
        contentType: originalReq.getContentType(),
        httpRequest: transformedReq
    };
    return reqCtx;
}

public isolated function buildRequestContextForTCP(string data, json transformedData, string in_contentType) returns TcpRequestContext|error {
    // TODO: extract user details
    TcpRequestContext reqCtx = {
        contentType: in_contentType,
        username: extractSendingApplication(data),
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
