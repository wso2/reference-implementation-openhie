// ITI-119 Patient Demographics Query for Mobile — Match Operation Tests
// =====================================================================
// Tests the Patient Demographics Supplier actor against IHE ITI-119 requirements.
// Reference: https://profiles.ihe.net/ITI/PDQm/ITI-119.html
//
// Covers all 10 IHE PDQm §3.119 test scenarios:
//   1. Exactly one match, no optional parameters
//   2. Multiple matches, no optional parameters
//   3. One certain match with onlyCertainMatches=true
//   4. One non-certain match with onlyCertainMatches=true → empty Bundle
//   5. Multiple uncertain matches with onlyCertainMatches=true → empty Bundle
//   6. Multiple matches with count parameter (result limited)
//   7. No matching records → empty Bundle
//   8. Deprecated (inactive) patient record matched
//   9. Request processing error → 400 OperationOutcome
//  10. Missing parameter array → 400 OperationOutcome
//
// Plus: Bundle structure validation, auth, and response format tests.

import ballerina/http;
import ballerina/mime;
import ballerina/test;
import ballerina/io;

// ============================================================
// TEST CONFIGURATION
// ============================================================

// HTTP client targeting the FHIR service under test
final http:Client matchTestClient = check new ("http://localhost:9090/fhir/r4");

// Admin auth token (base64-encoded JSON: {"sub":"test-admin@test.com","role":"admin","exp":9999999999999})
final string matchAdminToken = getMatchAdminToken();

// Viewer auth token
final string matchViewerToken = getMatchViewerToken();

