import ballerina/http;
import ballerina/io;

service / on new http:Listener(9092) {

    resource function post .(http:Caller caller, http:Request req) returns error? {

        // print auth header
        string authHeader = check req.getHeader("Authorization");
        io:println("Authorization header: ", authHeader);

        http:Response res = new;
        res.statusCode = 200;
        res.setPayload({message: "Request processed by target service"});
        check caller->respond(res);
    }
}
