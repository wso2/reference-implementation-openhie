import ballerina/io;

configurable Ports ports = ?;

public function main() returns error? {

    check startHttpListener(ports.HTTP_PORT);
    check startTcpListener(ports.TCP_PORT);

    io:println("Services started successfully.");

    // check saveAuditMessage(test_generateAuditMessage());
    while true {
    }
}
