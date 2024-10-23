import ballerina/http;
import ballerina/io;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.parser;

public isolated function getHTTPMessageFormatter(string in_contentType) returns HTTPMessageFormatter|error {
    map<HTTPMessageFormatter> messageFormatters = {
        "application/json": new FhirToJsonFormatter()
        // Add other formatters here
    };
    return messageFormatters[in_contentType] ?: error("Message formatter not found for content type: " + in_contentType);
}

public isolated function getTCPMessageFormatter(string in_contentType) returns TCPMessageFormatter|error {
    map<TCPMessageFormatter> messageFormatters = {
        "hl7": new fhirToHL7Formatter()
        // Add other formatters here
    };
    return messageFormatters[in_contentType] ?: error("Message formatter not found for content type: " + in_contentType);
}

public class FhirToJsonFormatter {
    *HTTPMessageFormatter;

    public isolated function init() {
        io:println("JSONToXMLFormatter initialized");
    }

    public isolated function format(http:Response res) returns http:Response|error {
        check res.setContentType("application/json");
        return res;
    }
}

public class fhirToHL7Formatter {
    *TCPMessageFormatter;

    public isolated function init() {
        io:println("Created an instance of fhirToHL7Formatter");
    }

    public isolated function format(TcpResponseContext|error resCtx, TcpRequestContext reqCtx) returns byte[]|error {

        if resCtx is error {
            // TODO: get msgID
            return createHL7AckMessage(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, resCtx.message()).toBytes();
        }
        http:Response res = resCtx.httpResponse;
        workflow workflow = resCtx.workflow;

        match res.statusCode {
            // Handle successful responses
            http:STATUS_CREATED => {
                return createHL7AckMessage(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AA", reqCtx.msgId, "Resource created successfully!").toBytes();
            }
            http:STATUS_OK => {
                if workflow == PATIENT_DEMOGRAPHICS_QUERY {
                    // parse the json payload to a FHIR Patient resource
                    international401:Patient fhirPatient = check parser:parse(check res.getJsonPayload()).ensureType();

                    // Convert FHIR patient to HL7v2 message
                    string hl7msg = check mapFhirPatientToHL7(fhirPatient, reqCtx.receivingApplication, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.sendingFacility, reqCtx.msgId);
                    return hl7msg.toBytes();
                }
                return createHL7AckMessage(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AA", reqCtx.msgId, "Resource updated successfully!").toBytes();
            }
            // Handle unsuccessful responses
            _ => {
                return createHL7AckMessage(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, "Failed to process message").toBytes();
            }
        }

    }

}
