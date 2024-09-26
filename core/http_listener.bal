import ballerina/http;
import ballerina/io;

http:InterceptableService httpService = service object {

    public function createInterceptors() returns http:RequestInterceptor[] {
        io:println("Creating http interceptors...");
        return [new ValidateInterceptor(), new AuditInterceptor()];
    }

    isolated resource function 'default [string... path](http:Caller caller, http:Request req) returns error? {
        http:Response response = check routeHttp(req);
        check caller->respond(response);
    }
};

public function startHttpListener(int port) returns error? {
    io:println("Starting HTTP listener on port: ", port);
    http:Listener httpListener = check new (port);
    check httpListener.attach(httpService, "/");
    check httpListener.'start();
}
