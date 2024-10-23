import ballerina/log;

public isolated function buildFHIRQuery(string patientId, string familyName, string givenName, string birthDate) returns string {
    string fhirQuery = "/Patient?";

    if patientId != "" {
        fhirQuery += "_id=" + patientId + "&";
    }
    if familyName != "" {
        fhirQuery += "family=" + familyName + "&";
    }
    if givenName != "" {
        fhirQuery += "given=" + givenName + "&";
    }
    if birthDate != "" {
        fhirQuery += "birthdate=" + birthDate + "&";
    }

    if fhirQuery.endsWith("&") {
        fhirQuery = fhirQuery.substring(0, fhirQuery.length() - 1);
    }

    log:printInfo("Constructed FHIR query: " + fhirQuery);
    return fhirQuery;
}
