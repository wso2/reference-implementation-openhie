import ballerina/http;
import ballerina/io;
import ballerina/xmldata;

public isolated function getMessageFormatter(string contentType) returns MessageFormatter|error {
    map<MessageFormatter> messageFormatters = {
        "application/xml": new JSONToXMLFormatter()
        // Add other formatters here
    };
    return messageFormatters[contentType] ?: error("Message formatter not found for content type: " + contentType);
}

public class JSONToXMLFormatter {
    *MessageFormatter;

    public isolated function init() {
        io:println("JSONToXMLFormatter initialized");
    }

    public isolated function format(http:Response res) returns http:Response|error {
        json payload = check res.getJsonPayload();
        xml? xmlPayload = check xmldata:fromJson(payload);
        res.setPayload(xmlPayload);
        check res.setContentType("application/xml");
        return res;
    }
}
