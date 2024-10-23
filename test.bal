// import ballerina/http;
// import ballerina/io;

// public function splitString(string str, string delimiter) returns string[] {
//     return re `${delimiter}`.split(str);
// }

// public function main() returns error? {

//     string[] result = splitString("test/bal", "/");
//     foreach string s in result {
//         io:println(s);
//     }

// }

// sample service running on 9090 and print the request and send something
import ballerina/http;
import ballerina/io;

service / on new http:Listener(9095) {
    resource function post .(http:Request req) returns http:Response|error {
        // Get the request payload
        json payload = check req.getJsonPayload();

        // Define the FHIR server URL
        string fhirServerUrl = "http://localhost:8081/fhir/Patient";

        // Create a new HTTP client
        http:Client fhirClient = check new (fhirServerUrl);

        io:print("recieved payload : ", payload);

        // Send the patient record to the FHIR server
        http:Response response = check fhirClient->post("/", payload);

        // Print the response from the FHIR server
        io:println("FHIR Server Response: ", response.getTextPayload());

        return response;
    }
}

