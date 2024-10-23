import ballerina/http;

public type SystemInfo record {|
    string SYSNAME;
|};

public type Ports record {|
    int HTTP_LISTENER_PORT;
    int TCP_LISTENER_PORT;
|};

public enum workflow {
    PATIENT_DEMOGRAPHICS_QUERY,
    PATIENT_DEMOGRAPHICS_UPDATE,
    PATIENT_DEMOGRAPHICS_CREATE
}

public type UserDetails record {
    string username;
    string userRole;
    string userRoleCode?;
};

type GenericRoute record {|
    string target;
    HttpAuthConfig auth?;
    workflow workflow;
|};

public type HttpAuthConfig http:CredentialsConfig|http:OAuth2ClientCredentialsGrantConfig|http:BearerTokenConfig|http:JwtIssuerConfig;

public type HttpRoute record {|
    *GenericRoute;
    string path;
    string[] methods;
    string contentType?;

|};

public type TcpRoute record {|
    *GenericRoute;
    string HL7Code;
    string method;
|};

public type TcpInternalPayload record {|
    json fhirMessage;
    string eventCode;
|};

public type TcpRequestContext record {|
    json fhirMessage;
    string eventCode;
    string msgId;
    string patientId;
    string sendingFacility;
    string receivingFacility;
    string sendingApplication;
    string receivingApplication;
|};

public type TcpResponseContext record {
    http:Response httpResponse;
    workflow workflow;
};

public type InternalAuditEvent record {|
    // Value Set http://hl7.org/fhir/ValueSet/audit-event-type
    string typeCode = "rest";
    // Value Set http://hl7.org/fhir/ValueSet/audit-event-sub-type 
    string subTypeCode;
    // Value Set http://hl7.org/fhir/ValueSet/audit-event-action
    string actionCode;
    // Value Set http://hl7.org/fhir/ValueSet/audit-event-outcome 
    string outcomeCode;
    string recordedTime;
    // actor involved in the event
    // Value Set http://hl7.org/fhir/ValueSet/participation-role-type
    string agentType;
    string agentName;
    boolean agentIsRequestor;
    // source of the event
    string sourceObserverName;
    // Value Set http://hl7.org/fhir/R4/valueset-audit-source-type.html
    string sourceObserverType;
    // Value Set http://hl7.org/fhir/ValueSet/audit-entity-type
    string entityType;
    // Value Set http://hl7.org/fhir/ValueSet/object-role
    string entityRole;
    // Requested relative path - eg.: "Patient/example/_history/1"
    string entityWhatReference;

|};

// // Data types related to Transaction
// public type requestLog record {|
//     string host;
//     string port;
//     string path;
//     // headers
//     string payload;
//     string method;
//     time:Utc timestamp;
// |};

// # Description.
// #
// # + status - field description  
// # + payload - field description  
// # + timestamp - field description
// public type responseLog record {|
//     int status;
//     // headers
//     string payload;
//     time:Utc timestamp;
// |};

// public type Transaction record {|
//     string clientId;
//     TransactionStatus status;
//     requestLog requestPayload?;
//     responseLog responsePayload?;
//     map<string> requestHeaders;
//     map<string> responseHeaders;
//     boolean isSuccess;
//     string? errorMessage;
// |};

// public enum TransactionStatus {
//     SUCCESS,
//     FAILURE
// };
