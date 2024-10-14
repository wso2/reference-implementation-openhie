import ballerina/http;
// import ballerina/io;
import ballerina/jwt;

const string X_JWT_HEADER = "Authorization";
const string[] JWT_KEYS = ["username", "email", "roles", "id"];

public isolated function getPayload(http:Request req) returns json|xml|string|error {
    json|error jsonPayload = req.getJsonPayload();
    if jsonPayload is json {
        return jsonPayload;
    }

    xml|error xmlPayload = req.getXmlPayload();
    if xmlPayload is xml {
        return xmlPayload;
    }

    string|error textPayload = req.getTextPayload();
    if textPayload is string {
        return textPayload;
    }
    return error("Unsupported payload type");
}

public isolated function extractUserDetails(http:Request httpRequest) returns map<string>|error {
    string|error authHeader = httpRequest.getHeader(X_JWT_HEADER);
    if authHeader is string {
        string jwtToken = authHeader.startsWith("Bearer ") ? authHeader.substring(7) : authHeader;
        [jwt:Header, jwt:Payload]|error headerPayload = jwt:decode(jwtToken);
        if headerPayload is [jwt:Header, jwt:Payload] {
            jwt:Payload payload = headerPayload[1];
            map<string> userDetails = {};
            foreach string key in JWT_KEYS {
                if payload.hasKey(key) {
                    userDetails[key] = <string>payload.get(key);
                }
            }
            return userDetails;
        } else {
            return error("Failed to decode JWT");
        }
    } else {
        return error("JWT token not found in the request header");
    }
}

public function splitString(string str, string delimiter) returns string[] {
    return re `${delimiter}`.split(str);
}
