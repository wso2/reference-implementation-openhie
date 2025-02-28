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
import ballerinax/health.hl7v24;
import ballerinax/health.hl7v23;
import ballerinax/health.hl7v25;

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
    hl7v24:MSH|hl7v23:MSH|hl7v25:MSH msh = <hl7v24:MSH|hl7v23:MSH|hl7v25:MSH>hl7Message["msh"];
    return {
        contentType: in_contentType,
        username: msh.msh3.hd1,
        fhirMessage: transformedData,
        msgId: msh.msh10,
        eventCode: extractHl7MessageType(data),
        patientId: extractPatientId(data),
        sendingFacility: msh.msh4.hd1,
        receivingFacility: msh.msh6.hd1,
        sendingApplication: msh.msh3.hd1,
        receivingApplication: msh.msh5.hd1
    };
}
