import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/websubhub;

isolated websubhub:PublisherClient webSubHub = check new (webSubHubSettings.URL);
final string[] topics = webSubHubSettings.TOPICS_TO_REGISTER;

// Register topics with WebSubHub
public function registerWebSubHubTopics() returns error? {
    log:printInfo("Attempting to register WebSubHub topics...");

    if !checkRetryHubReachable(webSubHubSettings.URL) {
        log:printError("WebSubHub is not reachable after retries. Aborting topic registration.");
        return;
    }

    foreach var topic in topics {
        lock {
            websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError registrationResponse = webSubHub->registerTopic(topic);
            if registrationResponse is websubhub:TopicRegistrationError {
                log:printError(string `Topic registration failed for topic: ${topic}`);
                return;
            }
        }
        log:printInfo(string `Topic registered successfully: ${topic}`);
    }
}

// Publish updates to a topic
public isolated function publishToHub(string topic, json content) returns error? {
    lock {
        websubhub:Acknowledgement ack = check webSubHub->publishUpdate(topic, content.cloneReadOnly());
        log:printInfo(string `Received acknowledgment for content update on topic: ${topic}`, response = ack);
    }
}

function checkRetryHubReachable(string hubUrl) returns boolean {
    int attempts = 0;
    while attempts < webSubHubSettings.MAX_RETRIES {
        if isHubReachable(hubUrl) {
            return true;
        }
        log:printWarn(string `Hub is not reachable. Retrying in ${webSubHubSettings.RETRY_INTERVAL} seconds... (Attempt ${attempts + 1}/${webSubHubSettings.MAX_RETRIES})`);
        attempts += 1;
        runtime:sleep(webSubHubSettings.RETRY_INTERVAL);
    }
    return false;
}

function isHubReachable(string hubUrl) returns boolean {
    do {
        http:Client hubClient = check new (hubUrl);
        http:Response response = check hubClient->get("/");
        return true;
    } on fail error err {
        log:printWarn(string `Error reaching hub: ${err.message()}`);
        return false;
    }
}
