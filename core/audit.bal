// import ballerina/io;
import ballerina/time;

// Function to convert Code to XML
isolated function codeToXML(Code code) returns xml {
    xml codeXml = xml `<Code csd-code="${code.code}" originalText="${code.originalText}" codeSystemName="${code.codeSystemName}"/>`;
    if code.displayName is string {
        codeXml = codeXml + xml `<displayName>${<string>code.displayName}</displayName>`;
    }
    return codeXml;
}

// Function to convert EventIdentification to XML
isolated function eventIdentificationToXML(EventIdentification eIdent) returns xml {
    xml eventTypeCodeXml = eIdent.eventTypeCode is Code ? xml `<EventTypeCode>${codeToXML(<Code>eIdent.eventTypeCode)}</EventTypeCode>` : xml ``;
    return xml `<EventIdentification>
        <EventActionCode>${eIdent.eventActionCode.code}</EventActionCode>
        <EventDateTime>${eIdent.eventDateTime}</EventDateTime>
        <EventOutcomeIndicator>${eIdent.eventOutcomeIndicator}</EventOutcomeIndicator>
        <EventID>${codeToXML(eIdent.eventID)}</EventID>
        ${eventTypeCodeXml}
    </EventIdentification>`;
}

// Function to convert ActiveParticipant to XML
isolated function activeParticipantToXML(ActiveParticipant participant) returns xml {
    xml altUserIdXml = (participant.altUserID is string) ? xml `<altUserID>${<string>participant.altUserID}</altUserID>` : xml ``;
    return xml `<ActiveParticipant userID="${participant.userID}" userIsRequestor="${participant.userIsRequestor}">
        ${altUserIdXml}
        <roleID>${codeToXML(participant.roleID)}</roleID>
    </ActiveParticipant>`;
}

// Function to convert AuditSourceIdentification to XML
isolated function auditSourceToXML(AuditSourceIdentification _source) returns xml {
    xml auditSourceTypeCodeXml = (_source.auditSourceTypeCode is string) ? xml `<auditSourceTypeCode>${<string>_source.auditSourceTypeCode}</auditSourceTypeCode>` : xml ``;
    return xml `<AuditSourceIdentification auditSourceID="${_source.auditSourceID}">
        ${auditSourceTypeCodeXml}
    </AuditSourceIdentification>`;
}

// Function to convert ParticipantObjectIdentification to XML
isolated function participantObjectToXML(ParticipantObjectIdentification obj) returns xml {
    xml nameXml = (obj.participantObjectName is string) ? xml `<participantObjectName>${<string>obj.participantObjectName}</participantObjectName>` : xml ``;
    return xml `<ParticipantObjectIdentification>
        <participantObjectID>${codeToXML(obj.participantObjectID)}</participantObjectID>
        <participantObjectTypeCode>${obj.participantObjectTypeCode}</participantObjectTypeCode>
        ${nameXml}
    </ParticipantObjectIdentification>`;
}

# This function generates an ATNA-compliant audit message in XML format based on the provided parameters.
#
# + outcome - The outcome of the event (e.g., "Success" or "Failure").
# + sysname - The name of the system generating the audit message.
# + username - The username of the active participant.
# + userRole - The role of the user in the system.
# + userRoleCode - The code representing the user's role.
# + objectType - The type code of the participant object.
# + participantObjectID - The ID of the participant object.
# + participantObjectName - The name of the participant object (optional).
# + eventID - The code representing the event ID.
# + eventTypeCode - The code representing the event type.
# + return - Returns the generated audit message as an XML.
public isolated function generateAuditMessage(string outcome, string sysname, string username, string userRole, string userRoleCode, string objectType, string participantObjectID, string? participantObjectName, Code eventID, Code eventTypeCode) returns AuditMessage {
    // Create EventIdentification
    EventIdentification eIdent = {
        eventActionCode: {code: "EXECUTE", originalText: "Execute", codeSystemName: "DCM", displayName: ()},
        eventDateTime: time:utcToString(time:utcNow(3)),
        eventOutcomeIndicator: outcome,
        eventID: eventID,
        eventTypeCode: eventTypeCode
    };

    // Create ActiveParticipant
    ActiveParticipant activeParticipant = {
        userID: username,
        userIsRequestor: "Y",
        roleID: {code: userRoleCode, originalText: userRole, codeSystemName: "RoleCodeSystem", displayName: ()},
        altUserID: ""
    };

    // Create AuditSourceIdentification
    AuditSourceIdentification auditSource = {auditSourceID: sysname, auditSourceTypeCode: "1"};

    // Create ParticipantObjectIdentification
    ParticipantObjectIdentification participantObject = {
        participantObjectID: {code: participantObjectID, originalText: participantObjectName ?: "DefaultObjectName", codeSystemName: "ObjectSystem", displayName: ()},
        participantObjectTypeCode: objectType,
        participantObjectName: participantObjectName
    };
    xml auditMessageInXML = xml `<AuditMessage>
    ${eventIdentificationToXML(eIdent)}
    ${activeParticipantToXML(activeParticipant)}
    ${auditSourceToXML(auditSource)}
    ${participantObjectToXML(participantObject)}
</AuditMessage>`;

    AuditMessage auditMessage = {
        eventIdentification: eIdent,
        activeParticipant: activeParticipant,
        auditSource: auditSource,
        participantObject: participantObject,
        rawMessage: auditMessageInXML
    };

    return auditMessage;
}

// Test function for generating a single audit message

public isolated function generateLoginAuditMessage(string outcome, string sysname, string username, string userRole, string userRoleCode) returns AuditMessage {
    Code eventID = {code: "110114", originalText: "UserAuthenticated", codeSystemName: "DCM", displayName: "User Authenticated"};
    Code eventType = {code: "110122", originalText: "Login", codeSystemName: "DCM", displayName: "Login"};

    AuditMessage auditMsg = generateAuditMessage(outcome, sysname, username, userRole, userRoleCode, "1", "", "", eventID, eventType);
    return auditMsg;
}
// public function test_generateAuditMessage() returns AuditMessage {
//     Code eventID = {code: "110114", originalText: "UserAuthenticated", codeSystemName: "DCM", displayName: "User Authenticated"};
//     Code eventType = {code: "110122", originalText: "Login", codeSystemName: "DCM", displayName: "Login"};

//     AuditMessage auditMsg = generateAuditMessage("Success", "MySystem", "admin", "Administrator", "admin", "1", "12345", "SampleObject", eventID, eventType);
//     // io:println(auditXml.toString());
//     return auditMsg;
// }
