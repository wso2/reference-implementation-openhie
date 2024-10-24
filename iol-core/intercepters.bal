import ballerina/http;

public isolated service class MessageBuilderInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Response|error? {
        ctx.set("in-content-type", req.getContentType());
        HTTPMessageBuilder messageBuilder = check getHTTPMessageBuilder(req.getContentType());
        http:Request Newreq = check messageBuilder.process(req);
        byte[] payload = check Newreq.getBinaryPayload();
        req.setPayload(payload, Newreq.getContentType());

        // var userDetails = check extractUserDetails(req);
        // io:println("User Details: ", userDetails);

        // // TODO: Extract userDetails from the request
        // string patientID = path.length() > 1 ? path[1] : "";
        UserDetails userDetails = {username: "test_username", userRole: "test_userRole"};

        ctx.set("username", userDetails.username);
        ctx.set("userRole", userDetails.userRole);
        ctx.set("patientID", "0000");
        return ctx.next();
    }
}

public isolated service class MessageFormatterIntercepter {
    *http:ResponseInterceptor;

    isolated remote function interceptResponse(http:RequestContext ctx, http:Response res) returns http:NextService|error? {
        string in_content_type = ctx.get("in-content-type").toString();
        HTTPMessageFormatter messageFormatter = check getHTTPMessageFormatter(in_content_type);
        http:Response newRes = check messageFormatter.format(res);
        byte[] payload = check newRes.getBinaryPayload();
        res.setPayload(payload, newRes.getContentType());
        return ctx.next();
    }
}

public isolated service class RequestValidatorInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Response|error? {
        // validate req
        return ctx.next();
    }
}

public isolated service class ResponseValidatorInterceptor {
    *http:ResponseInterceptor;

    isolated remote function interceptResponse(http:RequestContext ctx, http:Response res) returns http:NextService|error? {
        // validate res
        return ctx.next();
    }
}

public isolated service class SanctionCheckEnforcerInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Response|error? {
        // check req
        return ctx.next();
    }
}
