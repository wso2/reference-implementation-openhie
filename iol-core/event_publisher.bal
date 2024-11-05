import ballerina/http;
import ballerina/log;
import ballerina/websubhub;

isolated websubhub:PublisherClient websubHubClientEP = check new (externalServices.WEBSUB_HUB_URL);

// topics to be registered with the WebSubHub
final string[] topics = [
    "audit",
    "opensearch transaction",
    "opensearch audit"
];

public function registerWebSubHubTopics() returns error? {
    log:printInfo("WebSubHub Publisher Client created successfully.");
    if (!isHubReachable(externalServices.WEBSUB_HUB_URL)) {
        log:printError("WebSubHub is not reachable.");
        return;
    }
    foreach var topic in topics {
        lock {
            websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError registrationResponse = websubHubClientEP->registerTopic(topic);
            if (registrationResponse is websubhub:TopicRegistrationError) {
                log:printError(string `topic : ${topic} registeration failed.`);
                return;
            }
        }
        log:printInfo(string `topic : ${topic} registered successfully.`);
    }
}

public isolated function publish(string topic, json content) returns error? {
    lock {
        websubhub:Acknowledgement ack = check websubHubClientEP->publishUpdate(topic, content.cloneReadOnly());
        log:printInfo("Received response for content-update", response = ack);
    }
}

function isHubReachable(string hubUrl) returns boolean {
    do {
        http:Client hubClient = check new (hubUrl);
        http:Response response = check hubClient->get("/");
        return true;
    } on fail {
        return false;
    }
}
