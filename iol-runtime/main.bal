import ballerina/lang.runtime;
import ballerina/log;

configurable Ports ports = ?;

// configurable SystemInfo systemInfo = ?;

// final string NETWORK_ACCESS_POINT_ID = systemInfo.NETWORK_ACCESS_POINT_ID;
// final string AUDIT_ENTERPRISE_SITE_ID = systemInfo.AUDIT_ENTERPRISE_SITE_ID;
// final string SYSNAME = systemInfo.SYSNAME;

public function main() returns error? {
    check startHttpListener(ports.HTTP_LISTENER_PORT);
    check startTcpListener(ports.TCP_LISTENER_PORT);
    log:printInfo("Services started successfully.");
    waitForShutdownSignal();
}

function waitForShutdownSignal() {
    while true {
        runtime:sleep(1000);
    }
}
