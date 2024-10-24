import ballerina/http;
import ballerina/io;

configurable int PORT = ?;
listener http:Listener pdListener = new (PORT);

service / on pdListener {
    isolated resource function get .(http:Caller caller, http:Request req) returns error? {

        io:println("Recieved GET: ", req.rawPath);

        string patientId = req.getQueryParamValue("patientId") ?: "";
        string familyName = req.getQueryParamValue("familyName") ?: "";
        string givenName = req.getQueryParamValue("givenName") ?: "";
        string birthDate = req.getQueryParamValue("birthDate") ?: "";

        // Check if any query parameters are missing
        if patientId == "" && familyName == "" && givenName == "" && birthDate == "" {
            http:Response response = new;
            response.statusCode = 400;
            response.reasonPhrase = "Bad Request";
            response.setPayload("No query parameters provided");
            // Send response and return early to avoid further processing
            check caller->respond(response);
            return;
        }

        // Build FHIR query and get patient details
        string fhirQuery = buildFHIRQuery(patientId, familyName, givenName, birthDate);
        var result = getPatientDetailsFromFHIR(fhirQuery);

        // Handle errors from the FHIR query
        if result is error {
            http:Response response = new;
            response.statusCode = 500;
            response.reasonPhrase = "Internal Server Error";
            response.setPayload("FHIR server query failed");
            // Send response and return early to avoid further processing
            check caller->respond(response);
            return;
        }

        // If everything is successful, return the result to the client
        io:println("Result: ", result.getTextPayload());
        check caller->respond(result); // Only one respond call here
    }

    isolated resource function post .(http:Caller caller, http:Request req) returns error? {
        var result = check createPatientInFHIR(check req.getJsonPayload());
        check caller->respond(result);
        return;
    }

    isolated resource function put .(http:Caller caller, http:Request req) returns error? {

        io:println("Recieved PUT: ", req.getJsonPayload());

        string patientId = req.getQueryParamValue("patientId") ?: "";
        string familyName = req.getQueryParamValue("familyName") ?: "";
        string givenName = req.getQueryParamValue("givenName") ?: "";
        string birthDate = req.getQueryParamValue("birthDate") ?: "";

        if patientId == "" {
            http:Response response = new;
            response.statusCode = 400;
            response.reasonPhrase = "Bad Request";
            response.setPayload("No query parameters provided");
            io:println("Adooo noo");

            check caller->respond(response);
            return;
        }
        string fhirQuery = buildFHIRQuery(patientId, familyName, givenName, birthDate);
        var result = check updatePatientInFHIR(fhirQuery, check req.getJsonPayload());

        io:println("Result: ", result.statusCode);
        io:println("Result: ", result.getTextPayload());

        check caller->respond(result);
        return;
    }

}
