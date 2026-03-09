// Copyright (c) 2025 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/log;
import ballerina/time;

isolated function sendAuditEvent(InternalAuditEvent auditEvent) returns error? {
    do {
        check publishToHub("audit", <json>auditEvent);
    } on fail error e {
        log:printError("Failed to send the audit event.", 'error = e);
    }
}

public isolated function auditRequest(workflow workflow, string username, string objectID, string sysname) returns error? {
    match workflow {
        PATIENT_DEMOGRAPHICS_QUERY => {
            check sendAuditEvent(buildPdqAuditRequest(username, objectID, sysname, "0"));
        }
        PATIENT_DEMOGRAPHICS_UPDATE => {
            check sendAuditEvent(buildPduAuditRequest(username, objectID, sysname, "0"));
        }
        PATIENT_DEMOGRAPHICS_CREATE => {
            check sendAuditEvent(buildPdcAuditRequest(username, objectID, sysname, "0"));
        }
        // Add more cases for other workflows
        _ => {
            log:printError("Invalid workflow.");
        }
    }
}

// Audit Request for Patient Demographics Query 
public isolated function buildPdqAuditRequest(string username, string objectID, string sysname, string outcome) returns InternalAuditEvent {
    return {
        typeCode: "110112",
        subTypeCode: "READ",
        actionCode: "R",
        outcomeCode: outcome,
        recordedTime: time:utcToString(time:utcNow(3)),
        agentType: "User",
        agentName: username,
        agentIsRequestor: true,
        sourceObserverName: sysname,
        sourceObserverType: "3", // Assuming "3" is the appropriate type for the source observer
        entityType: "2", // Object type for a person (patient)
        entityRole: "1", // 1 for patient role
        entityWhatReference: objectID
    };
}

public isolated function buildPdcAuditRequest(string username, string objectID, string sysname, string outcome) returns InternalAuditEvent {
    return {
        typeCode: "110112",
        subTypeCode: "CREATE",
        actionCode: "C",
        outcomeCode: outcome,
        recordedTime: time:utcToString(time:utcNow(3)),
        agentType: "User",
        agentName: username,
        agentIsRequestor: true,
        sourceObserverName: sysname,
        sourceObserverType: "3", // Assuming "3" is the appropriate type for the source observer
        entityType: "2", // Object type for a person (patient)
        entityRole: "1", // 1 for patient role
        entityWhatReference: objectID
    };
}

public isolated function buildPduAuditRequest(string username, string objectID, string sysname, string outcome) returns InternalAuditEvent {
    return {
        typeCode: "110112",
        subTypeCode: "UPDATE",
        actionCode: "U",
        outcomeCode: outcome,
        recordedTime: time:utcToString(time:utcNow(3)),
        agentType: "User",
        agentName: username,
        agentIsRequestor: true,
        sourceObserverName: sysname,
        sourceObserverType: "3", // Assuming "3" is the appropriate type for the source observer
        entityType: "2", // Object type for a person (patient)
        entityRole: "1", // 1 for patient role
        entityWhatReference: objectID
    };
}

// public isolated function audit_PDQ_Response(string username, string objectID, string sysname, string outcome) returns error? {
//     InternalAuditEvent auditEvent = {
//         typeCode: "110112",
//         subTypeCode: "READ",
//         actionCode: "E",
//         outcomeCode: outcome,
//         recordedTime: time:utcToString(time:utcNow(3)),
//         agentType: "User",
//         agentName: username,
//         agentIsRequestor: true,
//         sourceObserverName: sysname,
//         sourceObserverType: "3", // Assuming "3" is the appropriate type for the source observer
//         entityType: "2", // Object type for a person (patient)
//         entityRole: "1", // 1 for patient role
//         entityWhatReference: objectID
//     };
//     check sendAuditEvent(auditEvent);
// }

