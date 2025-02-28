// Copyright (c) 2025 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

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