function getMatchAdminToken() returns string {
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

function getMatchViewerToken() returns string {
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
// HELPER: Build $match Parameters body
// ============================================================

// Build a minimal Parameters body with only the resource parameter.
function buildMatchParams(json patientResource) returns json {
    return {
        "resourceType": "Parameters",
        "parameter": [
            {
                "name": "resource",
                "resource": patientResource
            }
        ]
    };
}

// Build a Parameters body with resource + onlyCertainMatches.
function buildMatchParamsWithFlag(json patientResource, boolean onlyCertain) returns json {
    return {
        "resourceType": "Parameters",
        "parameter": [
            {
                "name": "resource",
                "resource": patientResource
            },
            {
                "name": "onlyCertainMatches",
                "valueBoolean": onlyCertain
            }
        ]
    };
}

// Build a Parameters body with resource + count.
function buildMatchParamsWithCount(json patientResource, int count) returns json {
    return {
        "resourceType": "Parameters",
        "parameter": [
            {
                "name": "resource",
                "resource": patientResource
            },
            {
                "name": "count",
                "valueInteger": count
            }
        ]
    };
}

// ============================================================
// TEST SETUP: Seed test patients
// ============================================================

@test:BeforeGroups {value: ["iti119"]}
function setupMatchTestPatients() returns error? {
    // Patient 1 — CERTAIN match target
    // Full Sri Lankan demographics: NIC + MR identifiers, complete name, phone, address.
    json certain = {
        "resourceType": "Patient",
        "extension": [
            {
                "url": "http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName",
                "valueString": "Perera"
            }
        ],
        "identifier": [
            {"system": "http://kaluthara-regional.moh.lk/mr", "use": "official", "value": "CR-TEST-CERT-001"},
            {"system": "http://moh.gov.lk/nic", "use": "official", "value": "200012345678"}
        ],
        "name": [{"use": "official", "family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15",
        "telecom": [
            {"system": "phone", "value": "+94771234567", "use": "mobile"},
            {"system": "email", "value": "maria.silva@example.com"}
        ],
        "address": [
            {
                "use": "home",
                "line": ["45 Galle Road"],
                "city": "Colombo",
                "district": "Western",
                "postalCode": "00300",
                "country": "LK"
            }
        ],
        "active": true
    };
    http:Response _ = check matchTestClient->put(
        "/Patient?identifier=http://moh.gov.lk/nic|200012345678",
        certain,
        {"Authorization": string `Bearer ${matchAdminToken}`, "Content-Type": "application/fhir+json"}
    );

    // Patient 2 — PARTIAL match (same family+DOB+gender, different given name)
    // Should score as possible/probable, not certain.
    json partial = {
        "resourceType": "Patient",
        "identifier": [
            {"system": "http://kaluthara-regional.moh.lk/mr", "use": "official", "value": "CR-TEST-PART-001"},
            {"system": "http://moh.gov.lk/nic", "use": "official", "value": "200098765432"}
        ],
        "name": [{"use": "official", "family": "Silva", "given": ["Marie"]}],
        "gender": "female",
        "birthDate": "2000-06-15",
        "active": true
    };
    http:Response _ = check matchTestClient->put(
        "/Patient?identifier=http://moh.gov.lk/nic|200098765432",
        partial,
        {"Authorization": string `Bearer ${matchAdminToken}`, "Content-Type": "application/fhir+json"}
    );

    // Patient 3 — UNRELATED (completely different demographics)
    json unrelated = {
        "resourceType": "Patient",
        "identifier": [
            {"system": "http://moh.gov.lk/nic", "use": "official", "value": "197005101234"}
        ],
        "name": [{"use": "official", "family": "Fernando", "given": ["Priya", "Kumari"]}],
        "gender": "female",
        "birthDate": "1970-05-10",
        "address": [{"city": "Kandy", "country": "LK"}],
        "active": true
    };
    http:Response _ = check matchTestClient->put(
        "/Patient?identifier=http://moh.gov.lk/nic|197005101234",
        unrelated,
        {"Authorization": string `Bearer ${matchAdminToken}`, "Content-Type": "application/fhir+json"}
    );

    // Patient 4 — INACTIVE (deprecated record)
    json inactive = {
        "resourceType": "Patient",
        "identifier": [
            {"system": "http://moh.gov.lk/nic", "use": "official", "value": "196006151234"}
        ],
        "name": [{"use": "official", "family": "Deprecated", "given": ["Record"]}],
        "gender": "male",
        "birthDate": "1960-06-15",
        "active": false
    };
    http:Response _ = check matchTestClient->put(
        "/Patient?identifier=http://moh.gov.lk/nic|196006151234",
        inactive,
        {"Authorization": string `Bearer ${matchAdminToken}`, "Content-Type": "application/fhir+json"}
    );
}

// ============================================================
// BUNDLE STRUCTURE TESTS
// ============================================================

// 1. POST $match returns 200 OK with a Bundle resource
@test:Config {groups: ["iti119", "structure"]}
function testMatchReturnsBundle() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200, "$match must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle", "Response must be a Bundle");
}

// 2. $match Bundle type must be "searchset" (PDQm Match Output Bundle Profile)
@test:Config {groups: ["iti119", "structure"], dependsOn: [testMatchReturnsBundle]}
function testMatchBundleTypeIsSearchset() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    json body = check response.getJsonPayload();
    test:assertEquals(check body.'type, "searchset", "Bundle type must be 'searchset'");
}

// 3. $match Bundle must include "total" field
@test:Config {groups: ["iti119", "structure"], dependsOn: [testMatchReturnsBundle]}
function testMatchBundleHasTotal() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    json body = check response.getJsonPayload();
    json|error total = body.total;
    test:assertFalse(total is error, "Bundle must include 'total' field");
}

// 4. $match Bundle entries must have search.score (0-1 match confidence)
@test:Config {groups: ["iti119", "structure"]}
function testMatchEntriesHaveSearchScore() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    json body = check response.getJsonPayload();
    json|error entries = body.entry;

    if entries is json[] && entries.length() > 0 {
        json firstEntry = entries[0];
        json|error score = firstEntry.search.score;
        test:assertFalse(score is error, "Each entry must have search.score");
        if score is json {
            float scoreVal = check score.cloneWithType();
            test:assertTrue(scoreVal >= 0.0 && scoreVal <= 1.0,
                string `search.score must be between 0 and 1, got: ${scoreVal}`);
        }
    }
}

// 5. $match Bundle entries must have search.mode = "match"
@test:Config {groups: ["iti119", "structure"]}
function testMatchEntriesHaveSearchMode() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    json body = check response.getJsonPayload();
    json|error entries = body.entry;

    if entries is json[] && entries.length() > 0 {
        json firstEntry = entries[0];
        json|error mode = firstEntry.search.mode;
        test:assertFalse(mode is error, "Each entry must have search.mode");
        if mode is json {
            test:assertEquals(mode.toString(), "match", "search.mode must be 'match'");
        }
    }
}

