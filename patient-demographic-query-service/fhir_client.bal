import ballerina/http;
import ballerina/log;

configurable string FHIR_SERVER = ?;

final http:Client fhirClient = check new (FHIR_SERVER, {
    cache: {enabled: true},
    timeout: 60
});

public isolated function getPatientDetailsFromFHIR(string fhirQuery) returns http:Response|error {
    log:printInfo("Calling FHIR server with query: " + fhirQuery);
    http:Response|error response = fhirClient->get(fhirQuery);
    if response is error {
        log:printError("Error calling FHIR server", response);
    }
    return response;
}
