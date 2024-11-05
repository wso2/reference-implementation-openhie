import ballerina/http;
import ballerina/log;

http:Service httpService = service object {
    isolated resource function 'default [string... path](http:Caller caller, http:Request req, http:RequestContext ctx) returns error? {
        http:Response response = handleHTTP(req, caller);
        check caller->respond(response);
    }
};

public function startHttpListener(int port) returns error? {
    log:printInfo(string `Starting HTTP listener on port: ${port}`);
    http:Listener httpListener = check new (port);
    check httpListener.attach(httpService, "/");
    check httpListener.'start();
}
