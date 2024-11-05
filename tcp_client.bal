import ballerina/io;
import ballerina/log;
import ballerina/tcp;

public function main() returns error? {
    // Define the server address and port
    string serverAddress = "localhost";
    int serverPort = 9086;

    // Create a TCP client
    tcp:Client tcpClient = check new (serverAddress, serverPort);

    // Define the ADT^A01 message (Patient Create)
    string message_a01 = string `MSH|^~\\&|SendingApp|SendingFac|ReceivingApp|ReceivingFac|20241013120000||ADT^A01|12345|P|2.3
EVN|A01|20241013120000
PID|1||2^^^Hospital^MR||Doe^John^A||1980-01-01|M|||123 Main St^^Anytown^CA^12345|555-555-5555|||M
NK1|1|Doe^Jane|SPO|456 Secondary St^^Anytown^CA^12345|555-666-7777
PV1|1|I|W^389^1^UCLA|3|||1111^Jones^John^A^^Dr.||2222^Smith^Jane^B^^Dr.||SUR||||ADM|A0|`;

    // Define the ADT^A06 message (Patient Update)
    string message_a06 = string `MSH|^~\\&|SendingApp|SendingFac|ReceivingApp|ReceivingFac|20241013130000||ADT^A06|54321|P|2.3
EVN|A08|20241013130000
PID|1||5^^^Hospital^MR||Doe^John^A||1980-01-01|M|||789 Updated St^^Newtown^CA^54321|555-777-8888|||M
NK1|1|Doe^Jane|SPO|789 Secondary St^^Newtown^CA^54321|555-999-0000
PV1|1|I|W^389^1^UCLA|3|||1111^Jones^John^A^^Dr.||2222^Smith^Jane^B^^Dr.||SUR||||ADM|A0|`;

    // Define the QBP^Q23 message (Patient Query)
    string message_q23 = string `MSH|^~\\&|SendingApp|SendingFac|ReceivingApp|ReceivingFac|20241013140000||QBP^Q21|67890|P|2.4
QPD|IHE PIX Query|Q123456|5^^^Hospital^MR|Doe^John^A|1980-01-01|M
RCP|I`;

    // Send the ADT^A01 (Patient Create) message to the server
    log:printInfo("Sending ADT^A01 (Patient Create)...");
    check sendMessageAndReceiveResponse(tcpClient, message_a01);

    // Send the ADT^A08 (Patient Update) message to the server
    // log:printInfo("Sending ADT^A06 (Patient Update)...");
    // check sendMessageAndReceiveResponse(tcpClient, message_a06);

    // // Send the QBP^Q23 (Patient Query) message to the server
    // log:printInfo("Sending QBP^Q23 (Patient Query)...");
    // check sendMessageAndReceiveResponse(tcpClient, message_q23);

    // Close the TCP client connection
    check tcpClient->close();
    log:printInfo("TCP client connection closed.");
}

// Function to send a message and receive the response
function sendMessageAndReceiveResponse(tcp:Client tcpClient, string message) returns error? {
    // Send the message to the server
    check tcpClient->writeBytes(message.toBytes());
    log:printInfo("Message sent to the server.");

    // Read the response from the server
    byte[] response = check tcpClient->readBytes();
    string responseMessage = check string:fromBytes(response);
    io:println("Response from server: ", responseMessage);
}
