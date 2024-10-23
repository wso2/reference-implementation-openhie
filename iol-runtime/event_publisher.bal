import ballerina/log;
import ballerina/websubhub;

configurable string WEBSUB_HUB_URL = ?;
isolated websubhub:PublisherClient websubHubClientEP = check new (WEBSUB_HUB_URL);
final string[] topics = [
    "audit"
];

public function registerWebSubHubTopics() returns error? {
    log:printInfo("WebSubHub Publisher Client created successfully.");
    foreach var topic in topics {
        lock {
            websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError registrationResponse = websubHubClientEP->registerTopic(topic);
            if (registrationResponse is websubhub:TopicRegistrationError) {
                log:printError(string `topic : ${topic} Already Registered.`);
                return;
            }
            log:printInfo(string `topic : ${topic} registered successfully.`);
        }
    }
}

public isolated function publish(string topic, json content) returns error? {
    lock {
        websubhub:Acknowledgement ack = check websubHubClientEP->publishUpdate(topic, content.cloneReadOnly());
        log:printInfo("Received response for content-update", response = ack);
    }
}
