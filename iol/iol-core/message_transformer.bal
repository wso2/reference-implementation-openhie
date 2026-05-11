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
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.parser;
import ballerinax/health.hl7v2;
import ballerinax/health.hl7v2.utils.v2tofhirr4;

public isolated function getHTTPMessageTransformer(string contentType) returns HTTPMessageTransformer|error {
    map<HTTPMessageTransformer> messageTransformers = {
        "application/json": new JsonMessageTransformer()
        // others

    };
    return messageTransformers[contentType] ?: error("Message builder not found for content type: " + contentType);
}

public isolated function getTCPMessageTransformer(string contentType) returns TCPMessageTransformer|error {
    map<TCPMessageTransformer> messageTransformers = {
        "hl7": new HL7MessageTransformer()
        // others

    };
    return messageTransformers[contentType] ?: error("Message builder not found for content type: " + contentType);
}

public class JsonMessageTransformer {
    *HTTPMessageTransformer;

    public isolated function init() {
        log:printInfo("Created an instance of JsonToFhirBuilder");
    }

    public isolated function transform(http:Request req) returns http:Request|error {
        check req.setContentType("application/json+fhir");
        return req;
    }

    public isolated function revertTransformation(http:Response res) returns http:Response|error {
        check res.setContentType("application/json");
        return res;
    }

}

public class HL7MessageTransformer {
    *TCPMessageTransformer;

    public isolated function init() {
        log:printInfo("Created an instance of JsonToFhirBuilder");
    }

    public isolated function transform(string data) returns [json, hl7v2:Message]|error {
        hl7v2:Message hl7Message = check parseHl7Message(data);
        json v2tofhirResult = check v2tofhirr4:v2ToFhir(hl7Message);
        return [v2tofhirResult, hl7Message];
    }

    public isolated function revertTransformation(json data, TcpRequestContext reqCtx) returns byte[]|error {
        international401:Patient fhirPatient = check parser:parse(data).ensureType();
        byte[] hl7msg = check mapFhirPatientToHL7(fhirPatient, reqCtx.receivingApplication, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.sendingFacility, reqCtx.msgId);
        return hl7msg;
    }
}