// 6. $match response Content-Type must be JSON
@test:Config {groups: ["iti119", "structure"]}
function testMatchResponseContentType() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}]
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    string contentType = response.getContentType();
    test:assertTrue(contentType.includes("json"),
        string `Content-Type must include 'json', got: ${contentType}`);
}

// ============================================================
// ITI-119 SPEC TEST CASES
// ============================================================

// Case 1 (§3.119): Exactly one match — no optional parameters
// Input: high-specificity demographics (NIC identifier + full name + all fields) matching exactly one patient.
// Expected: 200 OK, Bundle with at least 1 entry, top entry has score=1.0 (certain match).
// Note: lower-confidence candidates may also appear in the Bundle above the threshold;
//       the assertion verifies the certain match is present as the top result.
@test:Config {groups: ["iti119", "match"]}
function testMatchCase1ExactlyOneMatch() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15",
        "telecom": [{"system": "phone", "value": "+94771234567"}],
        "address": [{"postalCode": "00300", "country": "LK"}]
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200, "Exact match must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "Exact NIC identifier+demographics match must return at least 1 result");

    // Verify the top entry is the certain match with score 1.0
    json|error entries = body.entry;
    if entries is json[] && entries.length() >= 1 {
        json firstEntry = entries[0];
        json|error score = firstEntry.search.score;
        if score is json {
            decimal scoreVal = check score.cloneWithType();
            test:assertEquals(scoreVal, 1.0d,
                "Top match for full NIC+demographics query must have score 1.0");
        }
        json|error 'resource = firstEntry.'resource;
        if 'resource is json {
            test:assertEquals(check 'resource.resourceType, "Patient",
                "Top entry must be a Patient resource");
        }
    }
}

// Case 2 (§3.119): Multiple matches ordered by likelihood — no optional parameters
// Input: shared family name + dob without unique identifier (matches CERT and PART patients).
// Expected: 200 OK, Bundle with total≥2, entries ordered by descending score.
@test:Config {groups: ["iti119", "match"]}
function testMatchCase2MultipleMatchesOrderedByScore() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "name": [{"family": "Silva"}],
        "birthDate": "2000-06-15",
        "gender": "female"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200, "Multiple-match request must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 2,
        string `family=Silva + DOB should match ≥2 patients, got ${total}`);

    // Verify entries are in descending score order
    json|error entries = body.entry;
    if entries is json[] && entries.length() >= 2 {
        float prev = 1.0;
        foreach json entry in entries {
            json|error scoreJson = entry.search.score;
            if scoreJson is json {
                float score = check scoreJson.cloneWithType();
                test:assertTrue(score <= prev,
                    string `Entries must be ordered by descending score, prev=${prev} current=${score}`);
                prev = score;
            }
        }
    }
}

// Case 3 (§3.119): One certain match with onlyCertainMatches=true
// Input: exact all-field match + onlyCertainMatches=true.
// Expected: 200 OK, Bundle with exactly 1 entry of grade "certain".
@test:Config {groups: ["iti119", "match"]}
function testMatchCase3OneCertainMatchWithFlag() returns error? {
    json params = buildMatchParamsWithFlag({
        "resourceType": "Patient",
        "extension": [
            {
                "url": "http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName",
                "valueString": "Perera"
            }
        ],
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15",
        "telecom": [{"system": "phone", "value": "+94771234567", "use": "mobile"}],
        "address": [
            {
                "line": ["45 Galle Road"],
                "city": "Colombo",
                "district": "Western",
                "postalCode": "00300",
                "country": "LK"
            }
        ]
    }, true);

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200,
        "onlyCertainMatches=true with one certain match must return 200");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
    int total = check (check body.total).cloneWithType();
    test:assertEquals(total, 1, "Must return exactly 1 certain match");

    // Verify the entry exists and is a Patient
    json|error entries = body.entry;
    if entries is json[] && entries.length() == 1 {
        json entry = entries[0];
        json|error 'resource = entry.'resource;
        if 'resource is json {
            test:assertEquals(check 'resource.resourceType, "Patient",
                "Entry resource must be a Patient");
        }
    }
}

