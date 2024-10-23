import ballerina/http;
import ballerina/io;
import ballerinax/health.hl7v2;
import ballerinax/health.hl7v2.utils.v2tofhirr4;

public isolated function getHTTPMessageBuilder(string contentType) returns HTTPMessageBuilder|error {
    map<HTTPMessageBuilder> messageBuilders = {
        "application/json": new JsonToFhirBuilder()
        // "application/json": new JSONToXMLBuilder()
        // others

    };
    return messageBuilders[contentType] ?: error("Message builder not found for content type: " + contentType);
}

public isolated function getTCPMessageBuilder(string contentType) returns TCPMessageBuilder|error {
    map<TCPMessageBuilder> messageBuilders = {
        "hl7": new HL7toFhirBuilder()
        // others

    };
    return messageBuilders[contentType] ?: error("Message builder not found for content type: " + contentType);
}

public class JsonToFhirBuilder {
    *HTTPMessageBuilder;

    public isolated function init() {
        io:println("Created an instance of JsonToFhirBuilder");
    }

    public isolated function process(http:Request req) returns http:Request|error {
        check req.setContentType("application/json+fhir");
        return req;
    }

}

public class HL7toFhirBuilder {
    *TCPMessageBuilder;

    public isolated function init() {
        io:println("Created an instance of JsonToFhirBuilder");
    }

    public isolated function process(string data) returns TcpRequestContext|error {

        // parse 
        hl7v2:Message hl7Message = check parseHl7Message(data);

        // transform
        json v2tofhirResult = check v2tofhirr4:v2ToFhir(hl7Message);

        TcpRequestContext reqCtx = {
            fhirMessage: v2tofhirResult,
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
}

