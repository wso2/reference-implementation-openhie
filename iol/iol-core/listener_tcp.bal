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

import ballerina/log;
import ballerina/tcp;

tcp:Service tcpService = service object {
    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService {
        log:printInfo("New TCP client connected.");
        return new TcpService();
    }
};

service class TcpService {
    *tcp:ConnectionService;

    remote function onBytes(tcp:Caller caller, readonly & byte[] data) returns tcp:Error|error? {
        string fromBytes = check string:fromBytes(data);
        string sanitized = sanitizeHl7Message(fromBytes);
        byte[] response = handleTcp(sanitized, caller);
        check caller->writeBytes(response);
    }

    remote function onClose() {
        log:printInfo("TCP client connection closed.");
    }

    remote function onError(tcp:Error err) {
        log:printInfo(string `TCP error occurred: ${err.message()}`);
    }
}

public function startTcpListener(int port) returns error? {
    log:printInfo(string `Starting TCP listener on port: ${port} `);
    tcp:Listener tcpListener = check new (port);
    check tcpListener.attach(tcpService, "/");
    check tcpListener.'start();
}
