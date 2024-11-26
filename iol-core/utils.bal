import ballerina/http;
import ballerina/jwt;
import ballerina/time;
import ballerinax/health.hl7v2;
import ballerinax/health.hl7v23;

const X_JWT_HEADER = "x-jwt-assertion";
const IDP_CLAIMS = "idp_claims";

isolated function sanitizeHl7Message(string message) returns string {
    // Trim leading and trailing whitespace or newline characters
    string sanitizedMessage = message.trim();

    // Remove or replace any non-HL7 standard characters, such as "∟"
    // You can use a regular expression to remove unwanted characters
    // string:RegExp invalidCharsPattern = re `\\\\`;
    // string result = invalidCharsPattern.replaceAll(sanitizedMessage, "\\");

    return sanitizedMessage;
}

public isolated function getPayload(http:Request req) returns json|xml|string? {
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
    return ();
}

public isolated function extractUserDetails(http:Request httpRequest) returns map<string>|error {
    string|error authHeader = httpRequest.getHeader(X_JWT_HEADER);
    if authHeader is string {
        [jwt:Header, jwt:Payload]|error headerPayload = jwt:decode(authHeader);
        if headerPayload is [jwt:Header, jwt:Payload] {
            jwt:Payload payload = headerPayload[1];
            if payload.hasKey(IDP_CLAIMS) {
                map<string> userDetails = {};
                json idp_claims = <json>payload.get(IDP_CLAIMS);
                json|error userName = idp_claims.username;
                if userName is error {
                    return error("Username is not available");
                }
                userDetails["username"] = userName.toString();
                return userDetails;
            }
            return error("idp claims is not available");
        }
        return error("Invalid JWT token");
    } else {
        return error("JWT token not found in the request header");
    }
}

public isolated function isHl7Message(string message) returns boolean {
    return extractHl7Version(message) is string;
}

// TODO: use the hl7v2:extractHL7Version() function once it is support public access  
isolated function extractHl7Version(string message) returns string? {
    return extractHl7Field(message, 11);
}

isolated function extractHl7MessageType(string message) returns string {
    return extractHl7Field(message, 8) ?: "";
}

isolated function extractPatientId(string message) returns string {
    string? pidField;
    if (extractHl7MessageType(message) == "QBP^Q21") {
        pidField = extractHl7Field(message, 3, 1) ?: "";
    } else {
        pidField = extractHl7Field(message, 3, 2) ?: "";
    }

    if pidField is string {
        string[] fields = re `\^\^\^`.split(pidField);
        return fields.length() > 0 ? fields[0] : "";
    }
    return "";
}

isolated function extractHl7MessageId(string message) returns string {
    return extractHl7Field(message, 9) ?: "";
}

isolated function extractHl7Field(string message, int fieldIndex, int segmentIndex = 0) returns string? {
    string[] splitMsg = re `\r`.split(message);
    if splitMsg.length() > segmentIndex {
        string[] splitFields = re `\|`.split(splitMsg[segmentIndex].trim());
        if splitFields.length() > fieldIndex {
            return splitFields[fieldIndex];
        }
    }
    return ();
}

public isolated function parseHl7Message(string data) returns hl7v2:Message|error {
    return check hl7v2:parse(data);
}

public function splitString(string str, string delimiter) returns string[] {
    return re `${delimiter}`.split(str);
}

isolated function createHl7AckMessage(string sendingFacility, string receivingFacility, string sendingApp, string receivingApp, string messageType, string statusCode, string messageID, string details) returns byte[]|error {
    string hl7Version = "2.3";
    string timestamp = getCurrentTimestamp();

    hl7v23:ACK ack = {
        msh: {
            msh2: "^~\\&",
            msh3: {hd1: sendingApp},
            msh4: {hd1: sendingFacility},
            msh5: {hd1: receivingApp},
            msh6: {hd1: receivingFacility},
            msh7: {ts1: timestamp},
            msh9: {cm_msg1: hl7v23:ACK_MESSAGE_TYPE},
            msh10: messageID,
            msh11: {pt1: "P"},
            msh12: hl7Version
        },
        msa: {
            msa1: statusCode,
            msa2: messageID,
            msa3: details
        }
    };

    byte[] encodedAck = check hl7v2:encode(hl7v23:VERSION, ack);
    return encodedAck;
}

// Utility function to get current timestamp in HL7v2 format (YYYYMMDDHHMMSS)
public isolated function getCurrentTimestamp() returns string {
    time:Utc currentTime = time:utcNow();
    return formatTimestamp(currentTime);
}

isolated function joinStrings(string[]? parts) returns string {
    return string:'join(" ", ...parts ?: []);
}

isolated function formatTimestamp(time:Utc timestamp) returns string {
    // Convert the UTC timestamp to a time:Civil record (this includes both date and time fields)
    time:Civil civil = time:utcToCivil(timestamp);

    // Extract the year, month, day, and time components
    string year = civil.year.toString();
    string month = civil.month < 10 ? "0" + civil.month.toString() : civil.month.toString();
    string day = civil.day < 10 ? "0" + civil.day.toString() : civil.day.toString();

    // Extract the time of day (hours, minutes, seconds)
    string hour = civil.hour < 10 ? "0" + civil.hour.toString() : civil.hour.toString();
    string minute = civil.minute < 10 ? "0" + civil.minute.toString() : civil.minute.toString();
    string second = <int>civil.second < 10 ? "0" : (<int>civil.second).toString();

    // Return the formatted timestamp as "YYYYMMDDHHMMSS"
    return year + month + day + hour + minute + second;
}

public isolated function extractPatientResource(json FhirMessage, string patientId) returns json|error {
    map<json> fhirMessage = check FhirMessage.ensureType();
    json[] entries = check fhirMessage["entry"].ensureType();

    foreach var entry in entries {
        map<json> 'resource = check entry.ensureType();
        map<json> Resource = check 'resource["resource"].ensureType();
        if (Resource["resourceType"] == "Patient") {
            Resource["id"] = patientId;
            return Resource;
        }
    }
    return error("Patient resource not found in the FHIR message");
}

public isolated function extractHeadersFromReq(http:Request req) returns map<string> {
    map<string> headers = {};
    string[] headerNames = req.getHeaderNames();
    foreach string headerName in headerNames {
        string|http:HeaderNotFoundError headerValue = req.getHeader(headerName);
        if headerValue is string {
            headers[headerName] = headerValue;
        }
    }
    return headers;
}

public isolated function extractHeadersFromRes(http:Response res) returns map<string> {
    map<string> headers = {};
    string[] headerNames = res.getHeaderNames();
    foreach string headerName in headerNames {
        string|http:HeaderNotFoundError headerValue = res.getHeader(headerName);
        if headerValue is string {
            headers[headerName] = headerValue;
        }
    }
    return headers;
}
