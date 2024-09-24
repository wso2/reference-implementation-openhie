import ballerina/io;

configurable int HTTP_PORT = ?;
configurable int TCP_PORT = ?;

public function main() returns error? {

    check startHttpListener(HTTP_PORT);
    check startTcpListener(TCP_PORT);

    io:println("Services started successfully.");

    while true {
    }
}
