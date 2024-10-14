import ballerina/log;
import ballerina/websubhub;

public function main() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new ("http://localhost:9090/hub");
    websubhub:TopicRegistrationSuccess registrationResponse = check websubHubClientEP->registerTopic("audit");
    log:printInfo("Received topic-registration response", response = registrationResponse);
}
