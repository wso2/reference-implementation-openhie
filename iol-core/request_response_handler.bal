import ballerina/http;
// import ballerina/io;
import ballerina/log;
import ballerina/tcp;
import ballerina/time;

isolated function logTransaction(TransactionLog transactionLog) {
    log:printInfo(string `Transaction Log: ${transactionLog.toString()}`);
    do {
        check publish("opensearch transaction", <json>transactionLog);
    } on fail error e {
        log:printError("Failed to send the transaction event.", 'error = e);
    }
}

isolated function handleError(error e, TransactionLog transactionLog, string errorMessage) returns http:Response {
    transactionLog.status = FAILURE;
    transactionLog.errorMessage = e.message();
    logTransaction(transactionLog);

    http:Response response = new;
    response.statusCode = 500;
    response.setPayload({message: errorMessage});
    return response;
}

public isolated function handleHTTP(http:Request req, http:Caller caller) returns http:Response {
    RequestLog requestLog = {
        host: caller.remoteAddress.host,
        port: caller.remoteAddress.port,
        messageType: "HTTP",
        payload: getPayload(req).toString(),
        path: req.rawPath,
        requestHeaders: extractHeadersFromReq(req),
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
            responseHeaders: extractHeadersFromRes(transformedResponse),
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

public isolated function handleTCP(string data, tcp:Caller caller) returns byte[] {
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
        json transformedData = check messageTransformer.transform(data);

        TcpRequestContext reqCtx = check buildRequestContextForTCP(data, transformedData, in_contentType);
        transactionLog.clientId = reqCtx.username;

        ResponseContext|error resCtx = routeTCP(reqCtx);

        if resCtx is error {
            transactionLog.status = FAILURE;
            transactionLog.errorMessage = resCtx.message();
            logTransaction(transactionLog);
            return check createHL7AckMessage(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, string `Failed to process message ${resCtx.message()}`);
        }
        http:Response res = resCtx.response;
        workflow workflow = resCtx.route.workflow;

        match res.statusCode {
            http:STATUS_CREATED => {
                byte[] ackMessage = check createHL7AckMessage(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AA", reqCtx.msgId, "Resource created successfully!");
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

                byte[] ackMessage = check createHL7AckMessage(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AA", reqCtx.msgId, "Resource updated successfully!");
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
            _ => {
                transactionLog.status = FAILURE;
                transactionLog.errorMessage = "Failed to process message";
                logTransaction(transactionLog);

                return check createHL7AckMessage(reqCtx.sendingFacility, reqCtx.receivingFacility, reqCtx.sendingApplication, reqCtx.receivingApplication, "ACK^R01", "AE", reqCtx.msgId, "Failed to process message");
            }
        }
    } on fail error e {
        return handleTcpError(e, transactionLog, "Failed to process the message: " + e.message()).toBytes();
    }
}
