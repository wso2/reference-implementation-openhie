import ballerina/http;

public isolated function attributeValidator(http:Request|http:Response msg) returns http:Request|http:Response|error {
    // Validate the request/response attributes
    return msg;
}

public isolated function requestValidatorHL7(string data) returns error? {
    // Validate the HL7 message
    return isHL7Message(data) ? () : error("Invalid HL7 message Type");
}
