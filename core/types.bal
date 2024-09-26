import ballerina/http;

public type Ports record {|
    int HTTP_PORT;
    int TCP_PORT;
|};

public type DBConfig record {|
    string host;
    int port;
    string dbname;
    string username;
    string password;
|};

public type Payload json|xml|string;

type GenericRoute record {|
    string target;
|};

public type HttpAuthConfig http:CredentialsConfig|http:OAuth2ClientCredentialsGrantConfig|http:BearerTokenConfig|http:JwtIssuerConfig;

public type HttpRoute record {|
    *GenericRoute;
    string path;
    string[] methods;
    HttpAuthConfig auth?;
    // map<string> headers?;
|};

// Data types related to Audit
public type Code record {
    string code;
    string originalText;
    string codeSystemName;
    string? displayName;
};

public type EventIdentification record {
    Code eventActionCode;
    string eventDateTime;
    string eventOutcomeIndicator;
    Code eventID;
    Code? eventTypeCode;
};

public type ActiveParticipant record {
    string userID;
    string userIsRequestor;
    Code roleID;
    string? altUserID;
};

public type AuditSourceIdentification record {
    string auditSourceID;
    string? auditSourceTypeCode;
};

public type ParticipantObjectIdentification record {
    Code participantObjectID;
    string participantObjectTypeCode;
    string? participantObjectName;
};

public type EventConfig record {|
    Code eventID;
    Code eventTypeCode;
    string actionCode; // Action code such as 'E' for Execute, 'R' for Read, etc.
|};

public type AuditMessage record {|
    EventIdentification eventIdentification;
    ActiveParticipant activeParticipant;
    AuditSourceIdentification auditSource;
    ParticipantObjectIdentification participantObject;
    xml rawMessage;
|};
