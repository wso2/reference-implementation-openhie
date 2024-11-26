import ballerina/http;
import ballerinax/health.hl7v2;

public type HTTPMessageTransformer distinct object {
    public isolated function transform(http:Request req) returns http:Request|error;
    public isolated function revertTransformation(http:Response res) returns http:Response|error;
};

public type TCPMessageTransformer distinct object {
    public isolated function transform(string data) returns [json, hl7v2:Message]|error;
    public isolated function revertTransformation(json data, TcpRequestContext reqCtx) returns byte[]|error;
};
