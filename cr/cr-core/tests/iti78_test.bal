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

// ITI-78 Patient Demographics Query for Mobile — Compliance Tests
// ================================================================
// Tests the Patient Demographics Supplier actor against IHE ITI-78 requirements.
// Reference: https://profiles.ihe.net/ITI/PDQm/ITI-78.html
//
// Covers:
//   1. Patient Search (GET /Patient?params) — search-type interaction
//   2. Patient Read (GET /Patient/{id}) — read interaction
//   3. Required search parameters (_id, family, given, identifier, gender, birthdate, etc.)
//   4. Mandatory parameter combinations (family+gender, birthdate+family)
//   5. Response Bundle structure (type, total, entry, search.mode)
//   6. HTTP status codes (200 OK, 404 Not Found, unsupported params)
//   7. OperationOutcome on errors
//   8. Inactive/deprecated patient handling

import ballerina/http;
import ballerina/mime;
import ballerina/test;
import ballerina/io;

// ============================================================
// TEST CONFIGURATION
// ============================================================

// HTTP client targeting the FHIR service under test
final http:Client testClient = check new ("http://localhost:9090/fhir/r4");

// Admin auth token (base64-encoded JSON: {"sub":"test-admin@test.com","role":"admin","exp":9999999999999})
final string adminToken = getAdminToken();

// Viewer auth token
final string viewerToken = getViewerToken();

// Shared state: patient ID created during setup
string createdPatientId = "";
string createdPatientId2 = "";

function getAdminToken() returns string {
    string payload = "{\"sub\":\"test-admin@test.com\",\"role\":\"admin\",\"exp\":9999999999999}";
    string|byte[]|mime:EncodeError|io:ReadableByteChannel encoded = mime:base64Encode(payload.toBytes());
    string raw;
    if encoded is string {
        raw = encoded;
    } else if encoded is byte[] {
        string|error s = string:fromBytes(encoded);
        if s is error {
            return "invalid";
        }
        raw = s;
    } else {
        return "invalid";
    }
    return re `[\r\n]`.replaceAll(raw, "");
}

function getViewerToken() returns string {
    string payload = "{\"sub\":\"test-viewer@test.com\",\"role\":\"viewer\",\"exp\":9999999999999}";
    string|byte[]|mime:EncodeError|io:ReadableByteChannel encoded = mime:base64Encode(payload.toBytes());
    string raw;
    if encoded is string {
        raw = encoded;
    } else if encoded is byte[] {
        string|error s = string:fromBytes(encoded);
        if s is error {
            return "invalid";
        }
        raw = s;
    } else {
        return "invalid";
    }
    return re `[\r\n]`.replaceAll(raw, "");
}

// ============================================================
// TEST SETUP: Seed test patients
// ============================================================

@test:BeforeGroups {value: ["iti78"]}
function setupTestPatients() returns error? {
    // Create Patient 1: John Smith
    json patient1 = {
        "resourceType": "Patient",
        "identifier": [
            {"system": "urn:oid:1.2.3.4", "value": "ITI78-TEST-001"}
        ],
        "active": true,
        "name": [{"family": "Smith", "given": ["John"]}],
        "gender": "male",
        "birthDate": "1990-01-15",
        "telecom": [
            {"system": "phone", "value": "+1-555-0101"},
            {"system": "email", "value": "john.smith@test.com"}
        ],
        "address": [{
            "line": ["123 Main St"],
            "city": "Springfield",
            "state": "IL",
            "postalCode": "62701",
            "country": "US"
        }]
    };

    http:Response resp1 = check testClient->put("/Patient?identifier=urn:oid:1.2.3.4|ITI78-TEST-001", patient1, {
        "Authorization": string `Bearer ${adminToken}`,
        "Content-Type": "application/fhir+json"
    });

    if resp1.statusCode == 200 || resp1.statusCode == 201 {
        json body1 = check resp1.getJsonPayload();
        json|error id1 = body1.id;
        if id1 is json {
            createdPatientId = id1.toString();
        }
    }

    // Create Patient 2: Jane Doe
    json patient2 = {
        "resourceType": "Patient",
        "identifier": [
            {"system": "urn:oid:1.2.3.4", "value": "ITI78-TEST-002"}
        ],
        "active": true,
        "name": [{"family": "Doe", "given": ["Jane"]}],
        "gender": "female",
        "birthDate": "1985-06-20",
        "telecom": [
            {"system": "phone", "value": "+1-555-0202"}
        ],
        "address": [{
            "city": "Chicago",
            "state": "IL",
            "postalCode": "60601",
            "country": "US"
        }]
    };

    http:Response resp2 = check testClient->put("/Patient?identifier=urn:oid:1.2.3.4|ITI78-TEST-002", patient2, {
        "Authorization": string `Bearer ${adminToken}`,
        "Content-Type": "application/fhir+json"
    });

    if resp2.statusCode == 200 || resp2.statusCode == 201 {
        json body2 = check resp2.getJsonPayload();
        json|error id2 = body2.id;
        if id2 is json {
            createdPatientId2 = id2.toString();
        }
    }
}

