import ballerina/lang.runtime;
import ballerina/log;

configurable Ports ports = ?;
public configurable SystemInfo systemInfo = ?;
public configurable ExternalServices externalServices = ?;

function init() returns error? {
    check startHttpListener(ports.HTTP_LISTENER_PORT);
    check startTcpListener(ports.TCP_LISTENER_PORT);
    check registerWebSubHubTopics();
    check initHttpClients();
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
