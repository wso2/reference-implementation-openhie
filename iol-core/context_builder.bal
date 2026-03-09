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
import ballerinax/health.hl7v2;

public isolated function buildRequestContextForHTTP(http:Request originalReq, http:Request transformedReq) returns HTTPRequstContext|error {
    // TODO:extract user details
    map<string> userDetails = check extractUserDetails(originalReq);
    return {
        username: userDetails["username"] ?: "",
        patientId: originalReq.getQueryParamValue("Patient") ?: "",
        contentType: originalReq.getContentType(),
        httpRequest: transformedReq
    };
}

public isolated function buildRequestContextForTCP(string data, hl7v2:Message hl7Message, json transformedData, string in_contentType) returns TcpRequestContext|error {
    // TODO: extract user details
    map<anydata> msh = <map<anydata>>hl7Message["msh"];
    map<anydata> hd3 = <map<anydata>>msh["msh3"];
    map<anydata> hd4 = <map<anydata>>msh["msh4"];
    map<anydata> hd5 = <map<anydata>>msh["msh5"];
    map<anydata> hd6 = <map<anydata>>msh["msh6"];
    
    return {
        contentType: in_contentType,
        username: hd3["hd1"].toString(),
        fhirMessage: transformedData,
        msgId: msh["msh10"].toString(),
        eventCode: extractHl7MessageType(data),
        patientId: extractPatientId(data),
        sendingFacility: hd4["hd1"].toString(),
        receivingFacility: hd6["hd1"].toString(),
        sendingApplication: hd3["hd1"].toString(),
        receivingApplication: hd5["hd1"].toString()
    };
}