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
import ballerina/websubhub;

type OpenSearchConfig record {|
    string url;
    string username;
    string password;
|};

configurable OpenSearchConfig openSearchConfig = ?;
// index topic map
const map<string> indexTopicMap = {
    "transaction": "openhie_ref_impl-transactions",
    "audit": "openhie_ref_impl-audit"
};

final http:Client openSearchClient = check new (openSearchConfig.url,
    // Disable SSL verification for testing purposes (not recommended for production)
    secureSocket = {
        enable: false
    },
    auth = {
        username: openSearchConfig.username,
        password: openSearchConfig.password
    }
);

isolated function sendEvent(websubhub:UpdateMessage message) returns error? {
    string subtopic = message.hubTopic.substring(OPENSEARCH_TOPIC_PREFIX.length() + 1);

    http:Request req = new;
    req.setPayload(message.content.toJson(), contentType = "application/json");
    http:Response|http:ClientError response = openSearchClient->post(string `/${indexTopicMap.get(subtopic)}/_doc`, req);
    if response is http:ClientError {
        log:printError("failed to send ", message = response.message());
        return response;
    }
    if response.statusCode != http:STATUS_CREATED {
        log:printError(string `Failed to send event ${subtopic}`);
    }
    log:printInfo("Log sent to Fluent Bit", message = check response.getTextPayload());
}
