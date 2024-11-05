import ballerina/http;
import ballerina/log;
import ballerina/websubhub;

type OpenSearchConfig record {|
    string url;
    string username;
    string password;
|};

configurable OpenSearchConfig openSearchConfig = ?;
// index topic map
const map<string> indexTopicMap = {
    "transaction": "openhie_ref_impl-transactions",
    "audit": "openhie_ref_impl-audit"
};

final http:Client openSearchClient = check new (openSearchConfig.url,
    // Disable SSL verification for testing purposes (not recommended for production)
    secureSocket = {
        enable: false
    },
    auth = {
        username: openSearchConfig.username,
        password: openSearchConfig.password
    }
);

isolated function sendEvent(websubhub:UpdateMessage message) returns error? {
    string subtopic = message.hubTopic.substring(OPENSEARCH_TOPIC_PREFIX.length() + 1);

    http:Request req = new;
    req.setPayload(message.content.toJson(), contentType = "application/json");

    http:Response|http:ClientError response = openSearchClient->post(string `/${indexTopicMap.get(subtopic)}/_doc`, req);
    if response is http:ClientError {
        log:printError("failed to send ", message = response.message());
        return response;
    }
    if response.statusCode != http:STATUS_CREATED {
        log:printError("Failed to send log to Fluent Bit");
    }
    log:printInfo("Log sent to Fluent Bit", message = check response.getTextPayload());
}
