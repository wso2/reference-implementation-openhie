import ballerina/http;

configurable int PORT = ?;
listener http:Listener pdListener = new (PORT);

service / on pdListener {
    isolated resource function get .(http:Caller caller, http:Request req) returns error? {
        string patientId = req.getQueryParamValue("patientId") ?: "";
        string familyName = req.getQueryParamValue("familyName") ?: "";
        string givenName = req.getQueryParamValue("givenName") ?: "";
        string birthDate = req.getQueryParamValue("birthDate") ?: "";

        if patientId == "" && familyName == "" && givenName == "" && birthDate == "" {
            http:Response response = new;
            response.statusCode = 400;
            response.reasonPhrase = "Bad Request";
            response.setPayload("No query parameters provided");
            check caller->respond(response);
            return;
        }
        string fhirQuery = buildFHIRQuery(patientId, familyName, givenName, birthDate);
        var result = getPatientDetailsFromFHIR(fhirQuery);
        if result is error {
            http:Response response = new;
            response.statusCode = 500;
            response.reasonPhrase = "Internal Server Error";
            response.setPayload("FHIR server query failed");
            check caller->respond(response);
            return;
        }
        check caller->respond(result);
    }

    isolated resource function post .(http:Caller caller, http:Request req) returns error? {
        var result = check createPatientInFHIR(check req.getJsonPayload());
        check caller->respond(result);
        return;
    }

    isolated resource function put .(http:Caller caller, http:Request req) returns error? {
        string patientId = req.getQueryParamValue("patientId") ?: "";
        string familyName = req.getQueryParamValue("familyName") ?: "";
        string givenName = req.getQueryParamValue("givenName") ?: "";
        string birthDate = req.getQueryParamValue("birthDate") ?: "";

        if patientId == "" && familyName == "" && givenName == "" && birthDate == "" {
            http:Response response = new;
            response.statusCode = 400;
            response.reasonPhrase = "Bad Request";
            response.setPayload("No query parameters provided");
            check caller->respond(response);
            return;
        }
        string fhirQuery = buildFHIRQuery(patientId, familyName, givenName, birthDate);
        var result = check updatePatientInFHIR(fhirQuery, check req.getJsonPayload());
        check caller->respond(result);
        return;
    }

}
