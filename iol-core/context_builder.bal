import ballerina/http;
import ballerinax/health.hl7v2;
import ballerinax/health.hl7v24;

public isolated function buildRequestContextForHTTP(http:Request originalReq, http:Request transformedReq) returns HTTPRequstContext|error {
    // TODO:extract user details
    map<string> userDetails = check extractUserDetails(originalReq);
    return {
        username: userDetails["username"] ?: "",
        patientId: originalReq.getQueryParamValue("Patient") ?: "",
        contentType: originalReq.getContentType(),
        httpRequest: transformedReq
    };
}

public isolated function buildRequestContextForTCP(string data, hl7v2:Message hl7Message, json transformedData, string in_contentType) returns TcpRequestContext|error {
    // TODO: extract user details
    hl7v24:MSH msh = <hl7v24:MSH>hl7Message["msh"];
    return {
        contentType: in_contentType,
        username: msh.msh3.hd1,
        fhirMessage: transformedData,
        msgId: msh.msh10,
        eventCode: extractHl7MessageType(data),
        patientId: extractPatientId(data),
        sendingFacility: msh.msh4.hd1,
        receivingFacility: msh.msh6.hd1,
        sendingApplication: msh.msh3.hd1,
        receivingApplication: msh.msh5.hd1
    };
}
