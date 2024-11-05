import ballerina/http;

public type ExternalServices record {|
    string WEBSUB_HUB_URL;
|};

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

public type RequestContext record {
    string username;
    string patientId;
    string contentType;
};

public type TcpRequestContext record {|
    *RequestContext;
    json fhirMessage;
    string eventCode;
    string msgId;
    string sendingFacility;
    string receivingFacility;
    string sendingApplication;
    string receivingApplication;
|};

public type HTTPRequstContext record {
    *RequestContext;
    http:Request httpRequest;
};

public type ResponseContext record {
    http:Response response;
    HttpRoute|TcpRoute route;
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

public type RequestLog record {|
    string host;
    int port;
    string messageType;
    string payload?;
    string path?;
    map<string> requestHeaders?;
    string method?;
    string timestamp;
|};

public type ResponseLog record {|
    string status;
    string payload;
    map<string> responseHeaders?;
    string timestamp;
|};

public enum TransactionStatus {
    SUCCESS,
    FAILURE,
    UNKNOWN
};

public type TransactionLog record {|
    string clientId;
    TransactionStatus status;
    RequestLog requestLog;
    ResponseLog responseLog?;
    string errorMessage?;
|};
