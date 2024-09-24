import ballerina/http;
import ballerina/io;

http:InterceptableService httpService = service object {

    public function createInterceptors() returns http:RequestInterceptor[] {
        return [new ValidateInterceptor(), new LoggingInterceptor()];
    }

    isolated resource function 'default .(http:Caller caller, http:Request req) returns error? {
        // TODO: pass the request to the router

        // json|error payload = req.getJsonPayload();
        // if payload is json {
        //     string response = "Received: " + payload.toJsonString();
        //     check caller->respond(response);
        //     io:println("HTTP Request processed successfully with payload: ", response);
        // } else if payload is error {
        //     io:println("Error while processing HTTP request: ", payload.detail());
        //     check caller->respond("Invalid JSON payload");
        // }
    }
};

public function startHttpListener(int port) returns error? {
    io:println("Starting HTTP listener on port: ", port);
    http:Listener httpListener = check new (port);
    check httpListener.attach(httpService, "/");
    check httpListener.'start();
}
