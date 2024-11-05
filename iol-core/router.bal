import ballerina/http;
import ballerina/lang.regexp;
import ballerina/log;

configurable HttpRoute[] httpRoutes = ?;
configurable TcpRoute[] tcpRoutes = ?;

// Map to store HTTP clients for each target service
isolated map<http:Client> httpClients = {};

// Initialize HTTP clients
public function initHttpClients() returns error? {
    // create HttpClients for incoming http messages
    foreach var route in httpRoutes {
        lock {
            if httpClients[route.target] is http:Client {
                continue;
            }
            http:Client _client = check createHttpClient(route);
            httpClients[route.target] = _client;
        }
    }

    // create HttpClients for incoming tcp messages
    foreach var route in tcpRoutes {
        lock {
            if httpClients[route.target] is http:Client {
                continue;
            }
            http:Client _client = check createHttpClient(route);
            httpClients[route.target] = _client;
        }
    }
    log:printInfo("HTTP clients initialized successfully.");
}

isolated function createHttpClient(HttpRoute|TcpRoute route) returns http:Client|error {
    http:ClientConfiguration clientConfig = {
        auth: route.auth
    };
    return new http:Client(route.target, clientConfig);
}

isolated function getHTTPClient(HttpRoute|TcpRoute route) returns http:Client|error {
    lock {
        http:Client? _client = httpClients[route.target];
        if _client is () {
            return error("No HTTP client found for the target service: " + route.target);
        }
        return _client;
    }
}

// HTTP Routing
public isolated function routeHttp(HTTPRequstContext reqCtx) returns ResponseContext|error {
    do {
        HttpRoute targetRoute = check findRouteForHttpRequest(reqCtx.httpRequest.rawPath, reqCtx.httpRequest.method);
        http:Client _client = check getHTTPClient(targetRoute);
        http:Request _req = check createHTTPRequestforHTTP(reqCtx.httpRequest, targetRoute);
        check audit_request(targetRoute.workflow, reqCtx.username, reqCtx.patientId, systemInfo.SYSNAME);
        http:Response|error response = _client->forward(_req.rawPath, _req);

        if response is error {
            return error(string `Failed to forward the request to the Upstream Service: ${response.message()}`);
        }
        ResponseContext responseContext = {response: response, route: targetRoute};
        return responseContext;
    } on fail error e {
        return error("Something went wrong while processing: " + e.message());
    }
}

// TCP Routing
public isolated function routeTCP(TcpRequestContext reqCtx) returns ResponseContext|error {
    do {
        TcpRoute targetRoute = check findRouteForTcpRequest(reqCtx);
        http:Client _client = check getHTTPClient(targetRoute);
        http:Request _req = check createHTTPRequestforTCP(targetRoute, reqCtx);
        check audit_request(targetRoute.workflow, "test-username", reqCtx.patientId, systemInfo.SYSNAME);

        http:Response|error response;
        match targetRoute.method {
            http:GET => {
                response = _client->get(_req.rawPath);
            }
            _ => {
                response = _client->forward(_req.rawPath, _req);
            }
        }
        if response is error {
            return error("Failed to forward the request to the Upstream Service: " + response.message());
        }
        ResponseContext responseContext = {response: response, route: targetRoute};
        return responseContext;
    } on fail error e {
        return error("Something went wrong while processing: " + e.message());
    }
}

// Helper Functions 

isolated function findRouteForHttpRequest(string rawPath, string method) returns HttpRoute|error {
    log:printInfo("Checking route for incoming HTTP request...");
    foreach var route in httpRoutes {
        if route.methods.indexOf(method) != () {
            regexp:RegExp pathRegex = check regexp:fromString(route.path);
            boolean foundPath = rawPath.matches(pathRegex);
            if foundPath {
                log:printInfo("Match found");
                return route;
            }
        }
    }
    return error("No route found for the given message type");
}

isolated function findRouteForTcpRequest(TcpRequestContext reqCtx) returns TcpRoute|error {
    log:printInfo("Checking route for incoming TCP request...");
    foreach var route in tcpRoutes {
        if route.HL7Code == reqCtx.eventCode {
            log:printInfo("Match found");
            return route;
        }
    }
    return error("No route found for the given message type");
}

isolated function createHTTPRequestforTCP(TcpRoute route, TcpRequestContext reqCtx) returns http:Request|error {
    http:Request req = new;
    req.rawPath = check setRequestParams(route.method, reqCtx);
    if route.method == "GET" {
        return req;
    }
    req.method = route.method;
    json payload = check extractPatientResource(reqCtx.fhirMessage);
    req.setPayload(payload, "application/json");
    return req;
}

isolated function createHTTPRequestforHTTP(http:Request req, HttpRoute route) returns http:Request|error {
    http:Request customReq = req;
    customReq.rawPath = "/"; //TODO: change this to the actual path
    check customReq.setContentType(route.contentType ?: "application/json");
    return customReq;
}

isolated function setRequestParams(string method, TcpRequestContext reqCtx) returns string|error {
    // TODO: add more parameters
    if reqCtx.patientId != "" {
        string path = "/?";
        path = path + "patientId=" + reqCtx.patientId;
        return path;
    }
    return "";
}

