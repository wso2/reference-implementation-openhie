import ballerina/http;

configurable HttpRoute[] httpRoutes = ?;

public isolated function routeHttp(http:Request req) returns http:Response|error {

    HttpRoute? targetRoute = findRouteForHttpReq(req.rawPath, req.method);
    if targetRoute is () {
        http:Response badRequest = new;
        badRequest.statusCode = 400;
        badRequest.setPayload({message: "Path not found: " + req.rawPath + " " + req.method});
        return badRequest;
    }

    http:Client _client = check createHttpClient(targetRoute);
    http:Request customReq = check createCustomRequest(req, targetRoute);

    // TODO: extract user details from the request
    check audit_request(targetRoute.workflow, "admin", "patientID", "IOL-ref-impl v0.1");

    http:Response|error response = _client->forward(customReq.rawPath, customReq);

    if response is error {
        http:Response errorResponse = new;
        errorResponse.statusCode = 502;
        errorResponse.setPayload({message: string `Failed to forward the request to the Upstream Service: ${response.message()}`});
        return errorResponse;
    }
    return response;
}

isolated function findRouteForHttpReq(string path, string method) returns HttpRoute? {
    foreach var route in httpRoutes {

        // TODO: Find a better way to handle dynamic paths 
        if route.path == path || (route.path.endsWith("/*") && path.startsWith(route.path.substring(0, route.path.length() - 1))) {
            if route.methods.indexOf(method) != () {
                return route;
            }
        }
    }
    return ();
}

isolated function createHttpClient(HttpRoute route) returns http:Client|error {
    http:ClientConfiguration clientConfig = {
        auth: route.auth
    };
    return new http:Client(route.target, clientConfig);
}

isolated function createCustomRequest(http:Request req, HttpRoute route) returns http:Request|error {
    http:Request customReq = req;
    customReq.rawPath = string `/${(route.path.endsWith("/*") ? req.rawPath.substring(route.path.length() - 1) : "")}`;
    check customReq.setContentType(route.contentType ?: "application/json");
    return customReq;
}

// TODO:
// - implement the tcp router