// Case 4 (§3.119): One non-certain match with onlyCertainMatches=true → empty Bundle
// Input: low-confidence partial demographics + onlyCertainMatches=true.
// Expected: 200 OK, Bundle with total=0.
@test:Config {groups: ["iti119", "match"]}
function testMatchCase4NonCertainMatchWithFlag() returns error? {
    // PART patient has family=Silva + DOB but given=Marie (not Maria) — scores possible, not certain
    json params = buildMatchParamsWithFlag({
        "resourceType": "Patient",
        "name": [{"family": "Silva", "given": ["Marie"]}],
        "birthDate": "2000-06-15",
        "gender": "female"
    }, true);

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    // Per ITI-119: if no certain matches exist and onlyCertainMatches=true → empty Bundle
    test:assertEquals(response.statusCode, 200,
        "onlyCertainMatches=true with no certain match must return 200 (empty Bundle)");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
    int total = check (check body.total).cloneWithType();
    test:assertEquals(total, 0,
        "Non-certain matches filtered by onlyCertainMatches=true must return empty Bundle");
}

// Case 5 (§3.119): Multiple uncertain matches with onlyCertainMatches=true → empty Bundle
// Input: partial demographics matching multiple records (none certain) + onlyCertainMatches=true.
// Expected: 200 OK, empty Bundle.
@test:Config {groups: ["iti119", "match"]}
function testMatchCase5MultipleUncertainWithFlag() returns error? {
    // Query by family only — matches multiple Silva patients but none with certainty
    json params = buildMatchParamsWithFlag({
        "resourceType": "Patient",
        "name": [{"family": "Silva"}]
    }, true);

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200,
        "Multiple uncertain matches + onlyCertainMatches=true must return 200");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
    int total = check (check body.total).cloneWithType();
    test:assertEquals(total, 0,
        "Multiple uncertain matches with flag must return empty Bundle");
}

// Case 6 (§3.119): count parameter limits the number of results
// Input: broad match (family=Silva + DOB) with count=1.
// Expected: 200 OK, Bundle with at most 1 entry.
@test:Config {groups: ["iti119", "match"]}
function testMatchCase6CountLimitsResults() returns error? {
    json params = buildMatchParamsWithCount({
        "resourceType": "Patient",
        "name": [{"family": "Silva"}],
        "birthDate": "2000-06-15",
        "gender": "female"
    }, 1);

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200, "count parameter request must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total <= 1, string `count=1 must limit results to at most 1, got ${total}`);
}

// Case 7 (§3.119): No matching records → 200 OK with empty Bundle
// Input: completely fictional demographics that cannot match any stored patient.
// Expected: 200 OK, Bundle with total=0.
@test:Config {groups: ["iti119", "match"]}
function testMatchCase7NoMatchingRecords() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "urn:oid:9.9.9.9", "value": "NONEXISTENT-XYZ-99999"}],
        "name": [{"family": "ZZZNOMATCH", "given": ["ZZZNOMATCH"]}],
        "gender": "other",
        "birthDate": "1111-01-01"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200, "No-match $match must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
    int total = check (check body.total).cloneWithType();
    test:assertEquals(total, 0, "No matching records must return total=0 empty Bundle");
}

// Case 8 (§3.119): Deprecated (inactive) patient record matched
// Input: exact match on inactive patient's NIC identifier.
// Expected: 200 OK. The Bundle may contain the inactive record or omit it per policy.
//           The service must not error — this is a policy decision, not a failure.
@test:Config {groups: ["iti119", "match"]}
function testMatchCase8InactivePatientHandled() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "196006151234"}],
        "name": [{"family": "Deprecated", "given": ["Record"]}],
        "gender": "male",
        "birthDate": "1960-06-15"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    // ITI-119: service must return 200 — inactive patient handling is implementation policy
    test:assertEquals(response.statusCode, 200,
        "Matching a deprecated patient record must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle",
        "Response for deprecated patient match must be a Bundle");

    // Verify any returned inactive patient has active=false
    json|error entries = body.entry;
    if entries is json[] {
        foreach json entry in entries {
            json|error 'resource = entry.'resource;
            if 'resource is json {
                json|error active = 'resource.active;
                if active is json {
                    // If the inactive patient is included, active must be false
                    boolean activeVal = check active.cloneWithType();
                    test:assertFalse(activeVal,
                        "Matched inactive patient entry must have active=false");
                }
            }
        }
    }
}

