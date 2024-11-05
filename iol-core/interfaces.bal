import ballerina/http;

public type HTTPMessageTransformer distinct object {
    public isolated function transform(http:Request req) returns http:Request|error;
    public isolated function revertTransformation(http:Response res) returns http:Response|error;
};

public type TCPMessageTransformer distinct object {
    public isolated function transform(string data) returns json|error;
    public isolated function revertTransformation(json data, TcpRequestContext reqCtx) returns string|error;
};
