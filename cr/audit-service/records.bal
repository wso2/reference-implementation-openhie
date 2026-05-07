// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).

// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at

// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

// Holds the information needed to form an audit event based on the FHIR AuditEvent resource
// http://hl7.org/fhir/R4/auditevent.html
type InternalAuditEvent record {|
    // Value Set http://hl7.org/fhir/ValueSet/audit-event-type
    string typeCode = "rest";
    // Value Set http://hl7.org/fhir/ValueSet/audit-event-sub-type 
    string subTypeCode;
    // Value Set http://hl7.org/fhir/ValueSet/audit-event-action
    string actionCode;
    // Value Set http://hl7.org/fhir/ValueSet/audit-event-outcome
    string outcomeCode;
    // Free text description of the outcome (e.g., failure reason)
    string outcomeDesc = "";
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
