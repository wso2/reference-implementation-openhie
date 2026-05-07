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

public type HTTPMessageTransformer distinct object {
    public isolated function transform(http:Request req) returns http:Request|error;
    public isolated function revertTransformation(http:Response res) returns http:Response|error;
};

public type TCPMessageTransformer distinct object {
    public isolated function transform(string data) returns [json, hl7v2:Message]|error;
    public isolated function revertTransformation(json data, TcpRequestContext reqCtx) returns byte[]|error;
};
