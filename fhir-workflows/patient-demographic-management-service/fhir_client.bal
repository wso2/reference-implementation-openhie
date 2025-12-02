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

public isolated function createPatientInFHIR(json payload) returns http:Response|error {
    log:printInfo("Creating patient in FHIR server with payload: " + payload.toString());
    http:Response|error response = fhirClient->post("/Patient", payload);
    if response is error {
        log:printError("Error creating patient in FHIR server", response);
    }
    return response;
}

public isolated function updatePatientInFHIR(string fhirQuery, json payload) returns http:Response|error {
    log:printInfo("Updating patient in FHIR server with payload: " + payload.toString());
    http:Response|error response = fhirClient->put(fhirQuery, payload);
    if response is error {
        log:printError("Error updating patient in FHIR server", response);
    }
    return response;
}
