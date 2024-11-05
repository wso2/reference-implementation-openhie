import ballerina/http;

configurable int PORT = ?;
listener http:Listener pdListener = new (PORT);

service / on pdListener {
    isolated resource function get .(http:Caller caller, http:Request req) returns error? {
        // Extract query parameters with default values
        string patientId = req.getQueryParamValue("patientId") ?: "";
        string familyName = req.getQueryParamValue("familyName") ?: "";
        string givenName = req.getQueryParamValue("givenName") ?: "";
        string birthDate = req.getQueryParamValue("birthDate") ?: "";

        // Validate query parameters
        if patientId == "" && familyName == "" && givenName == "" && birthDate == "" {
            return respondWithBadRequest(caller, "No query parameters provided");
        }

        // Build FHIR query and fetch patient details
        string fhirQuery = buildFHIRQuery(patientId, familyName, givenName, birthDate);
        var result = getPatientDetailsFromFHIR(fhirQuery);

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

    isolated resource function put .(http:Caller caller, http:Request req) returns error? {
        // Extract and validate query parameters
        string patientId = req.getQueryParamValue("patientId") ?: "";
        if patientId == "" {
            return respondWithBadRequest(caller, "Patient ID is required");
        }
        string familyName = req.getQueryParamValue("familyName") ?: "";
        string givenName = req.getQueryParamValue("givenName") ?: "";
        string birthDate = req.getQueryParamValue("birthDate") ?: "";

        string fhirQuery = buildFHIRQuery(patientId, familyName, givenName, birthDate);
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
