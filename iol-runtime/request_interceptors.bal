import ballerina/http;

public isolated service class AttributesValidatorInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default [string... path](http:RequestContext ctx, http:Request req, http:Response res) returns http:NextService|http:Response|error? {
        // TODO:
        return ctx.next();
    }
}

public isolated service class MessageBuilderInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default [string... path](http:RequestContext ctx, http:Request req) returns http:NextService|http:Response|error? {

        ctx.set("in-content-type", req.getContentType());
        MessageBuilder messageBuilder = check getMessageBuilder(req.getContentType());
        http:Request Newreq = check messageBuilder.process(req);

        byte[] payload = check Newreq.getBinaryPayload();
        req.setPayload(payload, Newreq.getContentType());

        // var userDetails = check extractUserDetails(req);
        // io:println("User Details: ", userDetails);

        // // TODO: Extract userDetails from the request
        // string patientID = path.length() > 1 ? path[1] : "";
        // UserDetails userDetails = {username: "test_username", userRole: "test_userRole"};

        // ctx.set("username", userDetails.username);
        // ctx.set("userRole", userDetails.userRole);
        // ctx.set("patientID", <string>patientID);
        return ctx.next();
    }
}
