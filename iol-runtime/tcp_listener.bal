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

    remote function onBytes(tcp:Caller caller, readonly & byte[] data) returns tcp:Error?|error {
        // TODO: 
        // - pass the data to the router

        string tcpRequest = check string:fromBytes(data);

        // io:println("Received data over TCP: ", string:fromBytes(data));
        // string responseMessage = "Data received successfully.";
        // check caller->writeBytes(responseMessage.toBytes());
        // io:println("Response sent to TCP client.");

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
