import ballerina/http;

public type MessageBuilder distinct object {
    public isolated function process(http:Request req) returns http:Request|error;
};

public type MessageFormatter distinct object {
    public isolated function format(http:Response res) returns http:Response|error;
};