// Case 9 (§3.119): Missing "resource" parameter → 400 Bad Request + OperationOutcome
// Input: Parameters body present but no "resource" parameter inside.
// Expected: 400 Bad Request with OperationOutcome.
@test:Config {groups: ["iti119", "match", "errors"]}
function testMatchCase9MissingResourceParam() returns error? {
    json params = {
        "resourceType": "Parameters",
        "parameter": [
            {"name": "count", "valueInteger": 5}
        ]
    };

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 400,
        "Missing 'resource' parameter must return 400 Bad Request");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "OperationOutcome",
        "Error response must be an OperationOutcome");
}

// Case 10 (§3.119): Invalid/empty body → 400 Bad Request + OperationOutcome
// Input: Parameters body with empty parameter array.
// Expected: 400 Bad Request with OperationOutcome.
@test:Config {groups: ["iti119", "match", "errors"]}
function testMatchCase10MissingParamArray() returns error? {
    json params = {
        "resourceType": "Parameters",
        "parameter": []
    };

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    // A Parameters body with no parameters still has the array — service should return
    // 400 because the required "resource" parameter is absent.
    test:assertEquals(response.statusCode, 400,
        "Parameters with no 'resource' must return 400 Bad Request");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "OperationOutcome",
        "Error response must be an OperationOutcome");
}

// ============================================================
// PARAMETER TESTS
// ============================================================

// count parameter accepted — response is a valid Bundle
@test:Config {groups: ["iti119", "params"]}
function testMatchWithCountParam() returns error? {
    json params = buildMatchParamsWithCount({
        "resourceType": "Patient",
        "name": [{"family": "Silva"}]
    }, 5);

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200, "count param request must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
}

// onlyCertainMatches=false behaves identically to the default (no filtering)
@test:Config {groups: ["iti119", "params"]}
function testMatchWithOnlyCertainMatchesFalse() returns error? {
    json params = buildMatchParamsWithFlag({
        "resourceType": "Patient",
        "name": [{"family": "Silva"}],
        "birthDate": "2000-06-15",
        "gender": "female"
    }, false);

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200, "onlyCertainMatches=false must return 200 OK");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");

    // Should return the same results as without the flag (no filtering applied)
    int total = check (check body.total).cloneWithType();
    test:assertTrue(total >= 1, "onlyCertainMatches=false should not filter out probable matches");
}

// ============================================================
// AUTHENTICATION & AUTHORIZATION TESTS
// ============================================================

// Invalid token → 401 Unauthorized
@test:Config {groups: ["iti119", "auth"]}
function testMatchRequiresAuth() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "name": [{"family": "Silva"}]
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": "Bearer invalidtoken_iti119_test",
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 401,
        "Invalid token must return 401 Unauthorized");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "OperationOutcome",
        "Auth error must return OperationOutcome");
}

// Viewer role allowed for $match (ITI-119 is read-only: admin + viewer permitted)
@test:Config {groups: ["iti119", "auth"]}
function testMatchAllowsViewerRole() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchViewerToken}`,
        "Content-Type": "application/fhir+json"
    });

    // Per main.bal:52 — $match allows ROLE_ADMIN and ROLE_VIEWER
    test:assertEquals(response.statusCode, 200,
        "Viewer role must be permitted to call $match (read-only operation)");

    json body = check response.getJsonPayload();
    test:assertEquals(check body.resourceType, "Bundle");
}

// Admin role can call $match
@test:Config {groups: ["iti119", "auth"]}
function testMatchAdminCanMatch() returns error? {
    json params = buildMatchParams({
        "resourceType": "Patient",
        "identifier": [{"system": "http://moh.gov.lk/nic", "value": "200012345678"}],
        "name": [{"family": "Silva", "given": ["Maria", "Fernanda"]}],
        "gender": "female",
        "birthDate": "2000-06-15"
    });

    http:Response response = check matchTestClient->post("/Patient/$match", params, {
        "Authorization": string `Bearer ${matchAdminToken}`,
        "Content-Type": "application/fhir+json"
    });

    test:assertEquals(response.statusCode, 200, "Admin role must be permitted to call $match");
}
