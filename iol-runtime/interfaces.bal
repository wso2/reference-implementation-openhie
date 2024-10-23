import ballerina/http;

public type HTTPMessageBuilder distinct object {
    public isolated function process(http:Request req) returns http:Request|error;
};

public type TCPMessageBuilder distinct object {
    public isolated function process(string data) returns TcpRequestContext|error;
};

public type HTTPMessageFormatter distinct object {
    public isolated function format(http:Response res) returns http:Response|error;
};

public type TCPMessageFormatter distinct object {
    public isolated function format(TcpResponseContext|error resCtx, TcpRequestContext reqCtx) returns byte[]|error;
};
