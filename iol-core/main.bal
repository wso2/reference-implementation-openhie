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

import ballerina/lang.runtime;
import ballerina/log;

configurable Ports ports = ?;
public configurable SystemInfo systemInfo = ?;
public configurable ExternalServices externalServices = ?;
public configurable WebSubHubSettings webSubHubSettings = ?;

function init() returns error? {
    check startHttpListener(ports.HTTP_LISTENER_PORT);
    check startTcpListener(ports.TCP_LISTENER_PORT);
    check initHttpClients();
    check registerWebSubHubTopics();
    log:printInfo("Services started successfully.");
}

public function main() returns error? {
    waitForShutdownSignal();
}

function waitForShutdownSignal() {
    while true {
        runtime:sleep(1000);
    }
}
