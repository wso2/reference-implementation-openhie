import ballerina/http;

public isolated service class ValidateInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default .(http:RequestContext ctx, http:Request req) returns http:NextService|error? {
        // TODO: Implement request validation logic
        return ctx.next();
    }
}

public isolated service class LoggingInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default .(http:RequestContext ctx, http:Request req) returns http:NextService|error? {
        // TODO: Implement request logging logic
        return ctx.next();
    }
}
