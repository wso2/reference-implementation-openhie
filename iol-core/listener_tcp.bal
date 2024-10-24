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

        // transformers
        TCPMessageBuilder messageBuilder = check getTCPMessageBuilder("hl7");
        TCPMessageFormatter messageFormatter = check getTCPMessageFormatter("hl7");

        // request validation
        do {
            check requestValidatorHL7(fromBytes);
        } on fail error e {
            // construct partial request context with only the required fields
            TcpRequestContext reqCtx = {
                fhirMessage: {},
                msgId: extractHL7MessageId(fromBytes),
                eventCode: "",
                patientId: "",
                sendingFacility: extractSendingFacility(fromBytes),
                receivingFacility: extractReceivingFacility(fromBytes),
                sendingApplication: extractSendingApplication(fromBytes),
                receivingApplication: extractRecievingApplication(fromBytes)
            };
            byte[] response = check messageFormatter.format(e, reqCtx);
            check caller->writeBytes(response);
            return;
        }

        // message building
        TcpRequestContext reqCtx = check messageBuilder.process(fromBytes);
        // routing
        TcpResponseContext|error resCtx = routeTCP(reqCtx);

        // do{
        //     // response validatation
        // }on fail error e{

        // }

        // formatting
        byte[] response = check messageFormatter.format(resCtx, reqCtx);
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
