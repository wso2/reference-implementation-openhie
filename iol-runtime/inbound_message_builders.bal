import ballerina/http;
import ballerina/io;
import ballerina/xmldata;

public isolated function getMessageBuilder(string contentType) returns MessageBuilder|error {
    map<MessageBuilder> messageBuilders = {
        "application/xml": new XMLToJSONBuilder()
        // "application/json": new JSONToXMLBuilder()
        // others

    };
    return messageBuilders[contentType] ?: error("Message builder not found for content type: " + contentType);
}

public class XMLToJSONBuilder {
    *MessageBuilder;

    public isolated function init() {
        io:println("XMLToJSONBuilder initialized");
    }

    public isolated function process(http:Request req) returns http:Request|error {
        xml payload = check req.getXmlPayload();
        json jsonPayload = check xmldata:toJson(payload);
        req.setPayload(jsonPayload);
        check req.setContentType("application/json");
        return req;
    }
}
