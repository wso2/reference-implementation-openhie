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
    http:Response response = check _client->forward("/", req);
    return response;
}

isolated function findRouteForHttpReq(string path, string method) returns HttpRoute? {
    foreach var route in httpRoutes {
        if route.path == path && route.methods.indexOf(method) != () {
            return route;
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

// TODO:
// - implement the tcp router
