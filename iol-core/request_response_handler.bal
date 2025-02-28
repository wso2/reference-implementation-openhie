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
import ballerina/tcp;
import ballerina/time;
import ballerinax/health.hl7v2;

public isolated function handleHttp(http:Request req, http:Caller caller) returns http:Response {
    RequestLog requestLog = {
        host: caller.remoteAddress.host,
        port: caller.remoteAddress.port,
        messageType: "HTTP",
        payload: getPayload(req).toString(),
        path: req.rawPath,
        requestHeaders: extractRequestHeaders(req),
        method: req.method,
        timestamp: time:utcToString(time:utcNow())
    };
    TransactionLog transactionLog = {
        clientId: "",
        status: UNKNOWN,
        requestLog: requestLog
    };

    do {
        string in_contentType = req.getContentType();
        HTTPMessageTransformer messageTransformer = check getHTTPMessageTransformer(in_contentType);
        http:Request transformedRequest = check messageTransformer.transform(req);

        HTTPRequstContext reqCtx = check buildRequestContextForHTTP(req, transformedRequest);
        transactionLog.clientId = reqCtx.username;

        ResponseContext resCtx = check routeHttp(reqCtx);
        http:Response transformedResponse = check messageTransformer.revertTransformation(resCtx.response);

        ResponseLog responseLog = {
            status: transformedResponse.statusCode.toString(),
            payload: check transformedResponse.getTextPayload(),
            responseHeaders: extractResponseHeaders(transformedResponse),
            timestamp: time:utcToString(time:utcNow())
        };
        transactionLog.status = SUCCESS;
        transactionLog.responseLog = responseLog;
        logTransaction(transactionLog);
        return transformedResponse;

    } on fail error e {
        return handleError(e, transactionLog, e.message());
    }
}

isolated function handleTcpError(error e, TransactionLog transactionLog, string errorMessage) returns string {
    transactionLog.status = FAILURE;
    transactionLog.errorMessage = e.message();
    logTransaction(transactionLog);
    return errorMessage;
}

public isolated function handleTcp(string data, tcp:Caller caller) returns byte[] {
    RequestLog requestLog = {
        host: caller.remoteHost,
        port: caller.remotePort,
        messageType: "TCP",
        payload: data,
        timestamp: time:utcToString(time:utcNow(3))
    };

    TransactionLog transactionLog = {
        clientId: "",
        status: UNKNOWN,
        requestLog: requestLog
    };

    do {
        // check requestValidatorHL7(data);

        string in_contentType = "hl7";
        TCPMessageTransformer messageTransformer = check getTCPMessageTransformer(in_contentType);
        [json, hl7v2:Message] transformedData = check messageTransformer.transform(data);

        TcpRequestContext reqCtx = check buildRequestContextForTCP(data, transformedData[1], transformedData[0], in_contentType);
        transactionLog.clientId = reqCtx.username;

        ResponseContext|error resCtx = routeTCP(reqCtx);

        if resCtx is error {
            transactionLog.status = FAILURE;
            transactionLog.errorMessage = resCtx.message();
            logTransaction(transactionLog);
            return check generateHl7Acknowledgment(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, string `Failed to process message ${resCtx.message()}`);
        }
        http:Response res = resCtx.response;
        workflow workflow = resCtx.route.workflow;

        match res.statusCode {
            http:STATUS_CREATED => {
                byte[] ackMessage = check generateHl7Acknowledgment(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AA", reqCtx.msgId, "Resource created successfully!");
                string ackMessageStr = check string:fromBytes(ackMessage);
                ResponseLog responseLog = {
                    status: "AA",
                    payload: ackMessageStr.trim(),
                    timestamp: time:utcToString(time:utcNow(3))
                };

                transactionLog.status = SUCCESS;
                transactionLog.responseLog = responseLog;
                logTransaction(transactionLog);

                return ackMessage;
            }
            http:STATUS_OK => {
                if (workflow == PATIENT_DEMOGRAPHICS_QUERY) {
                    byte[] payload = check messageTransformer.revertTransformation(check resCtx.response.getJsonPayload(), reqCtx);
                    string payloadStr = check string:fromBytes(payload);
                    ResponseLog responseLog = {
                        status: "AA",
                        payload: payloadStr.trim(),
                        timestamp: time:utcToString(time:utcNow(3))
                    };

                    transactionLog.status = SUCCESS;
                    transactionLog.responseLog = responseLog;
                    logTransaction(transactionLog);

                    return payload;
                }

                byte[] ackMessage = check generateHl7Acknowledgment(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AA", reqCtx.msgId, "Resource updated successfully!");
                string ackMessageStr = check string:fromBytes(ackMessage);
                ResponseLog responseLog = {
                    status: "AA",
                    payload: ackMessageStr.trim(),
                    timestamp: time:utcToString(time:utcNow(3))
                };

                transactionLog.status = SUCCESS;
                transactionLog.responseLog = responseLog;
                logTransaction(transactionLog);

                return ackMessage;
            }
            http:STATUS_BAD_REQUEST => {
                transactionLog.status = FAILURE;
                transactionLog.errorMessage = "Bad Request";
                logTransaction(transactionLog);

                return check generateHl7Acknowledgment(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, "Bad Request");
            }

            http:STATUS_NOT_FOUND => {
                transactionLog.status = FAILURE;
                transactionLog.errorMessage = "Resource not found";
                logTransaction(transactionLog);

                return check generateHl7Acknowledgment(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, "Resource not found");
            }

            http:STATUS_INTERNAL_SERVER_ERROR => {
                transactionLog.status = FAILURE;
                transactionLog.errorMessage = "Internal Server Error";
                logTransaction(transactionLog);

                return check generateHl7Acknowledgment(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, "Internal Server Error");
            }

            _ => {
                transactionLog.status = FAILURE;
                transactionLog.errorMessage = "Failed to process message";
                logTransaction(transactionLog);

                return check generateHl7Acknowledgment(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, "Failed to process message");
            }
        }
    } on fail error e {
        return handleTcpError(e, transactionLog, "Failed to process the message: " + e.message()).toBytes();
    }
}
