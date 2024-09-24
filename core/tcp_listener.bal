import ballerina/io;
import ballerina/tcp;

tcp:Service tcpService = service object {
    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService {
        io:println("New TCP client connected.");
        return new TcpService();
    }
};

service class TcpService {
    *tcp:ConnectionService;

    remote function onBytes(tcp:Caller caller, readonly & byte[] data) returns tcp:Error? {
        // TODO: pass the data to the router

        // io:println("Received data over TCP: ", string:fromBytes(data));
        // string responseMessage = "Data received successfully.";
        // check caller->writeBytes(responseMessage.toBytes());
        // io:println("Response sent to TCP client.");
    }

    remote function onClose() {
        io:println("TCP client connection closed.");
    }

    remote function onError(tcp:Error err) {
        io:println("TCP error occurred: ", err.message());
    }
}

public function startTcpListener(int port) returns error? {
    io:println("Starting TCP listener on port: ", port);
    tcp:Listener tcpListener = check new (port);
    check tcpListener.attach(tcpService, "/");
    check tcpListener.'start();
}
