import ballerina/http;

configurable int PORT = ?;
listener http:Listener pdListener = new (PORT);

service / on pdListener {
    isolated resource function get [string... path](http:Caller caller, http:Request req) returns error? {
        // path is like Patient/{patientId}
        if path.length() == 0 {
            return respondWithBadRequest(caller, "No patient id provided");
        }
        // Build FHIR query and fetch patient details
        string fhirQuery = req.rawPath;
        http:Response|error result = getPatientDetailsFromFHIR(fhirQuery);

        if result is error {
            return respondWithInternalError(caller, "FHIR server query failed");
        }
        check caller->respond(result);
    }

    isolated resource function post .(http:Caller caller, http:Request req) returns error? {
        var payload = req.getJsonPayload();
        if payload is error {
            return respondWithBadRequest(caller, "Invalid JSON payload");
        }

        var result = createPatientInFHIR(payload);
        if result is error {
            return respondWithInternalError(caller, "Failed to create patient in FHIR");
        }

        check caller->respond(result);
    }

    isolated resource function put [string... path](http:Caller caller, http:Request req) returns error? {
        // path is like Patient/{patientId}
        if path.length() == 0 {
            return respondWithBadRequest(caller, "No patient id provided");
        }
        // Build FHIR query and fetch patient details
        string fhirQuery = req.rawPath;
        var payload = req.getJsonPayload();
        if payload is error {
            return respondWithBadRequest(caller, "Invalid JSON payload");
        }

        var result = updatePatientInFHIR(fhirQuery, payload);
        if result is error {
            return respondWithInternalError(caller, "Failed to update patient in FHIR");
        }
        check caller->respond(result);
    }
}

// Helper function to respond with a 400 Bad Request
isolated function respondWithBadRequest(http:Caller caller, string message) returns error? {
    http:Response response = new;
    response.statusCode = 400;
    response.reasonPhrase = "Bad Request";
    response.setPayload(message);
    return caller->respond(response);
}

// Helper function to respond with a 500 Internal Server Error
isolated function respondWithInternalError(http:Caller caller, string message) returns error? {
    http:Response response = new;
    response.statusCode = 500;
    response.reasonPhrase = "Internal Server Error";
    response.setPayload(message);
    return caller->respond(response);
}