// ============================================================
// 1. SEARCH: Basic search returns Bundle (§2.3.78.4.2)
// ============================================================

@test:Config {groups: ["iti78", "search"]}
function testSearchReturnsBundle() returns error? {
    http:Response response = check testClient->get("/Patient", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search must return 200 OK");

    json body = check response.getJsonPayload();

    // ITI-78: Response is a Bundle of type "searchset"
    test:assertEquals(check body.resourceType, "Bundle", "Response must be a Bundle");
    test:assertEquals(check body.'type, "searchset", "Bundle type must be 'searchset'");

    // ITI-78: Bundle must include "total" property
    json|error total = body.total;
    test:assertFalse(total is error, "Bundle must include 'total' property");
}

// ============================================================
// 2. SEARCH: Bundle entries have search.mode = "match"
// ============================================================

@test:Config {groups: ["iti78", "search"], dependsOn: [testSearchReturnsBundle]}
function testSearchEntriesHaveSearchMode() returns error? {
    http:Response response = check testClient->get("/Patient", {
        "Authorization": string `Bearer ${adminToken}`
    });

    json body = check response.getJsonPayload();
    json|error entries = body.entry;

    if entries is json[] && entries.length() > 0 {
        json firstEntry = entries[0];
        json|error searchMode = firstEntry.search.mode;
        test:assertFalse(searchMode is error, "Each entry must have search.mode");
        if searchMode is json {
            test:assertEquals(searchMode.toString(), "match", "search.mode must be 'match'");
        }
    }
}

// ============================================================
// 3. SEARCH: _id parameter (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchById() returns error? {
    if createdPatientId == "" {
        test:assertFail("Setup failed: no patient ID available");
    }

    http:Response response = check testClient->get(
        string `/Patient?_id=${createdPatientId}`,
        {"Authorization": string `Bearer ${adminToken}`}
    );

    test:assertEquals(response.statusCode, 200, "Search by _id must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle", "Response must be a Bundle");

    int total = check (check body.total).cloneWithType();
    test:assertEquals(total, 1, "Search by _id should return exactly 1 result");
}

// ============================================================
// 4. SEARCH: family parameter (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByFamily() returns error? {
    http:Response response = check testClient->get("/Patient?family=Smith", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by family must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by family 'Smith' should find at least 1 patient");
}

// ============================================================
// 5. SEARCH: given parameter (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByGiven() returns error? {
    http:Response response = check testClient->get("/Patient?given=John", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by given must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by given 'John' should find at least 1 patient");
}

// ============================================================
// 6. SEARCH: identifier parameter (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByIdentifier() returns error? {
    http:Response response = check testClient->get(
        "/Patient?identifier=urn:oid:1.2.3.4|ITI78-TEST-001",
        {"Authorization": string `Bearer ${adminToken}`}
    );

    test:assertEquals(response.statusCode, 200, "Search by identifier must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertEquals(total, 1, "Search by identifier should return exactly 1 result");
}

// ============================================================
// 7. SEARCH: gender parameter (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByGender() returns error? {
    http:Response response = check testClient->get("/Patient?gender=male", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by gender must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by gender 'male' should find at least 1 patient");
}

// ============================================================
// 8. SEARCH: birthdate parameter (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByBirthdate() returns error? {
    http:Response response = check testClient->get("/Patient?birthdate=1990-01-15", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by birthdate must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by birthdate should find at least 1 patient");
}

// ============================================================
// 9. SEARCH: address-city parameter (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByAddressCity() returns error? {
    http:Response response = check testClient->get("/Patient?address-city=Springfield", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by address-city must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by address-city 'Springfield' should find at least 1 patient");
}

// ============================================================
// 10. SEARCH: address-state parameter
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByAddressState() returns error? {
    http:Response response = check testClient->get("/Patient?address-state=IL", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by address-state must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by address-state 'IL' should find at least 1 patient");
}

// ============================================================
// 11. SEARCH: address-postalcode parameter
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByAddressPostalCode() returns error? {
    http:Response response = check testClient->get("/Patient?address-postalcode=62701", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by address-postalcode must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by postal code should find at least 1 patient");
}

// ============================================================
// 12. SEARCH: address-country parameter
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByAddressCountry() returns error? {
    http:Response response = check testClient->get("/Patient?address-country=US", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by address-country must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by country 'US' should find at least 1 patient");
}

// ============================================================
// 13. SEARCH: telecom parameter
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByTelecom() returns error? {
    http:Response response = check testClient->get("/Patient?telecom=555-0101", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by telecom must return 200 OK");
}

// ============================================================
// 14. SEARCH: Mandatory combination — family + gender (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "combinations"]}
function testSearchByFamilyAndGender() returns error? {
    http:Response response = check testClient->get("/Patient?family=Smith&gender=male", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by family+gender must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "family=Smith & gender=male should find at least 1 patient");
}

// ============================================================
// 15. SEARCH: Mandatory combination — birthdate + family (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "combinations"]}
function testSearchByBirthdateAndFamily() returns error? {
    http:Response response = check testClient->get("/Patient?birthdate=1990-01-15&family=Smith", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by birthdate+family must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "birthdate+family should find at least 1 patient");
}

// ============================================================
// 16. SEARCH: No matches returns Bundle with total=0 (§2.3.78.4.3.3)
// ============================================================

@test:Config {groups: ["iti78", "search"]}
function testSearchNoMatchesReturnsEmptyBundle() returns error? {
    http:Response response = check testClient->get(
        "/Patient?family=ZZZZNONEXISTENT99999",
        {"Authorization": string `Bearer ${adminToken}`}
    );

    test:assertEquals(response.statusCode, 200, "No-match search must still return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle", "Response must be a Bundle");
    int total = check (check body.total).cloneWithType();
    test:assertEquals(total, 0, "No matches should return total=0");
}

// ============================================================
// 17. SEARCH: Unsupported search parameter returns error
// ============================================================

@test:Config {groups: ["iti78", "search", "errors"]}
function testSearchUnsupportedParameter() returns error? {
    http:Response response = check testClient->get(
        "/Patient?unsupportedParam=foo",
        {"Authorization": string `Bearer ${adminToken}`}
    );

    // Per ITI-78: Supplier may return 400 or ignore unsupported parameters
    // Our implementation returns 400
    test:assertEquals(response.statusCode, 400,
        "Unsupported search parameter should return 400 Bad Request");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "OperationOutcome",
        "Error response must be an OperationOutcome");
}

// ============================================================
// 18. READ: Patient by ID returns 200 (§2.3.78.4.3.2)
// ============================================================

@test:Config {groups: ["iti78", "read"]}
function testReadPatientById() returns error? {
    if createdPatientId == "" {
        test:assertFail("Setup failed: no patient ID available");
    }

    http:Response response = check testClient->get(
        string `/Patient/${createdPatientId}`,
        {"Authorization": string `Bearer ${adminToken}`}
    );

    test:assertEquals(response.statusCode, 200, "Read existing patient must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Patient", "Response must be a Patient resource");

    // Verify the returned patient has the correct ID
    test:assertEquals((check body.id).toString(), createdPatientId,
        "Returned Patient.id must match the requested ID");
}

// ============================================================
// 19. READ: Patient resource structure validation
// ============================================================

@test:Config {groups: ["iti78", "read"], dependsOn: [testReadPatientById]}
function testReadPatientResourceStructure() returns error? {
    if createdPatientId == "" {
        test:assertFail("Setup failed: no patient ID available");
    }

    http:Response response = check testClient->get(
        string `/Patient/${createdPatientId}`,
        {"Authorization": string `Bearer ${adminToken}`}
    );

    json body = check response.getJsonPayload();

    // Verify required FHIR Patient elements
    test:assertEquals(check body.resourceType, "Patient", "resourceType must be 'Patient'");

    // Patient must have identifier (PDQm Patient profile requirement)
    json|error identifiers = body.identifier;
    test:assertFalse(identifiers is error, "Patient must have identifier");

    // Patient must have name
    json|error names = body.name;
    test:assertFalse(names is error, "Patient should have name");
}

// ============================================================
// 20. READ: Non-existent patient returns 404 (§2.3.78.4.3.2)
// ============================================================

@test:Config {groups: ["iti78", "read", "errors"]}
function testReadNonExistentPatientReturns404() returns error? {
    http:Response response = check testClient->get(
        "/Patient/NONEXISTENT-9999-0000",
        {"Authorization": string `Bearer ${adminToken}`}
    );

    test:assertEquals(response.statusCode, 404,
        "Reading non-existent patient must return 404 Not Found");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "OperationOutcome",
        "404 response must include an OperationOutcome");
}

// ============================================================
// 21. SEARCH: Bundle entries contain fullUrl (§2.3.78.4.3.3)
// ============================================================

@test:Config {groups: ["iti78", "search"]}
function testSearchBundleEntriesHaveFullUrl() returns error? {
    http:Response response = check testClient->get("/Patient?family=Smith", {
        "Authorization": string `Bearer ${adminToken}`
    });

    json body = check response.getJsonPayload();
    json|error entries = body.entry;

    if entries is json[] && entries.length() > 0 {
        json firstEntry = entries[0];
        json|error fullUrl = firstEntry.fullUrl;
        test:assertFalse(fullUrl is error, "Each Bundle entry must have a fullUrl");

        string fullUrlStr = (check firstEntry.fullUrl).toString();
        test:assertTrue(fullUrlStr.includes("Patient/"),
            "fullUrl must reference a Patient resource");
    }
}

// ============================================================
// 22. SEARCH: Bundle entries contain Patient resource
// ============================================================

@test:Config {groups: ["iti78", "search"]}
function testSearchBundleEntriesContainPatientResource() returns error? {
    http:Response response = check testClient->get("/Patient?family=Smith", {
        "Authorization": string `Bearer ${adminToken}`
    });

    json body = check response.getJsonPayload();
    json|error entries = body.entry;

    if entries is json[] && entries.length() > 0 {
        json firstEntry = entries[0];
        json|error 'resource = firstEntry.'resource;
        test:assertFalse('resource is error, "Each entry must contain a resource");

        if 'resource is json {
            test:assertEquals(check 'resource.resourceType, "Patient",
                "Entry resource must be a Patient");
        }
    }
}

// ============================================================
// 23. SEARCH: active parameter (§2.3.78.4.1.2.1)
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByActive() returns error? {
    http:Response response = check testClient->get("/Patient?active=true", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by active must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle", "Response must be a Bundle");
}

// ============================================================
// 24. AUTH: Unauthenticated request returns 401 (Security)
// ============================================================

@test:Config {groups: ["iti78", "auth"]}
function testSearchWithoutAuthReturns401() returns error? {
    // Note: The service has optional auth for search (internal calls),
    // so this may return 200 for system user. Testing with invalid token instead.
    http:Response response = check testClient->get("/Patient", {
        "Authorization": "Bearer invalidtoken123"
    });

    test:assertEquals(response.statusCode, 401,
        "Request with invalid token should return 401 Unauthorized");
}

// ============================================================
// 25. SEARCH: Multiple parameter combination (family + given + gender)
// ============================================================

@test:Config {groups: ["iti78", "search", "combinations"]}
function testSearchByMultipleParams() returns error? {
    http:Response response = check testClient->get(
        "/Patient?family=Smith&given=John&gender=male",
        {"Authorization": string `Bearer ${adminToken}`}
    );

    test:assertEquals(response.statusCode, 200, "Multi-param search must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1,
        "Search by family=Smith&given=John&gender=male should find at least 1");
}

// ============================================================
// 26. SEARCH: _id with non-existent ID returns empty Bundle
// ============================================================

@test:Config {groups: ["iti78", "search"]}
function testSearchByIdNonExistentReturnsEmptyBundle() returns error? {
    http:Response response = check testClient->get(
        "/Patient?_id=NONEXISTENT-0000",
        {"Authorization": string `Bearer ${adminToken}`}
    );

    test:assertEquals(response.statusCode, 200, "Search by non-existent _id must return 200");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertEquals(total, 0, "Non-existent _id search should return total=0");
}

// ============================================================
// 27. READ: Patient has meta with versionId
// ============================================================

@test:Config {groups: ["iti78", "read"]}
function testReadPatientHasMeta() returns error? {
    if createdPatientId == "" {
        test:assertFail("Setup failed: no patient ID available");
    }

    http:Response response = check testClient->get(
        string `/Patient/${createdPatientId}`,
        {"Authorization": string `Bearer ${adminToken}`}
    );

    json body = check response.getJsonPayload();

    // FHIR R4: Patient should have meta with versionId
    json|error meta = body.meta;
    test:assertFalse(meta is error, "Patient should have meta element");

    if meta is json {
        json|error versionId = meta.versionId;
        test:assertFalse(versionId is error, "Patient.meta should have versionId");
    }
}

// ============================================================
// 28. SEARCH: Verify Bundle has correct resourceType and type
// ============================================================

@test:Config {groups: ["iti78", "search"]}
function testSearchBundleResourceTypeAndType() returns error? {
    http:Response response = check testClient->get("/Patient?gender=female", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200);

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
    test:assertEquals(check body.'type, "searchset");

    // Bundle must have an id
    json|error bundleId = body.id;
    test:assertFalse(bundleId is error, "Bundle must have an id");
}

// ============================================================
// 29. SEARCH: Identifier search with unknown domain returns empty
// ============================================================

@test:Config {groups: ["iti78", "search"]}
function testSearchByIdentifierUnknownDomain() returns error? {
    http:Response response = check testClient->get(
        "/Patient?identifier=urn:oid:9.9.9.9|UNKNOWN-VALUE",
        {"Authorization": string `Bearer ${adminToken}`}
    );

    // ITI-78 §2.3.78.4.3.3: Supplier may return 404 or 200 with empty Bundle
    // for unrecognized domains
    test:assertTrue(response.statusCode == 200 || response.statusCode == 404,
        "Unknown identifier domain should return 200 (empty) or 404");

    if response.statusCode == 200 {
        json body = check response.getJsonPayload();
        int total = check (check body.total).cloneWithType();
        test:assertEquals(total, 0, "Unknown domain should return 0 results");
    }
}

// ============================================================
// 30. SEARCH: Content-Type is JSON
// ============================================================

@test:Config {groups: ["iti78", "search"]}
function testSearchResponseContentType() returns error? {
    http:Response response = check testClient->get("/Patient?family=Smith", {
        "Authorization": string `Bearer ${adminToken}`
    });

    string contentType = response.getContentType();
    test:assertTrue(
        contentType.includes("json"),
        string `Response Content-Type must include 'json', got: ${contentType}`
    );
}

// ============================================================
// 31. SEARCH: Viewer role can also search (both admin + viewer allowed)
// ============================================================

@test:Config {groups: ["iti78", "auth"]}
function testSearchWithViewerRole() returns error? {
    http:Response response = check testClient->get("/Patient?family=Smith", {
        "Authorization": string `Bearer ${viewerToken}`
    });

    test:assertEquals(response.statusCode, 200,
        string `Viewer search must return 200, got ${response.statusCode}`);
}

// ============================================================
// 32. READ: Viewer role can read a patient
// ============================================================

@test:Config {groups: ["iti78", "auth"]}
function testReadWithViewerRole() returns error? {
    if createdPatientId == "" {
        test:assertFail("Setup failed: no patient ID available");
    }

    http:Response response = check testClient->get(
        string `/Patient/${createdPatientId}`,
        {"Authorization": string `Bearer ${viewerToken}`}
    );

    // Read is allowed for both admin + viewer
    test:assertEquals(response.statusCode, 200,
        "Viewer role should be able to read patients");
}

// ============================================================
// 33. SEARCH: Combined address parameter
// ============================================================

@test:Config {groups: ["iti78", "search", "params"]}
function testSearchByAddress() returns error? {
    http:Response response = check testClient->get("/Patient?address=Springfield", {
        "Authorization": string `Bearer ${adminToken}`
    });

    test:assertEquals(response.statusCode, 200, "Search by address must return 200 OK");

    json body = check response.getJsonPayload();
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Search by address 'Springfield' should find at least 1 patient");
}

// ============================================================
// 34. METADATA: Server exposes CapabilityStatement
// ============================================================

@test:Config {groups: ["iti78", "metadata"]}
function testMetadataEndpoint() returns error? {
    http:Response response = check testClient->get("/metadata");

    test:assertEquals(response.statusCode, 200, "Metadata must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "CapabilityStatement",
        "Metadata must return a CapabilityStatement");
    test:assertEquals(check body.fhirVersion, "4.0.1",
        "FHIR version must be 4.0.1 (R4)");
}

// ============================================================
// CLEANUP
// ============================================================

// @test:AfterSuite
// function cleanupTestPatients() returns error? {
//     // Soft-delete the test patients via the API
//     if createdPatientId != "" {
//         _ = check testClient->delete(
//             string `/Patient?identifier=urn:oid:1.2.3.4|ITI78-TEST-001`,
//             headers = {"Authorization": string `Bearer ${adminToken}`}
//         );
//     }
//     if createdPatientId2 != "" {
//         _ = check testClient->delete(
//             string `/Patient?identifier=urn:oid:1.2.3.4|ITI78-TEST-002`,
//             headers = {"Authorization": string `Bearer ${adminToken}`}
//         );
//     }
// }
