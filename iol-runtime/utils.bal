import ballerina/http;
import ballerina/jwt;
import ballerina/time;
// import ballerinax/health.fhir.r4.international401;
// import ballerinax/health.fhir.r4.parser;
import ballerinax/health.hl7v2;

// import ballerinax/health.hl7v23;

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

public isolated function isHL7Message(string message) returns boolean {
    return extractHL7Version(message) is string;
}

// TODO: use the hl7v2:extractHL7Version() function once it is support public access  
isolated function extractHL7Version(string message) returns string? {
    return extractHL7Field(message, 11);
}

isolated function extractHL7MessageType(string message) returns string {
    return extractHL7Field(message, 8) ?: "";
}

isolated function extractPatientId(string message) returns string {
    string? pidField = extractHL7Field(message, 3, 2) ?: "";
    if pidField is string {
        string[] fields = re `\^\^\^`.split(pidField);
        return fields.length() > 0 ? fields[0] : "";
    }
    return "";
}

isolated function extractHL7MessageId(string message) returns string {
    return extractHL7Field(message, 9) ?: "";
}

isolated function extractSendingFacility(string message) returns string {
    return extractHL7Field(message, 3) ?: "";
}

isolated function extractReceivingFacility(string message) returns string {
    return extractHL7Field(message, 5) ?: "";
}

isolated function extractSendingApplication(string message) returns string {
    return extractHL7Field(message, 2) ?: "";
}

isolated function extractRecievingApplication(string message) returns string {
    return extractHL7Field(message, 4) ?: "";
}

isolated function extractHL7Field(string message, int fieldIndex, int segmentIndex = 0) returns string? {
    string[] splitMsg = re `\r`.split(message);
    if splitMsg.length() > segmentIndex {
        string[] splitFields = re `\|`.split(splitMsg[segmentIndex].trim());
        if splitFields.length() > fieldIndex {
            return splitFields[fieldIndex];
        }
    }
    return ();
}

// public isolated getHL7MessageType(hl7v2:Message hl7Msg) returns string {
//     // Extract the MSH segment from the HL7 message
//     hl7v2:Segment mshSegment = check hl7Msg.getSegment("MSH");

//     // Extract the message type from the MSH-9 field
//     string messageType = check mshSegment.getField(9).toString();

//     // Log the extracted message type
//     log:printInfo(string `Extracted HL7 message type: ${messageType}`);

// }

public isolated function parseHl7Message(string data) returns hl7v2:Message|error {
    return check hl7v2:parse(data);
}

public function splitString(string str, string delimiter) returns string[] {
    return re `${delimiter}`.split(str);
}

isolated function createHL7AckMessage(string sendingFacility, string receivingFacility, string sendingApp, string receivingApp, string messageType, string statusCode, string messageID, string details) returns string {
    string hl7Version = "2.4";
    string timestamp = time:utcToString(time:utcNow()); // TODO: correct the format : yyyyMMddHHmmss

    // Construct MSH (Message Header) segment
    string mshSegment = string `MSH|^~\\&|${sendingApp}|${sendingFacility}|${receivingApp}|${receivingFacility}|${timestamp}||ACK^${messageType}|${messageID}|P|${hl7Version}|`;

    // Construct MSA (Message Acknowledgment) segment
    string msaSegment = string `MSA|${statusCode}|${messageID}|${details}`;

    // Combine the MSH and MSA segments to create the full HL7 ACK message
    string ackMessage = string `${mshSegment}\n${msaSegment}`;
    return ackMessage;
}
