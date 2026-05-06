// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0

// Database Repository for PDQmPatient Storage (H2 / PostgreSQL)
// ==============================================================
// Stores full PDQmPatient FHIR resources in a pluggable SQL database.
// Set dbType = "h2" (default) or "postgresql" in Config.toml to switch.

import ballerina/sql;
import ballerina/time;
import ballerina/uuid;
import ballerinax/java.jdbc;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.ihe.pdqm320 as pdqm;
import ballerina/log;
import healthcare_samples/client_registry.handlers;

// ============================================================
// DATABASE CONFIGURATION
// ============================================================

configurable string dbUrl = ?;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbType = "h2";

// Database provider — selected via factory based on dbType
final handlers:DatabaseProvider dbProvider = check handlers:getDatabaseProvider(dbType);

// Database client - initialized on module load
final jdbc:Client dbClient = check new (
    url = dbUrl,
    user = dbUser,
    password = dbPassword,
    connectionPool = {
        maxOpenConnections: 10,
        minIdleConnections: 2
    }
);

// ============================================================
// DATABASE ROW TYPES
// ============================================================

// Patient table row
type PatientRow record {|
    string id;
    string resource_json;
    boolean active;
    string? family_name;
    string? given_name;
    string? gender;
    string? birth_date;
    string? phone;
    string? email;
    string? city;
    string? state;
    string? postal_code;
    string? country;
    string created_at;
    string updated_at;
    int 'version;
    string? blocking_keys_at;
|};

// Identifier table row
type IdentifierRow record {|
    int? row_id;
    string patient_id;
    string system;
    string value;
|};

// Blocking key table row
type BlockingKeyRow record {|
    int? row_id;
    string patient_id;
    string block_type;
    string block_value;
|};

// ============================================================
// ERROR TYPES
// ============================================================

public type PatientNotFoundError distinct error;
public type DuplicatePatientError distinct error;
public type InvalidPatientError distinct error;
public type ConcurrencyError distinct error;

// ============================================================
// DATABASE INITIALIZATION
// ============================================================

# Initialize database schema using the active database provider.
# + return - error if database initialization fails
public function initDatabase() returns error? {
    check dbProvider.initSchema(dbClient);
}

// ============================================================
// CREATE PATIENT
// ============================================================

# Create a new patient in database
# 
# + patient - PDQmPatient resource to store
# + return - Created patient with assigned ID or error
public isolated function createPatient(pdqm:PDQmPatient patient) 
        returns pdqm:PDQmPatient|InvalidPatientError|DuplicatePatientError|error {
    

    
    // Validate: identifier is required
    if patient.identifier.length() == 0 {
        return error InvalidPatientError("Patient.identifier is required in the Patient resource(min 1)");
    }
    
    // Pre-declare for use after the transaction block
    string patientId = "";
    pdqm:PDQmPatient newPatient = patient;

    transaction {
        // Check if any identifier already belongs to an existing (active or deleted) patient
        foreach pdqm:PDQmPatientIdentifier id in patient.identifier {
            IdentifierRow|sql:Error idRow = dbClient->queryRow(
                `SELECT * FROM identifiers WHERE system = ${id.system} AND "value" = ${id.value}`
            );
            if idRow is IdentifierRow {
                // Identifier exists — check if the owning patient is soft-deleted
                PatientRow|sql:Error ownerRow = dbClient->queryRow(
                    `SELECT * FROM patients WHERE id = ${idRow.patient_id}`
                );
                if ownerRow is PatientRow {
                    if !ownerRow.active {
                        fail error DuplicatePatientError(
                            string `Cannot create patient: identifier ${id.system}|${id.value} belongs to a deleted patient (ID: ${idRow.patient_id}). Consider reactivating the existing patient instead.`);
                    } else {
                        fail error DuplicatePatientError(
                            string `Cannot create patient: identifier ${id.system}|${id.value} already exists for active patient (ID: ${idRow.patient_id}).`);
                    }
                }
            }
        }

        // Generate ID
        patientId = uuid:createType4AsString();
        string now = time:utcToString(time:utcNow());

        // Add CR identifier
        newPatient = check addCRIdentifier(patient, patientId);
        newPatient.id = patientId;

        if newPatient.active is () {
            newPatient.active = true;
        }

        // Extract search fields
        string? familyName = getFamily(newPatient);
        string? givenName = getGiven(newPatient);
        string? phone = getTelecom(newPatient, "phone");
        string? email = getTelecom(newPatient, "email");
        string? city = getAddressField(newPatient, "city");
        string? state = getAddressField(newPatient, "state");
        string? postalCode = getAddressField(newPatient, "postalCode");
        string? country = getAddressField(newPatient, "country");

        // Ensure meta is properly serialized as JSON
        json resourceJsonObj = newPatient.toJson();
        json metaJson = {
            "versionId": "1",
            "lastUpdated": now
        };
        map<json> createMap = <map<json>>resourceJsonObj;
        createMap["meta"] = metaJson;
        resourceJsonObj = createMap;
        string resourceJson = resourceJsonObj.toJsonString();

        // Insert patient
        _ = check dbClient->execute(`
            INSERT INTO patients (id, resource_json, active, family_name, given_name,
                gender, birth_date, phone, email, city, state, postal_code, country,
                created_at, updated_at, version)
            VALUES (${patientId}, ${resourceJson}, ${newPatient.active ?: true},
                ${familyName}, ${givenName}, ${newPatient.gender}, ${newPatient.birthDate},
                ${phone}, ${email}, ${city}, ${state}, ${postalCode}, ${country}, ${now}, ${now}, 1)
        `);

        // Insert identifiers
        foreach pdqm:PDQmPatientIdentifier id in newPatient.identifier {
            _ = check dbClient->execute(`
                INSERT INTO identifiers (patient_id, system, "value")
                VALUES (${patientId}, ${id.system}, ${id.value})
            `);
        }

        check commit;
    } on fail error e {
        return e;
    }

    // Compute and store blocking keys for fast matching (non-fatal; runs after commit)
    if blocking.enabled {
        error? bkResult = storeBlockingKeys(patientId, newPatient);
        if bkResult is error {
            log:printError(string `Failed to store blocking keys for new patient ${patientId}`, bkResult);
        }
    }

    return newPatient;
}

// ============================================================
// READ PATIENT
// ============================================================

# Get patient by ID
# 
# + id - Patient ID
# + return - PDQmPatient or error
public isolated function getPatientById(string id) 
        returns pdqm:PDQmPatient|PatientNotFoundError|error {
    
    PatientRow|sql:Error row = dbClient->queryRow(
        `SELECT * FROM patients WHERE id = ${id}`
    );
    
    if row is sql:NoRowsError {
        return error PatientNotFoundError(string `Patient ${id} not found`);
    }
    if row is sql:Error {
        return row;
    }
    
    return check parsePatient(row.resource_json);
}

# Get patient by identifier
# 
# + system - Identifier system URI
# + value - Identifier value
# + return - PDQmPatient or nil if not found
public isolated function getPatientByIdentifier(string system, string value) 
        returns pdqm:PDQmPatient|error? {
    
    IdentifierRow|sql:Error idRow = dbClient->queryRow(
        `SELECT * FROM identifiers WHERE system = ${system} AND "value" = ${value}`
    );
    
    if idRow is sql:NoRowsError {
        return ();
    }
    if idRow is sql:Error {
        return idRow;
    }
    
    pdqm:PDQmPatient|PatientNotFoundError|error result = getPatientById(idRow.patient_id);
    if result is PatientNotFoundError {
        return ();
    }
    return result;
}

// ============================================================
// UPDATE PATIENT
// ============================================================

# Update patient by CRUID
# 
# + id - CRUID Patient 
# + patient - Updated patient data
# + return - Updated patient or error
public isolated function updatePatient(string id, pdqm:PDQmPatient patient)
        returns pdqm:PDQmPatient|PatientNotFoundError|DuplicatePatientError|InvalidPatientError|ConcurrencyError|error {

    // Validate identifier (pure check, no DB read — safe outside transaction)
    if patient.identifier.length() == 0 {
        return error InvalidPatientError("Patient.identifier is required (min 1)");
    }

    // Populated inside the transaction; used for post-commit work and return value.
    json resourceJsonObj = {};

    transaction {
        // Read inside the transaction so the version we act on is consistent with the UPDATE.
        PatientRow|sql:Error existingRow = dbClient->queryRow(
            `SELECT * FROM patients WHERE id = ${id}`
        );
        if existingRow is sql:NoRowsError {
            fail error PatientNotFoundError(string `Patient ${id} not found`);
        }
        if existingRow is sql:Error {
            fail existingRow;
        }

        string now = time:utcToString(time:utcNow());
        int newVersion = existingRow.'version + 1;

        // Parse existing patient from DB and merge with incoming payload
        pdqm:PDQmPatient existingPatient = check parsePatient(existingRow.resource_json);
        pdqm:PDQmPatient updatedPatient = check mergePatientFields(existingPatient, patient);
        updatedPatient.id = id;

        // Check merged identifiers don't conflict with other patients
        foreach pdqm:PDQmPatientIdentifier mergedId in updatedPatient.identifier {
            IdentifierRow|sql:Error idRow = dbClient->queryRow(
                `SELECT * FROM identifiers
                 WHERE system = ${mergedId.system} AND "value" = ${mergedId.value} AND patient_id != ${id}`
            );
            if idRow is IdentifierRow {
                fail error DuplicatePatientError(
                    string `Identifier ${mergedId.system}|${mergedId.value} belongs to another patient`);
            }
        }

        // Check if CR identifier exists; if not, add it
        boolean hasCRIdentifier = false;
        foreach pdqm:PDQmPatientIdentifier crid in updatedPatient.identifier {
            if crid.system == baseUrl {
                hasCRIdentifier = true;
                break;
            }
        }
        if !hasCRIdentifier {
            updatedPatient = check addCRIdentifier(updatedPatient, id);
        }

        // Build resource JSON with updated meta
        map<json> resourceMap = <map<json>>updatedPatient.toJson();
        resourceMap["meta"] = {"versionId": newVersion.toString(), "lastUpdated": now};
        resourceJsonObj = resourceMap;
        string resourceJson = resourceJsonObj.toJsonString();

        // Extract search fields
        string? familyName = getFamily(updatedPatient);
        string? givenName = getGiven(updatedPatient);
        string? phone = getTelecom(updatedPatient, "phone");
        string? email = getTelecom(updatedPatient, "email");
        string? city = getAddressField(updatedPatient, "city");
        string? state = getAddressField(updatedPatient, "state");
        string? postalCode = getAddressField(updatedPatient, "postalCode");
        string? country = getAddressField(updatedPatient, "country");

        // Version-pinned UPDATE: only succeeds when no concurrent modification has occurred.
        sql:ExecutionResult updateResult = check dbClient->execute(`
            UPDATE patients SET
                resource_json = ${resourceJson},
                active = ${updatedPatient.active ?: true},
                family_name = ${familyName},
                given_name = ${givenName},
                gender = ${updatedPatient.gender},
                birth_date = ${updatedPatient.birthDate},
                phone = ${phone},
                email = ${email},
                city = ${city},
                state = ${state},
                postal_code = ${postalCode},
                country = ${country},
                updated_at = ${now},
                version = ${newVersion}
            WHERE id = ${id} AND version = ${existingRow.'version}
        `);
        if updateResult.affectedRowCount != 1 {
            fail error ConcurrencyError(
                string `Patient ${id} was modified concurrently; please re-fetch and retry`);
        }

        // Replace identifiers atomically with the update
        _ = check dbClient->execute(`DELETE FROM identifiers WHERE patient_id = ${id}`);
        foreach pdqm:PDQmPatientIdentifier identifier in updatedPatient.identifier {
            _ = check dbClient->execute(`
                INSERT INTO identifiers (patient_id, system, "value")
                VALUES (${id}, ${identifier.system}, ${identifier.value})
            `);
        }

        check commit;
    } on fail error e {
        return e;
    }

    // Recompute blocking keys and invalidate compared pairs (non-fatal; runs after commit)
    if blocking.enabled {
        sql:ExecutionResult|sql:Error delResult = dbClient->execute(
            `DELETE FROM dedup_compared_pairs WHERE patient_id_1 = ${id} OR patient_id_2 = ${id}`
        );
        if delResult is sql:Error {
            log:printError(string `Failed to invalidate dedup_compared_pairs for patient ${id}`, delResult);
        }
        pdqm:PDQmPatient|error updatedParsed = resourceJsonObj.cloneWithType(pdqm:PDQmPatient);
        if updatedParsed is pdqm:PDQmPatient {
            error? bkResult = storeBlockingKeys(id, updatedParsed);
            if bkResult is error {
                log:printError(string `Failed to store blocking keys for updated patient ${id}`, bkResult);
            }
        }
    }

    return resourceJsonObj.cloneWithType(pdqm:PDQmPatient);
}

// ============================================================
// DELETE PATIENT (Soft Delete)
// ============================================================

# Soft delete patient (sets active=false)
# 
# + id - Patient ID
# + return - true if deleted or error
public isolated function deletePatient(string id) 
        returns boolean|PatientNotFoundError|error {
    
    PatientRow|sql:Error existingRow = dbClient->queryRow(
        `SELECT * FROM patients WHERE id = ${id}`
    );
    
    if existingRow is sql:NoRowsError {
        return error PatientNotFoundError(string `Patient ${id} not found`);
    }
    if existingRow is sql:Error {
        log:printError("Delete patient error", existingRow);
        return existingRow;
    }
    
    string now = time:utcToString(time:utcNow());
    int newVersion = existingRow.'version + 1;
    
    // Update JSON to set active=false
    pdqm:PDQmPatient|error patient = parsePatient(existingRow.resource_json);
    if patient is error {
        log:printError("Delete patient error", patient);
        return patient;
    }
    patient.active = false;
    patient.meta = {versionId: newVersion.toString(), lastUpdated: now};
    
    _ = check dbClient->execute(`
        UPDATE patients SET 
            resource_json = ${patient.toJsonString()},
            active = false,
            updated_at = ${now},
            version = ${newVersion}
        WHERE id = ${id}
    `);
    
    return true;
}

// ============================================================
// RESOLVE DUPLICATE PATIENT (ITI-104 §2.3.104.4.2)
// ============================================================

# Resolve a duplicate patient by marking it inactive with a replaced-by link.
#
# + subsumedId - CRUID of the patient being subsumed (duplicate)
# + patient - The updated Patient resource (active=false, link with replaced-by)
# + return - Updated patient or error
public isolated function resolvePatient(string subsumedId, pdqm:PDQmPatient patient)
        returns pdqm:PDQmPatient|PatientNotFoundError|ConcurrencyError|error {

    json resourceJsonObj = {};

    transaction {
        PatientRow|sql:Error existingRow = dbClient->queryRow(
            `SELECT * FROM patients WHERE id = ${subsumedId}`
        );
        if existingRow is sql:NoRowsError {
            fail error PatientNotFoundError(string `Patient ${subsumedId} not found`);
        }
        if existingRow is sql:Error {
            fail existingRow;
        }

        string now = time:utcToString(time:utcNow());
        int newVersion = existingRow.'version + 1;

        pdqm:PDQmPatient resolvedPatient = patient.clone();
        resolvedPatient.id = subsumedId;
        resolvedPatient.active = false;

        json|error j = resolvedPatient.toJson();
        if j is error {
            fail j;
        }
        map<json> resolveMap = <map<json>>j;
        resolveMap["meta"] = {"versionId": newVersion.toString(), "lastUpdated": now};
        resourceJsonObj = resolveMap;
        string resourceJson = resourceJsonObj.toJsonString();

        sql:ExecutionResult updateResult = check dbClient->execute(`
            UPDATE patients SET
                resource_json = ${resourceJson},
                active = false,
                updated_at = ${now},
                version = ${newVersion}
            WHERE id = ${subsumedId} AND version = ${existingRow.'version}
        `);
        if updateResult.affectedRowCount != 1 {
            fail error ConcurrencyError(
                string `Patient ${subsumedId} was modified concurrently; please re-fetch and retry`);
        }

        check commit;
    } on fail error e {
        return e;
    }

    return resourceJsonObj.cloneWithType(pdqm:PDQmPatient);
}

// ============================================================
// HELPER: EXTRACT IDENTIFIERS FROM PATIENT JSON
// ============================================================

# Extract all (system, value) identifier pairs from a raw FHIR Patient JSON.
# Returns an empty array if the identifier field is absent or malformed.
# + patientJson - Raw FHIR Patient resource as JSON
# + return - Array of [system, value] tuples
isolated function extractIdentifiers(map<json> patientJson) returns [string, string][] {
    [string, string][] result = [];
    json? identifiers = patientJson["identifier"];
    if identifiers == () {
        return result;
    }
    if identifiers is json[] {
        foreach json id in identifiers {
            json|error sys = id.system;
            json|error val = id.'value;
            if sys is string && val is string {
                result.push([sys, val]);
            }
        }
    }
    return result;
}

// ============================================================
// SEARCH PATIENTS (ITI-78)
// ============================================================

# Search patients by criteria
#
# + identifier - Identifier in "system|value" format
# + family - Family name (partial match)
# + given - Given name (partial match)
# + gender - Gender code
# + birthdate - Birth date (YYYY-MM-DD)
# + telecom - Telecom value (searches phone and email)
# + address - General address search (searches city, state, postal code, country)
# + city - City (partial match)
# + state - State
# + postalCode - Postal code
# + country - Country
# + mothersMaidenName - Mother's maiden name (FHIR extension)
# + active - Active status
# + count - Max results (default 100)
# + offset - Pagination offset
# + patientJson - Optional full FHIR Patient JSON for fallback identifier search
# + return - Array of matching patients
public isolated function searchPatients(
    string? identifier = (),
    string? family = (),
    string? given = (),
    string? gender = (),
    string? birthdate = (),
    string? telecom = (),
    string? address = (),
    string? city = (),
    string? state = (),
    string? postalCode = (),
    string? country = (),
    string? mothersMaidenName = (),
    boolean? active = true,
    int count = 100,
    int offset = 0,
    map<json>? patientJson = ()
) returns pdqm:PDQmPatient[]|error {
    
    // Step 1: If identifier is available, search by identifier first
    boolean identifierProvided = identifier is string;
    if identifier is string {
        int? pipeIdx = identifier.indexOf("|");
        if pipeIdx is int {
            string sys = identifier.substring(0, pipeIdx);
            string val = identifier.substring(pipeIdx + 1);
            //remove Patient/ from the value if it exists
            if val.startsWith("Patient/") { 
                val = val.substring(8);
            }
            
            if sys == baseUrl{
                log:printInfo(string `Searching for patients with identifier system=${sys} and value=${val}`);
                pdqm:PDQmPatient|PatientNotFoundError|error directResult = getPatientById(val);
                if directResult is pdqm:PDQmPatient {
                    return [directResult];
                }
                if directResult is PatientNotFoundError {
                    // Not found — fall through to demographic search
                } else {
                    return directResult;
                }
            }
            sql:ParameterizedQuery identifierQuery = `
                SELECT p.* FROM patients p
                INNER JOIN identifiers i ON p.id = i.patient_id
                WHERE i.system = ${sys} AND i."value" = ${val}
            `;
            
            if active is boolean {
                identifierQuery = sql:queryConcat(identifierQuery, ` AND p.active = ${active}`);
            }
            
            identifierQuery = sql:queryConcat(identifierQuery, ` ORDER BY p.updated_at DESC LIMIT ${count} OFFSET ${offset}`);
            
            stream<PatientRow, sql:Error?> identifierRowStream = dbClient->query(identifierQuery);
            
            pdqm:PDQmPatient[] identifierResults = [];
            check from PatientRow row in identifierRowStream
                do {
                    pdqm:PDQmPatient|error patient = parsePatient(row.resource_json);
                    if patient is pdqm:PDQmPatient {
                        identifierResults.push(patient);
                    }
                };

            if identifierResults.length() > 0 {
                return identifierResults;
            }

            // Step 1b: Try each other identifier from the patient resource one by one
            if patientJson is map<json> {
                [string, string][] allIdentifiers = extractIdentifiers(patientJson);
                foreach [string, string] idPair in allIdentifiers {
                    string otherSys = idPair[0];
                    string otherVal = idPair[1];

                    // Skip the identifier already searched in Step 1
                    if otherSys == sys && otherVal == val {
                        continue;
                    }

                    // Special case: CR base-URL identifier → direct ID lookup
                    if otherSys == baseUrl {
                        string directId = otherVal.startsWith("Patient/") ? otherVal.substring(8) : otherVal;
                        pdqm:PDQmPatient|PatientNotFoundError|error directResult = getPatientById(directId);
                        if directResult is pdqm:PDQmPatient {
                            return [directResult];
                        }
                        continue;
                    }

                    sql:ParameterizedQuery fallbackQuery = `
                        SELECT p.* FROM patients p
                        INNER JOIN identifiers i ON p.id = i.patient_id
                        WHERE i.system = ${otherSys} AND i."value" = ${otherVal}
                    `;
                    if active is boolean {
                        fallbackQuery = sql:queryConcat(fallbackQuery, ` AND p.active = ${active}`);
                    }
                    fallbackQuery = sql:queryConcat(fallbackQuery, ` ORDER BY p.updated_at DESC LIMIT ${count} OFFSET ${offset}`);

                    stream<PatientRow, sql:Error?> fallbackStream = dbClient->query(fallbackQuery);
                    pdqm:PDQmPatient[] fallbackResults = [];
                    check from PatientRow row in fallbackStream
                        do {
                            pdqm:PDQmPatient|error patient = parsePatient(row.resource_json);
                            if patient is pdqm:PDQmPatient {
                                fallbackResults.push(patient);
                            }
                        };

                    if fallbackResults.length() > 0 {
                        return fallbackResults;
                    }
                }
            }
            // No identifier match at all — fall through to demographic search
        } else {
            log:printError(string `Invalid identifier format: ${identifier}. Expected "system|value".`);
            return [];
        }
    }
    
    // Step 2: Search by demographic data (or return all if no criteria)
    boolean hasDemographics = !(family is () && given is () && gender is () && birthdate is () &&
       telecom is () && address is () && city is () && state is () &&
       postalCode is () && country is () && mothersMaidenName is ());

    if !hasDemographics {
        if identifierProvided {
            // Identifier was provided but didn't match, no demographics to fall back to
            return [];
        }
        // No criteria at all — return all active patients
        sql:ParameterizedQuery allQuery = `SELECT * FROM patients WHERE active = true ORDER BY updated_at DESC LIMIT ${count} OFFSET ${offset}`;
        stream<PatientRow, sql:Error?> allStream = dbClient->query(allQuery);
        pdqm:PDQmPatient[] allPatients = [];
        check from PatientRow row in allStream
            do {
                pdqm:PDQmPatient|error patient = parsePatient(row.resource_json);
                if patient is pdqm:PDQmPatient {
                    allPatients.push(patient);
                }
            };
        return allPatients;
    }
    
    sql:ParameterizedQuery query = `SELECT * FROM patients WHERE 1=1`;
    
    // Active filter
    if active is boolean {
        query = sql:queryConcat(query, ` AND active = ${active}`);
    }
    
    // Family name filter
    if family is string {
        string pattern = "%" + family + "%";
        query = sql:queryConcat(query, ` AND LOWER(family_name) LIKE LOWER(${pattern})`);
    }
    
    // Given name filter
    if given is string {
        string pattern = "%" + given + "%";
        query = sql:queryConcat(query, ` AND LOWER(given_name) LIKE LOWER(${pattern})`);
    }
    
    // Gender filter
    if gender is string {
        query = sql:queryConcat(query, ` AND gender = ${gender}`);
    }
    
    // Birth date filter
    if birthdate is string {
        query = sql:queryConcat(query, ` AND birth_date = ${birthdate}`);
    }
    
    // City filter
    if city is string {
        string pattern = "%" + city + "%";
        query = sql:queryConcat(query, ` AND LOWER(city) LIKE LOWER(${pattern})`);
    }
    
    // State filter
    if state is string {
        query = sql:queryConcat(query, ` AND state = ${state}`);
    }
    
    // Postal code filter
    if postalCode is string {
        query = sql:queryConcat(query, ` AND postal_code = ${postalCode}`);
    }
    
    // Country filter
    if country is string {
        query = sql:queryConcat(query, ` AND country = ${country}`);
    }
    
    // Telecom filter (searches phone and email)
    if telecom is string {
        string pattern = "%" + telecom + "%";
        query = sql:queryConcat(query, ` AND (LOWER(phone) LIKE LOWER(${pattern}) OR LOWER(email) LIKE LOWER(${pattern}))`);
    }
    
    // General address filter (searches city, state, postal_code, country)
    if address is string {
        string pattern = "%" + address + "%";
        query = sql:queryConcat(query, ` AND (LOWER(city) LIKE LOWER(${pattern}) OR LOWER(state) LIKE LOWER(${pattern}) OR LOWER(postal_code) LIKE LOWER(${pattern}) OR LOWER(country) LIKE LOWER(${pattern}))`);
    }
    
    // Path A: no mothersMaidenName — single paginated query, unchanged behaviour
    if mothersMaidenName is () {
        sql:ParameterizedQuery pagedQuery = sql:queryConcat(query,
            ` ORDER BY updated_at DESC LIMIT ${count} OFFSET ${offset}`);
        stream<PatientRow, sql:Error?> rowStream = dbClient->query(pagedQuery);
        pdqm:PDQmPatient[] patients = [];
        check from PatientRow row in rowStream
            do {
                pdqm:PDQmPatient|error patient = parsePatient(row.resource_json);
                if patient is pdqm:PDQmPatient {
                    patients.push(patient);
                }
            };
        return patients;
    }

    // Path B: mothersMaidenName provided — iterative batch fetching so LIMIT/OFFSET
    // apply to the maiden-name-filtered set, not the raw DB rows.
    int batchSize = count * 10;
    if batchSize < 100 {
        batchSize = 100;
    }
    pdqm:PDQmPatient[] results = [];
    int matchedSeen = 0;
    int dbBatchOffset = 0;
    boolean exhausted = false;

    while results.length() < count && !exhausted {
        sql:ParameterizedQuery batchQuery = sql:queryConcat(query,
            ` ORDER BY updated_at DESC LIMIT ${batchSize} OFFSET ${dbBatchOffset}`);
        stream<PatientRow, sql:Error?> batchStream = dbClient->query(batchQuery);

        int rowsInBatch = 0;
        check from PatientRow row in batchStream
            do {
                rowsInBatch += 1;
                pdqm:PDQmPatient|error patient = parsePatient(row.resource_json);
                if patient is pdqm:PDQmPatient {
                    string? maidenName = getMothersMaidenName(patient);
                    if maidenName is string &&
                            maidenName.toLowerAscii().includes(mothersMaidenName.toLowerAscii()) {
                        matchedSeen += 1;
                        if matchedSeen > offset && results.length() < count {
                            results.push(patient);
                        }
                    }
                }
            };

        if rowsInBatch < batchSize {
            exhausted = true;
        }
        dbBatchOffset += batchSize;
    }

    return results;
}


// ============================================================
// BLOCKING KEY MANAGEMENT
// ============================================================

# Compute and store blocking keys for a single patient.
# Deletes any existing keys for this patient first.
# + patientId - The patient's CRUID
# + patient - The parsed PDQmPatient resource
# + return - error if database operations fail
isolated function storeBlockingKeys(string patientId, pdqm:PDQmPatient patient) returns error? {
    // Delete old keys
    _ = check dbClient->execute(
        `DELETE FROM blocking_keys WHERE patient_id = ${patientId}`
    );

    // Gather identifiers for this patient
    string[][] identifiers = [];
    foreach pdqm:PDQmPatientIdentifier id in patient.identifier {
        identifiers.push([id.system, id.value]);
    }

    // Compute new keys
    BlockingKey[] keys = computeBlockingKeys(patient, identifiers);

    // Insert new keys
    foreach BlockingKey key in keys {
        _ = check dbClient->execute(
            `INSERT INTO blocking_keys (patient_id, block_type, block_value)
             VALUES (${patientId}, ${key.blockType}, ${key.blockValue})`
        );
    }

    // Mark as up-to-date
    string now = time:utcToString(time:utcNow());
    _ = check dbClient->execute(
        `UPDATE patients SET blocking_keys_at = ${now} WHERE id = ${patientId}`
    );
}

# Refresh blocking keys for patients that need them (new/updated patients).
# Processes up to `batchSize` patients per call.
# + batchSize - Maximum patients to process in this batch
# + return - Number of patients processed, or error
function refreshBlockingKeys(int batchSize = 5000) returns int|error {
    stream<PatientRow, sql:Error?> staleStream = dbClient->query(
        `SELECT * FROM patients
         WHERE active = true
           AND (blocking_keys_at IS NULL OR blocking_keys_at < updated_at)
         ORDER BY updated_at ASC
         LIMIT ${batchSize}`
    );

    int processed = 0;
    check from PatientRow row in staleStream
        do {
            pdqm:PDQmPatient|error patient = parsePatient(row.resource_json);
            if patient is pdqm:PDQmPatient {
                error? storeResult = storeBlockingKeys(row.id, patient);
                if storeResult is error {
                    log:printError(string `Failed to store blocking keys for patient ${row.id}`, storeResult);
                } else {
                    processed += 1;
                }
            }
        };

    if processed > 0 {
        log:printInfo(string `Refreshed blocking keys for ${processed} patients`);
    }
    return processed;
}

// ============================================================
// MATCH PATIENTS (ITI-119)
// ============================================================

public type MatchResult record {|
    pdqm:PDQmPatient patient;
    decimal score;
    string matchGrade;
|};

# Find matching patients using blocking-based candidate selection.
# Instead of scanning all patients, uses pre-computed blocking keys
# to select a small candidate set, then scores only those candidates.
#
# + inputPatient - Patient demographics to match
# + threshold - Minimum match score (0.0-1.0)
# + maxResults - Maximum results to return
# + return - Array of match results sorted by score
public isolated function matchPatients(
        pdqm:PDQmPatient inputPatient,
        decimal threshold = 0.3d,
        int maxResults = 10
) returns MatchResult[]|error {

    // If blocking is disabled, fall back to full scan
    if !blocking.enabled {
        return matchPatientsFull(inputPatient, threshold, maxResults);
    }

    // Step 1: Compute blocking keys for the input patient (in memory, not stored)
    string[][] inputIdentifiers = [];
    foreach pdqm:PDQmPatientIdentifier id in inputPatient.identifier {
        inputIdentifiers.push([id.system, id.value]);
    }
    BlockingKey[] inputKeys = computeBlockingKeys(inputPatient, inputIdentifiers);

    // Step 2: Collect candidate patient IDs via blocking key lookups
    map<boolean> candidateIds = {};

    foreach BlockingKey key in inputKeys {
        stream<record {|string patient_id;|}, sql:Error?> rows = dbClient->query(
            `SELECT DISTINCT bk.patient_id
             FROM blocking_keys bk
             JOIN patients p ON bk.patient_id = p.id
             WHERE bk.block_type = ${key.blockType}
               AND bk.block_value = ${key.blockValue}
               AND p.active = true`
        );
        check from var row in rows
            do {
                candidateIds[row.patient_id] = true;
            };

        // Safety cap to prevent memory blowup from very common blocking keys
        if candidateIds.keys().length() >= blocking.maxCandidatesPerMatch {
            break;
        }
    }

    // Also do direct identifier lookup (fastest path, always runs)
    foreach pdqm:PDQmPatientIdentifier id in inputPatient.identifier {
        stream<record {|string patient_id;|}, sql:Error?> idRows = dbClient->query(
            `SELECT patient_id FROM identifiers
             WHERE system = ${id.system} AND "value" = ${id.value}`
        );
        check from var row in idRows
            do {
                candidateIds[row.patient_id] = true;
            };
    }

    // Step 3: If no candidates found via blocking and input has sparse data, fall back
    if candidateIds.keys().length() == 0 && inputKeys.length() == 0 {
        return matchPatientsFull(inputPatient, threshold, maxResults);
    }

    // Step 4: Load and score candidates
    string[] idList = candidateIds.keys();
    MatchResult[] results = [];

    foreach string candidateId in idList {
        PatientRow|sql:Error row = dbClient->queryRow(
            `SELECT * FROM patients WHERE id = ${candidateId} AND active = true`
        );
        if row is PatientRow {
            pdqm:PDQmPatient|error candidate = parsePatient(row.resource_json);
            if candidate is pdqm:PDQmPatient {
                decimal score = calculateScore(inputPatient, candidate);
                if score >= threshold {
                    results.push({
                        patient: candidate,
                        score: score,
                        matchGrade: getMatchGrade(score)
                    });
                }
            }
        }
    }

    // Step 5: Sort and limit
    results = results.sort("descending", isolated function(MatchResult r) returns decimal {
        return r.score;
    });

    if results.length() > maxResults {
        return results.slice(0, maxResults);
    }

    return results;
}

# Full-scan fallback for matchPatients (used when blocking is disabled or input is sparse).
# + inputPatient - Patient demographics to match
# + threshold - Minimum match score (0.0-1.0)
# + maxResults - Maximum results to return
# + return - Array of match results sorted by score
isolated function matchPatientsFull(
        pdqm:PDQmPatient inputPatient,
        decimal threshold = 0.3d,
        int maxResults = 10
) returns MatchResult[]|error {

    stream<PatientRow, sql:Error?> rowStream = dbClient->query(
        `SELECT * FROM patients WHERE active = true`
    );

    MatchResult[] results = [];

    check from PatientRow row in rowStream
        do {
            pdqm:PDQmPatient|error candidate = parsePatient(row.resource_json);
            if candidate is pdqm:PDQmPatient {
                decimal score = calculateScore(inputPatient, candidate);
                if score >= threshold {
                    results.push({
                        patient: candidate,
                        score: score,
                        matchGrade: getMatchGrade(score)
                    });
                }
            }
        };

    results = results.sort("descending", isolated function(MatchResult r) returns decimal {
        return r.score;
    });

    if results.length() > maxResults {
        return results.slice(0, maxResults);
    }

    return results;
}

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

# Count patients matching the same filters as searchPatients (for pagination total).
#
# + family - Family name filter
# + given - Given name filter
# + gender - Gender filter
# + birthdate - Birth date filter
# + telecom - Phone/email filter
# + address - General address filter
# + city - City filter
# + state - State filter
# + postalCode - Postal code filter
# + country - Country filter
# + identifier - Identifier filter (system|value format)
# + mothersMaidenName - Mother's maiden name filter (in-memory substring match)
# + active - Active status filter
# + return - the count or an error
public isolated function countFilteredPatients(
    string? family = (),
    string? given = (),
    string? gender = (),
    string? birthdate = (),
    string? telecom = (),
    string? address = (),
    string? city = (),
    string? state = (),
    string? postalCode = (),
    string? country = (),
    string? identifier = (),
    string? mothersMaidenName = (),
    boolean? active = true
) returns int|error {
    if identifier is string {
        int? pipeIdx = identifier.indexOf("|");
        if pipeIdx is int {
            string sys = identifier.substring(0, pipeIdx);
            string val = identifier.substring(pipeIdx + 1);
            if val.startsWith("Patient/") {
                val = val.substring(8);
            }
            if sys == baseUrl {
                pdqm:PDQmPatient|PatientNotFoundError|error directResult = getPatientById(val);
                if directResult is pdqm:PDQmPatient {
                    return 1;
                }
                if directResult is PatientNotFoundError {
                    return 0;
                }
                return directResult;
            }
            sql:ParameterizedQuery idCountQuery = `
                SELECT COUNT(*) as count FROM patients p
                INNER JOIN identifiers i ON p.id = i.patient_id
                WHERE i.system = ${sys} AND i."value" = ${val}`;
            if active is boolean {
                idCountQuery = sql:queryConcat(idCountQuery, ` AND p.active = ${active}`);
            }
            record {|int count;|}|sql:Error idResult = dbClient->queryRow(idCountQuery);
            if idResult is sql:Error {
                return idResult;
            }
            return idResult.count;
        } else {
            return 0;
        }
    }

    sql:ParameterizedQuery query = `SELECT COUNT(*) as count FROM patients WHERE 1=1`;

    if active is boolean {
        query = sql:queryConcat(query, ` AND active = ${active}`);
    }
    if family is string {
        string pattern = "%" + family + "%";
        query = sql:queryConcat(query, ` AND LOWER(family_name) LIKE LOWER(${pattern})`);
    }
    if given is string {
        string pattern = "%" + given + "%";
        query = sql:queryConcat(query, ` AND LOWER(given_name) LIKE LOWER(${pattern})`);
    }
    if gender is string {
        query = sql:queryConcat(query, ` AND gender = ${gender}`);
    }
    if birthdate is string {
        query = sql:queryConcat(query, ` AND birth_date = ${birthdate}`);
    }
    if city is string {
        string pattern = "%" + city + "%";
        query = sql:queryConcat(query, ` AND LOWER(city) LIKE LOWER(${pattern})`);
    }
    if state is string {
        query = sql:queryConcat(query, ` AND state = ${state}`);
    }
    if postalCode is string {
        query = sql:queryConcat(query, ` AND postal_code = ${postalCode}`);
    }
    if country is string {
        query = sql:queryConcat(query, ` AND country = ${country}`);
    }
    if telecom is string {
        string pattern = "%" + telecom + "%";
        query = sql:queryConcat(query, ` AND (LOWER(phone) LIKE LOWER(${pattern}) OR LOWER(email) LIKE LOWER(${pattern}))`);
    }
    if address is string {
        string pattern = "%" + address + "%";
        query = sql:queryConcat(query, ` AND (LOWER(city) LIKE LOWER(${pattern}) OR LOWER(state) LIKE LOWER(${pattern}) OR LOWER(postal_code) LIKE LOWER(${pattern}) OR LOWER(country) LIKE LOWER(${pattern}))`);
    }

    if mothersMaidenName is string {
        stream<PatientRow, sql:Error?> rowStream = dbClient->query(query);
        int matchCount = 0;
        check from PatientRow row in rowStream
            do {
                pdqm:PDQmPatient|error patient = parsePatient(row.resource_json);
                if patient is pdqm:PDQmPatient {
                    string? maidenName = getMothersMaidenName(patient);
                    if maidenName is string &&
                            maidenName.toLowerAscii().includes(mothersMaidenName.toLowerAscii()) {
                        matchCount += 1;
                    }
                }
            };
        return matchCount;
    }

    record {|int count;|}|sql:Error result = dbClient->queryRow(query);
    if result is sql:Error {
        return result;
    }
    return result.count;
}

# Get patient count
#
# + includeInactive - whether to include inactive patients in the count
# + return - the count of patients or an error
public isolated function getPatientCount(boolean includeInactive = false) returns int|error {
    record {|int count;|}|sql:Error result;
    if includeInactive {
        result = dbClient->queryRow(`SELECT COUNT(*) as count FROM patients`);
    } else {
        result = dbClient->queryRow(`SELECT COUNT(*) as count FROM patients WHERE active = true`);
    }
    if result is sql:Error {
        return result;
    }
    return result.count;
}

# Check if identifier exists
#
# + system - The identifier system URI
# + value - The identifier value
# + return - true if identifier exists, false otherwise, or error
isolated function identifierExists(string system, string value) returns boolean|error {
    record {|int count;|}|sql:Error result = dbClient->queryRow(
        `SELECT COUNT(*) as count FROM identifiers WHERE system = ${system} AND "value" = ${value}`
    );
    if result is sql:Error {
        return result;
    }
    return result.count > 0;
}
# Parse patient data from a JSON string representation
# + jsonStr - The JSON string containing patient data
# + return - A PDQmPatient object on success, or an error on failure
isolated function parsePatient(string jsonStr) returns pdqm:PDQmPatient|error {
    pdqm:PDQmPatient|error result = jsonStr.fromJsonStringWithType(pdqm:PDQmPatient);
    if result is pdqm:PDQmPatient {
        return result;
    }
    // Fallback: two-step parse (handles some JSON structures better in certain runtime versions)
    json patientJson = check jsonStr.fromJsonString();
    return patientJson.cloneWithType();
}

# Merge incoming patient fields into existing patient record.
# Fields present (non-nil) in the incoming patient overwrite the existing values.
# Fields absent (nil) in the incoming patient are preserved from the existing record.
# Identifiers are merged as a union (deduplicated by system|value), not replaced.
#
# + existing - The existing patient record from the database
# + incoming - The incoming patient from the update payload
# + return - The merged patient record
isolated function mergePatientFields(pdqm:PDQmPatient existing, pdqm:PDQmPatient incoming) returns pdqm:PDQmPatient|error {
    // Work entirely at JSON level to avoid runtime type violations.
    // The FHIR framework delivers nested arrays (name, telecom, address, etc.) as json[] at
    // runtime, so direct typed field assignment between patients throws InherentTypeViolation.
    // Same pattern as addCRIdentifier: toJson() -> map<json> -> modify -> json -> cloneWithType()
    json|error ej = existing.toJson();
    if ej is error { return ej; }
    json|error ij = incoming.toJson();
    if ij is error { return ij; }

    map<json> existingMap = check ej.ensureType();
    map<json> incomingMap = check ij.ensureType();

    // Start with existing as the base, overwrite with incoming non-null fields
    map<json> mergedMap = existingMap.clone();
    foreach string key in incomingMap.keys() {
        // meta and id are managed by the server; identifier is merged separately below
        if key == "meta" || key == "id" || key == "identifier" {
            continue;
        }
        json val = incomingMap[key];
        if val != () {
            mergedMap[key] = val;
        }
    }

    // Merge identifiers: union of existing + incoming (incoming takes precedence)
    json incomingIds = incomingMap["identifier"];
    json[] mergedIds = incomingIds is json[] ? incomingIds : [];
    string[] addedKeys = [];
    foreach json iid in mergedIds {
        map<json> idObj = check iid.ensureType();
        string sys = (idObj["system"] ?: "").toString();
        string idVal = (idObj["value"] ?: "").toString();
        addedKeys.push(string `${sys}|${idVal}`);
    }
    json existingIds = existingMap["identifier"];
    if existingIds is json[] {
        foreach json eid in existingIds {
            map<json> idObj = check eid.ensureType();
            string sys = (idObj["system"] ?: "").toString();
            string idVal = (idObj["value"] ?: "").toString();
            string key = string `${sys}|${idVal}`;
            boolean alreadyAdded = false;
            foreach string ak in addedKeys {
                if ak == key { alreadyAdded = true; break; }
            }
            if !alreadyAdded {
                mergedIds.push(eid);
                addedKeys.push(key);
            }
        }
    }
    mergedMap["identifier"] = mergedIds;

    // Assign to json first so cloneWithType() recursively converts nested types (e.g. json[] -> HumanName[])
    json updatedJson = mergedMap;
    return updatedJson.cloneWithType();
}

# Extract the family name from a patient record
# + patient - The PDQmPatient object to extract family name from
# + return - The family name as a string, or nil if not found
isolated function getFamily(pdqm:PDQmPatient patient) returns string? {
    r4:HumanName[]? names = patient.name;
    if names is r4:HumanName[] && names.length() > 0 {
        return names[0].family;
    }
    return ();
}

# Extract the given name from a patient record
# + patient - The PDQmPatient object to extract given name from
# + return - The given name as a string, or nil if not found
isolated function getGiven(pdqm:PDQmPatient patient) returns string? {
    r4:HumanName[]? names = patient.name;
    if names is r4:HumanName[] && names.length() > 0 {
        string[]? given = names[0].given;
        if given is string[] && given.length() > 0 {
            return string:'join(" ", ...given);
        }
    }
    return ();
}
# Extract a specific telecom value from patient contact information
# + patient - The PDQmPatient object to search for telecom data
# + system - The system type to filter by (e.g., "phone", "email")
# + return - The telecom value as a string, or nil if not found
# Extract telecom value
isolated function getTelecom(pdqm:PDQmPatient patient, string system) returns string? {
    r4:ContactPoint[]? telecoms = patient.telecom;
    if telecoms is r4:ContactPoint[] {
        foreach r4:ContactPoint t in telecoms {
            if t.system == system {
                return t.value;
            }
        }
    }
    return ();
}
# Extract a specific field from the patient's address information
# + patient - The PDQmPatient object to extract address data from
# + field - The address field to retrieve ("city", "state", or "postalCode")
# + return - The requested address field value, or nil if not found
# Extract address field
isolated function getAddressField(pdqm:PDQmPatient patient, string 'field) returns string? {
    r4:Address[]? addresses = patient.address;
    if addresses is r4:Address[] && addresses.length() > 0 {
        r4:Address addr = addresses[0];
        match 'field {
            "city" => { return addr.city; }
            "state" => { return addr.state; }
            "postalCode" => { return addr.postalCode; }
            "country" => { return addr.country; }
        }
    }
    return ();
}

# Extract mother's maiden name from patient (FHIR extension)
# + patient - The PDQmPatient object
# + return - The mother's maiden name or nil if not found
isolated function getMothersMaidenName(pdqm:PDQmPatient patient) returns string? {
    r4:Extension[]? extensions = patient.extension;
    if extensions is r4:Extension[] {
        foreach r4:Extension ext in extensions {
            if ext.url == "http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName" {
                // The value is stored as valueString
                anydata val = ext.get("valueString");
                if val is string {
                    return val;
                }
            }
        }
    }
    return ();
}

// calculateScore and getMatchGrade are now in matching.bal

// ============================================================
// ASYNC DEDUP JOB MANAGEMENT
// ============================================================

# Represents an async deduplication job
#
# + jobId - field description  
# + status - field description  
# + startedAt - field description  
# + completedAt - field description  
# + totalPatients - field description  
# + totalGroups - field description  
# + result - field description  
# + errorMessage - field description  
# + startedBy - field description
public type DedupJob record {|
    string jobId;
    string status;          // "pending" | "running" | "completed" | "failed"
    string startedAt;
    string? completedAt;
    int? totalPatients;
    int? totalGroups;
    DedupResult? result;
    string? errorMessage;
    string startedBy;
|};

// In-memory job store
map<DedupJob> dedupJobs = {};
boolean dedupRunning = false;
string? currentDedupJobId = ();

# Start dedup in background and update job state on completion.
#
# + jobId - The job ID to update
# + agentName - The agent who started the job
# + threshold - The dedup threshold score
function executeDedupAsync(string jobId, string agentName, decimal threshold) {
    // Update to RUNNING
    lock {
        DedupJob? job = dedupJobs[jobId];
        if job is DedupJob {
            dedupJobs[jobId] = {
                jobId: job.jobId,
                status: "running",
                startedAt: job.startedAt,
                completedAt: job.completedAt,
                totalPatients: job.totalPatients,
                totalGroups: job.totalGroups,
                result: job.result,
                errorMessage: job.errorMessage,
                startedBy: job.startedBy
            };
        }
    }

    DedupResult? lastResult = ();
    lock {
        string latestCompletedAt = "";
        foreach var [_, job] in dedupJobs.entries() {
            if job.status == "completed" && job.result is DedupResult {
                string completedAt = job.completedAt ?: "";
                if completedAt > latestCompletedAt {
                    latestCompletedAt = completedAt;
                    lastResult = <DedupResult>job.result;
                }
            }
        }
    }

    DedupResult|error result = deduplicatePatients(threshold, lastResult);
    string now = time:utcToString(time:utcNow());

    lock {
        if result is DedupResult {
            dedupJobs[jobId] = {
                jobId: jobId,
                status: "completed",
                startedAt: dedupJobs.hasKey(jobId) ? dedupJobs.get(jobId).startedAt : now,
                completedAt: now,
                totalPatients: result.totalPatients,
                totalGroups: result.totalGroups,
                result: result,
                errorMessage: (),
                startedBy: agentName
            };
        } else {
            dedupJobs[jobId] = {
                jobId: jobId,
                status: "failed",
                startedAt: dedupJobs.hasKey(jobId) ? dedupJobs.get(jobId).startedAt : now,
                completedAt: now,
                totalPatients: (),
                totalGroups: (),
                result: (),
                errorMessage: result.message(),
                startedBy: agentName
            };
        }
        dedupRunning = false;
        currentDedupJobId = ();
    }

    // Audit
    if result is DedupResult {
        log:printInfo(string `Async dedup complete: ${result.totalGroups} groups from ${result.totalPatients} patients`);
        auditDedup(agentName, result.totalGroups, true);
    } else {
        log:printError("Async dedup failed", result);
        auditDedup(agentName, 0, false, "Dedup failed: " + result.message());
    }

    // Cleanup old jobs (older than 1 hour)
    cleanupOldJobs();
}

# Remove completed/failed jobs older than 1 hour
function cleanupOldJobs() {
    string[] keysToRemove = [];
    lock {
        time:Utc now = time:utcNow();
        foreach var [key, job] in dedupJobs.entries() {
            if job.status == "completed" || job.status == "failed" {
                if job.completedAt is string {
                    time:Utc|error jobTime = time:utcFromString(<string>job.completedAt);
                    if jobTime is time:Utc {
                        time:Seconds diff = time:utcDiffSeconds(now, jobTime);
                        if diff > 3600d {
                            keysToRemove.push(key);
                        }
                    }
                }
            }
        }
        foreach string key in keysToRemove {
            _ = dedupJobs.remove(key);
        }
    }
}

// ============================================================
// DEDUPLICATION TYPES AND FUNCTIONS
// ============================================================

# Represents a field comparison between patients in a match group
#
# + matchedFields - field description  
# + unmatchedFields - field description
public type FieldComparison record {|
    string[] matchedFields;
    string[] unmatchedFields;
|};

# Represents a single dedup match group
#
# + id - field description  
# + status - field description  
# + score - field description  
# + matchGrade - field description  
# + createdAt - field description  
# + patients - field description  
# + matchedFields - field description  
# + unmatchedFields - field description
public type DedupGroup record {|
    string id;
    string status;       // always "pending" from backend
    decimal score;       // average pairwise score
    string matchGrade;   // grade based on average score
    string createdAt;
    json[] patients;     // full FHIR Patient resources as JSON
    string[] matchedFields;
    string[] unmatchedFields;
|};

# Full dedup result returned to client
#
# + totalPatients - field description
# + totalGroups - field description
# + totalGroupedPatients - total number of patient records across all groups
# + threshold - field description
# + timestamp - field description
# + groups - field description
public type DedupResult record {|
    int totalPatients;
    int totalGroups;
    int totalGroupedPatients;
    decimal threshold;
    string timestamp;
    DedupGroup[] groups;
|};

# Extract address line from patient (first line of first address)
# + patient - The PDQmPatient object
# + return - The address line as a string, or nil if not found
isolated function getAddressLine(pdqm:PDQmPatient patient) returns string? {
    r4:Address[]? addresses = patient.address;
    if addresses is r4:Address[] && addresses.length() > 0 {
        string[]? lines = addresses[0].line;
        if lines is string[] && lines.length() > 0 {
            return string:'join(", ", ...lines);
        }
    }
    return ();
}

# Compare demographic fields between two patients to determine matched/unmatched fields
# + a - First patient
# + b - Second patient
# + return - FieldComparison with matched and unmatched field lists
isolated function compareFields(pdqm:PDQmPatient a, pdqm:PDQmPatient b) returns FieldComparison {
    string[] matchedFields = [];
    string[] unmatchedFields = [];

    // family_name (uses configured algorithm)
    string? aFamily = getFamily(a);
    string? bFamily = getFamily(b);
    if aFamily is string && bFamily is string && compareField(aFamily, bFamily, matchingConfig.fields.family) > 0.0d {
        matchedFields.push("family_name");
    } else {
        unmatchedFields.push("family_name");
    }

    // given_name (uses configured algorithm)
    string? aGiven = getGiven(a);
    string? bGiven = getGiven(b);
    if aGiven is string && bGiven is string && compareField(aGiven, bGiven, matchingConfig.fields.given) > 0.0d {
        matchedFields.push("given_name");
    } else {
        unmatchedFields.push("given_name");
    }

    // birth_date (uses configured algorithm)
    if a.birthDate is string && b.birthDate is string && compareField(<string>a.birthDate, <string>b.birthDate, matchingConfig.fields.birthDate) > 0.0d {
        matchedFields.push("birth_date");
    } else {
        unmatchedFields.push("birth_date");
    }

    // gender (uses configured algorithm)
    if a.gender is string && b.gender is string && compareField(<string>a.gender, <string>b.gender, matchingConfig.fields.gender) > 0.0d {
        matchedFields.push("gender");
    } else {
        unmatchedFields.push("gender");
    }

    // phone (uses configured algorithm)
    string? aPhone = getTelecom(a, "phone");
    string? bPhone = getTelecom(b, "phone");
    if aPhone is string && bPhone is string && compareField(aPhone, bPhone, matchingConfig.fields.phone) > 0.0d {
        matchedFields.push("phone");
    } else {
        unmatchedFields.push("phone");
    }

    // email
    string? aEmail = getTelecom(a, "email");
    string? bEmail = getTelecom(b, "email");
    if aEmail is string && bEmail is string && aEmail.toLowerAscii() == bEmail.toLowerAscii() {
        matchedFields.push("email");
    } else {
        unmatchedFields.push("email");
    }

    // city
    string? aCity = getAddressField(a, "city");
    string? bCity = getAddressField(b, "city");
    if aCity is string && bCity is string && aCity.toLowerAscii() == bCity.toLowerAscii() {
        matchedFields.push("city");
    } else {
        unmatchedFields.push("city");
    }

    // postal_code (uses configured algorithm)
    string? aPostal = getAddressField(a, "postalCode");
    string? bPostal = getAddressField(b, "postalCode");
    if aPostal is string && bPostal is string && compareField(aPostal, bPostal, matchingConfig.fields.postalCode) > 0.0d {
        matchedFields.push("postal_code");
    } else {
        unmatchedFields.push("postal_code");
    }

    // address (line)
    string? aAddr = getAddressLine(a);
    string? bAddr = getAddressLine(b);
    if aAddr is string && bAddr is string && aAddr.toLowerAscii() == bAddr.toLowerAscii() {
        matchedFields.push("address");
    } else {
        unmatchedFields.push("address");
    }

    return { matchedFields, unmatchedFields };
}

# Run deduplication using blocking-based candidate selection with incremental support.
# Instead of O(n²) all-pairs comparison, uses blocking keys to find candidate pairs,
# and tracks previously compared pairs to avoid redundant work on subsequent runs.
#
# + threshold - Minimum score to consider a match (default 0.6)
# + lastResult - Result from the previous completed job; returned as-is when there are no new pairs
# + return - DedupResult containing all match groups, or error
public function deduplicatePatients(decimal threshold = 0.6d, DedupResult? lastResult = ()) returns DedupResult|error {

    // If blocking is disabled, fall back to full-scan dedup
    if !blocking.enabled {
        return deduplicatePatientsFull(threshold);
    }

    string now = time:utcToString(time:utcNow());

    // Step 1: Ensure blocking keys are up to date for all patients
    int refreshed = 1;
    while refreshed > 0 {
        refreshed = check refreshBlockingKeys(blocking.refreshBatchSize);
    }

    // Step 2: Get total active patient count
    record {|int count;|}|sql:Error countResult = dbClient->queryRow(
        `SELECT COUNT(*) as count FROM patients WHERE active = true`
    );
    int totalPatients = 0;
    if countResult is record {|int count;|} {
        totalPatients = countResult.count;
    }

    // Step 3: Find candidate pairs via blocking keys (excluding already-compared pairs)
    stream<record {|string pid1; string pid2;|}, sql:Error?> pairStream = dbClient->query(
        `SELECT DISTINCT
            CASE WHEN bk1.patient_id < bk2.patient_id
                 THEN bk1.patient_id ELSE bk2.patient_id END as pid1,
            CASE WHEN bk1.patient_id < bk2.patient_id
                 THEN bk2.patient_id ELSE bk1.patient_id END as pid2
         FROM blocking_keys bk1
         JOIN blocking_keys bk2
            ON bk1.block_type = bk2.block_type
           AND bk1.block_value = bk2.block_value
           AND bk1.patient_id < bk2.patient_id
         JOIN patients p1 ON bk1.patient_id = p1.id AND p1.active = true
         JOIN patients p2 ON bk2.patient_id = p2.id AND p2.active = true
         LEFT JOIN dedup_compared_pairs dcp
            ON dcp.patient_id_1 = CASE WHEN bk1.patient_id < bk2.patient_id
                                       THEN bk1.patient_id ELSE bk2.patient_id END
           AND dcp.patient_id_2 = CASE WHEN bk1.patient_id < bk2.patient_id
                                       THEN bk2.patient_id ELSE bk1.patient_id END
         WHERE dcp.patient_id_1 IS NULL`
    );

    // Collect new pairs to compare
    record {|string pid1; string pid2;|}[] newPairs = [];
    check from var pair in pairStream
        do {
            newPairs.push(pair);
        };

    log:printInfo(string `Dedup: ${newPairs.length()} new candidate pairs to compare`);

    if newPairs.length() == 0 && lastResult != () && lastResult.totalGroups > 0 {
        log:printInfo(string `Dedup: No new pairs to score — reusing cached result (${lastResult.totalGroups} groups)`);
        return lastResult;
    }

    // Step 4: Score new pairs with a patient cache to avoid repeated DB reads
    map<pdqm:PDQmPatient> patientCache = {};

    foreach var pair in newPairs {
        // Load patients with cache
        pdqm:PDQmPatient p1 = check loadPatientCached(pair.pid1, patientCache);
        pdqm:PDQmPatient p2 = check loadPatientCached(pair.pid2, patientCache);

        decimal score = calculateScore(p1, p2);

        // Record comparison — upsert delegated to active database provider
        _ = check dbClient->execute(
            dbProvider.getUpsertComparePair(pair.pid1, pair.pid2, now, score)
        );
    }

    // Step 5: Build groups from ALL scored pairs above threshold (including previously scored)
    // Exclude pairs where patients share a dedup exclusion code (admin-rejected matches)
    stream<record {|string patient_id_1; string patient_id_2; decimal score;|}, sql:Error?> scoredStream = dbClient->query(
        `SELECT dcp.patient_id_1, dcp.patient_id_2, dcp.score
         FROM dedup_compared_pairs dcp
         JOIN patients p1 ON dcp.patient_id_1 = p1.id AND p1.active = true
         JOIN patients p2 ON dcp.patient_id_2 = p2.id AND p2.active = true
         WHERE dcp.score >= ${threshold}`
    );

    // Pre-load exclusion codes for all patients involved to avoid per-pair DB calls
    map<string[]> exclusionCache = {};

    // Union-Find for grouping connected patients
    map<string> parent = {};

    // In-memory score cache: "id1:id2" (id1 < id2) → score, populated from the stream below
    map<decimal> pairScoreMap = {};

    check from var row in scoredStream
        do {
            // Cache score for every above-threshold pair before exclusion check,
            // so the nested loop in Step 6 can look up scores without DB calls.
            string scoreKey = row.patient_id_1 < row.patient_id_2
                ? row.patient_id_1 + ":" + row.patient_id_2
                : row.patient_id_2 + ":" + row.patient_id_1;
            pairScoreMap[scoreKey] = row.score;

            // Check if this pair has been rejected (shares an exclusion code)
            boolean excluded = check hasSharedExclusionCached(
                row.patient_id_1, row.patient_id_2, exclusionCache
            );
            if excluded {
                // Skip this pair — admin decided they are not the same person
            } else {
                // Ensure both patients are in the union-find
                if !parent.hasKey(row.patient_id_1) {
                    parent[row.patient_id_1] = row.patient_id_1;
                }
                if !parent.hasKey(row.patient_id_2) {
                    parent[row.patient_id_2] = row.patient_id_2;
                }
                // Union: connect the two patients
                string root1 = findRoot(parent, row.patient_id_1);
                string root2 = findRoot(parent, row.patient_id_2);
                if root1 != root2 {
                    parent[root1] = root2;
                }
            }
        };

    // Collect groups by root
    map<string[]> groupMap = {};
    foreach string pid in parent.keys() {
        string root = findRoot(parent, pid);
        if groupMap.hasKey(root) {
            string[] members = groupMap.get(root);
            members.push(pid);
            groupMap[root] = members;
        } else {
            groupMap[root] = [pid];
        }
    }

    // Step 6: Build DedupGroup objects (only groups with 2+ patients)
    DedupGroup[] groups = [];
    int groupIndex = 0;

    foreach string[] memberIds in groupMap {
        if memberIds.length() < 2 {
            continue;
        }

        // Load patients for this group
        pdqm:PDQmPatient[] groupPatients = [];
        foreach string pid in memberIds {
            pdqm:PDQmPatient p = check loadPatientCached(pid, patientCache);
            groupPatients.push(p);
        }

        // Calculate average pairwise score from the stored comparisons
        decimal totalScore = 0.0d;
        int pairCount = 0;
        foreach int i in 0 ..< memberIds.length() {
            foreach int j in (i + 1) ..< memberIds.length() {
                string id1 = memberIds[i] < memberIds[j] ? memberIds[i] : memberIds[j];
                string id2 = memberIds[i] < memberIds[j] ? memberIds[j] : memberIds[i];
                decimal? cachedScore = pairScoreMap[id1 + ":" + id2];
                if cachedScore is decimal {
                    totalScore += cachedScore;
                    pairCount += 1;
                }
            }
        }
        decimal avgScore = pairCount > 0 ? totalScore / <decimal>pairCount : 0.0d;

        // Compare fields between first two patients
        FieldComparison fieldComp = compareFields(groupPatients[0], groupPatients[1]);

        // Build patient JSON array
        json[] patientJsons = [];
        foreach pdqm:PDQmPatient p in groupPatients {
            patientJsons.push(p.toJson());
        }

        groups.push({
            id: string `group-${now}-${groupIndex}`,
            status: "pending",
            score: avgScore,
            matchGrade: getMatchGrade(avgScore),
            createdAt: now,
            patients: patientJsons,
            matchedFields: fieldComp.matchedFields,
            unmatchedFields: fieldComp.unmatchedFields
        });
        groupIndex += 1;
    }

    int totalGroupedPatients = 0;
    foreach DedupGroup g in groups {
        totalGroupedPatients += g.patients.length();
    }

    return {
        totalPatients: totalPatients,
        totalGroups: groups.length(),
        totalGroupedPatients: totalGroupedPatients,
        threshold: threshold,
        timestamp: now,
        groups: groups
    };
}

# Union-Find: find root with path compression.
# parent map is modified in place to optimize future lookups.
# Returns the root ID for the given patient ID.
# + parent - The union-find parent map
# + id - The patient ID to find the root for
# + return - The root patient ID that represents the group for the given ID
# Example usage:
function findRoot(map<string> parent, string id) returns string {
    string current = id;
    while parent.hasKey(current) && parent.get(current) != current {
        // Path compression: point to grandparent
        string p = parent.get(current);
        if parent.hasKey(p) {
            parent[current] = parent.get(p);
        }
        current = p;
    }
    return current;
}

# Check if two patients were rejected as a pair, using a cache to avoid redundant DB reads.
# + patientId1 - First patient CRUID
# + patientId2 - Second patient CRUID
# + cache - Cache of patient ID → exclusion codes
# + return - true if the pair was rejected
function hasSharedExclusionCached(string patientId1, string patientId2, map<string[]> cache) returns boolean|error {
    // Load rejected peers for patient 1
    if !cache.hasKey(patientId1) {
        string[]|error peers = getRejectedPeers(patientId1);
        cache[patientId1] = peers is string[] ? peers : [];
    }
    // Load rejected peers for patient 2
    if !cache.hasKey(patientId2) {
        string[]|error peers = getRejectedPeers(patientId2);
        cache[patientId2] = peers is string[] ? peers : [];
    }

    string[] peers1 = cache.get(patientId1);
    foreach string peerId in peers1 {
        if peerId == patientId2 {
            return true;
        }
    }

    return false;
}

isolated function normalizePair(string patientId1, string patientId2) returns record {|string left; string right;|} {
    if patientId1 <= patientId2 {
        return {left: patientId1, right: patientId2};
    }
    return {left: patientId2, right: patientId1};
}

isolated function getRejectedPeers(string patientId) returns string[]|error {
    stream<record {|string patient_id_1; string patient_id_2;|}, sql:Error?> rowStream = dbClient->query(
        `SELECT patient_id_1, patient_id_2
         FROM dedup_pair_decisions
         WHERE status = 'rejected'
           AND (patient_id_1 = ${patientId} OR patient_id_2 = ${patientId})`
    );

    string[] peers = [];
    check from var row in rowStream
        do {
            if row.patient_id_1 == patientId {
                peers.push(row.patient_id_2);
            } else {
                peers.push(row.patient_id_1);
            }
        };
    return peers;
}

isolated function hasRejectedPairDecision(string patientId1, string patientId2) returns boolean|error {
    record {|string left; string right;|} pair = normalizePair(patientId1, patientId2);
    record {|int cnt;|}|sql:Error row = dbClient->queryRow(
        `SELECT COUNT(*) AS cnt
         FROM dedup_pair_decisions
         WHERE patient_id_1 = ${pair.left}
           AND patient_id_2 = ${pair.right}
           AND status = 'rejected'`
    );
    if row is sql:Error {
        return row;
    }
    return row.cnt > 0;
}

# Load a patient by ID with an in-memory cache to avoid redundant DB reads.
# + patientId - The patient's CRUID
# + cache - In-memory cache of patient IDs to PDQmPatient objects
# + return - The PDQmPatient object or error
function loadPatientCached(string patientId, map<pdqm:PDQmPatient> cache) returns pdqm:PDQmPatient|error {
    if cache.hasKey(patientId) {
        return cache.get(patientId);
    }
    PatientRow|sql:Error row = dbClient->queryRow(
        `SELECT * FROM patients WHERE id = ${patientId}`
    );
    if row is sql:Error {
        return row;
    }
    pdqm:PDQmPatient patient = check parsePatient(row.resource_json);
    cache[patientId] = patient;
    return patient;
}

# Full-scan fallback for dedup (used when blocking is disabled).
#
# + threshold - Minimum score to consider a match (default 0.6)
# + return - DedupResult containing all match groups, or error
function deduplicatePatientsFull(decimal threshold = 0.6d) returns DedupResult|error {
    stream<PatientRow, sql:Error?> rowStream = dbClient->query(
        `SELECT * FROM patients WHERE active = true`
    );

    PatientRow[] rows = [];
    check from PatientRow row in rowStream
        do {
            rows.push(row);
        };

    pdqm:PDQmPatient[] patients = [];
    foreach PatientRow row in rows {
        pdqm:PDQmPatient|error patient = parsePatient(row.resource_json);
        if patient is pdqm:PDQmPatient {
            patients.push(patient);
        }
    }

    int totalPatients = patients.length();
    string now = time:utcToString(time:utcNow());

    map<boolean> processed = {};
    DedupGroup[] groups = [];
    int groupIndex = 0;
    map<string[]> exclusionCache = {};

    foreach int i in 0 ..< patients.length() {
        string? patientIdI = patients[i].id;
        if patientIdI is () { continue; }
        if processed.hasKey(patientIdI) { continue; }

        record {|pdqm:PDQmPatient patient; decimal score;|}[] matchedPeers = [];

        foreach int j in (i + 1) ..< patients.length() {
            string? patientIdJ = patients[j].id;
            if patientIdJ is () { continue; }
            if processed.hasKey(patientIdJ) { continue; }

            // Skip pairs rejected by admin
            boolean excluded = check hasSharedExclusionCached(patientIdI, patientIdJ, exclusionCache);
            if excluded { continue; }

            decimal score = calculateScore(patients[i], patients[j]);
            if score >= threshold {
                matchedPeers.push({ patient: patients[j], score: score });
            }
        }

        if matchedPeers.length() > 0 {
            decimal totalScore = 0.0d;
            foreach var peer in matchedPeers {
                totalScore += peer.score;
            }
            decimal avgScore = totalScore / <decimal>matchedPeers.length();

            FieldComparison fieldComp = compareFields(patients[i], matchedPeers[0].patient);

            json[] patientJsons = [];
            patientJsons.push(patients[i].toJson());
            foreach var peer in matchedPeers {
                patientJsons.push(peer.patient.toJson());
            }

            DedupGroup group = {
                id: string `group-${now}-${groupIndex}`,
                status: "pending",
                score: avgScore,
                matchGrade: getMatchGrade(avgScore),
                createdAt: now,
                patients: patientJsons,
                matchedFields: fieldComp.matchedFields,
                unmatchedFields: fieldComp.unmatchedFields
            };
            groups.push(group);
            groupIndex += 1;

            processed[patientIdI] = true;
            foreach var peer in matchedPeers {
                string? peerId = peer.patient.id;
                if peerId is string {
                    processed[peerId] = true;
                }
            }
        }
    }

    int totalGroupedPatientsFull = 0;
    foreach DedupGroup g in groups {
        totalGroupedPatientsFull += g.patients.length();
    }

    return {
        totalPatients: totalPatients,
        totalGroups: groups.length(),
        totalGroupedPatients: totalGroupedPatientsFull,
        threshold: threshold,
        timestamp: now,
        groups: groups
    };
}

// ============================================================
// MATCH REJECTION (PAIR DECISIONS)
// ============================================================

# Reject a match between two patients by recording a pair-level manual decision.
# A row is upserted in dedup_pair_decisions; status captures the outcome and
# active=false marks the review item as resolved.
#
# + patientId1 - First patient CRUID
# + patientId2 - Second patient CRUID
# + rejectedBy - The user/agent who rejected the match
# + return - The generated decision ID, or error
public function rejectMatch(string patientId1, string patientId2, string rejectedBy) returns string|error {
    // Verify both patients exist
    PatientRow|sql:Error row1 = dbClient->queryRow(
        `SELECT * FROM patients WHERE id = ${patientId1}`
    );
    if row1 is sql:NoRowsError {
        return error PatientNotFoundError(string `Patient ${patientId1} not found`);
    }
    if row1 is sql:Error {
        return row1;
    }
    PatientRow|sql:Error row2 = dbClient->queryRow(
        `SELECT * FROM patients WHERE id = ${patientId2}`
    );
    if row2 is sql:NoRowsError {
        return error PatientNotFoundError(string `Patient ${patientId2} not found`);
    }
    if row2 is sql:Error {
        return row2;
    }

    record {|string left; string right;|} pair = normalizePair(patientId1, patientId2);
    string now = time:utcToString(time:utcNow());
    string decisionId = uuid:createType4AsString();

    _ = check dbClient->execute(
        dbProvider.getUpsertPairDecision(pair.left, pair.right, decisionId, now, rejectedBy)
    );

    log:printInfo(string `Match rejected: ${patientId1} <-> ${patientId2} (decision: ${decisionId}, by: ${rejectedBy})`);

    return decisionId;
}

# Check if two patients were previously rejected as a match.
# + patientId1 - First patient CRUID
# + patientId2 - Second patient CRUID
# + return - true if the pair has a rejected decision, false otherwise
public isolated function hasSharedExclusion(string patientId1, string patientId2) returns boolean|error {
    boolean|error rejected = hasRejectedPairDecision(patientId1, patientId2);
    if rejected is boolean {
        if rejected {
            return true;
        }
    } else {
        return rejected;
    }

    return false;
}

# Remove a merged/inactive patient from all cached dedup job results.
# Groups with fewer than 2 patients after removal are dropped entirely.
# + patientId - CRUID of the patient to evict
public function evictPatientFromDedupCache(string patientId) {
    lock {
        string[] jobIds = dedupJobs.keys();
        foreach string jobId in jobIds {
            DedupJob? job = dedupJobs[jobId];
            if !(job is DedupJob) || !(job.result is DedupResult) {
                continue;
            }
            DedupResult r = <DedupResult>job.result;
            DedupGroup[] updatedGroups = [];
            int groupedCount = 0;
            foreach DedupGroup grp in r.groups {
                json[] remaining = grp.patients.filter(
                    isolated function(json p) returns boolean {
                        if p is map<json> {
                            return p["id"] != patientId;
                        }
                        return true;
                    }
                );
                if remaining.length() >= 2 {
                    updatedGroups.push({
                        id: grp.id,
                        status: grp.status,
                        score: grp.score,
                        matchGrade: grp.matchGrade,
                        createdAt: grp.createdAt,
                        patients: remaining,
                        matchedFields: grp.matchedFields,
                        unmatchedFields: grp.unmatchedFields
                    });
                    groupedCount += remaining.length();
                }
            }
            int prevTotal = job.totalPatients ?: r.totalPatients;
            dedupJobs[jobId] = {
                jobId: job.jobId,
                status: job.status,
                startedAt: job.startedAt,
                completedAt: job.completedAt,
                totalPatients: prevTotal - 1,
                totalGroups: updatedGroups.length(),
                result: {
                    totalPatients: r.totalPatients - 1,
                    totalGroups: updatedGroups.length(),
                    totalGroupedPatients: groupedCount,
                    threshold: r.threshold,
                    timestamp: r.timestamp,
                    groups: updatedGroups
                },
                errorMessage: job.errorMessage,
                startedBy: job.startedBy
            };
        }
    }
}

# Remove any cached group that contains both of the given patient IDs (rejected pair).
# Neither patient is removed from the system — only the group linking them is dropped.
# + patientId1 - First patient CRUID of the rejected pair
# + patientId2 - Second patient CRUID of the rejected pair
public function evictRejectedGroupFromDedupCache(string patientId1, string patientId2) {
    lock {
        string[] jobIds = dedupJobs.keys();
        foreach string jobId in jobIds {
            DedupJob? job = dedupJobs[jobId];
            if !(job is DedupJob) || !(job.result is DedupResult) {
                continue;
            }
            DedupResult r = <DedupResult>job.result;
            DedupGroup[] updatedGroups = [];
            int groupedCount = 0;
            foreach DedupGroup grp in r.groups {
                boolean hasPid1 = grp.patients.some(
                    isolated function(json p) returns boolean =>
                        p is map<json> && p["id"] == patientId1
                );
                boolean hasPid2 = grp.patients.some(
                    isolated function(json p) returns boolean =>
                        p is map<json> && p["id"] == patientId2
                );
                if !(hasPid1 && hasPid2) {
                    updatedGroups.push(grp);
                    groupedCount += grp.patients.length();
                }
            }
            dedupJobs[jobId] = {
                jobId: job.jobId,
                status: job.status,
                startedAt: job.startedAt,
                completedAt: job.completedAt,
                totalPatients: job.totalPatients,
                totalGroups: updatedGroups.length(),
                result: {
                    totalPatients: r.totalPatients,
                    totalGroupedPatients: groupedCount,
                    totalGroups: updatedGroups.length(),
                    threshold: r.threshold,
                    timestamp: r.timestamp,
                    groups: updatedGroups
                },
                errorMessage: job.errorMessage,
                startedBy: job.startedBy
            };
        }
    }
}

# Close the database connection and release resources
# + return - An error if the connection cannot be closed properly, nil otherwise
# Close database connection
public function closeDatabase() returns error? {
    check dbClient.close();
}


# Merge identifiers from two patients into a union set, deduplicated by system|value.
# Incoming identifiers take precedence; existing ones not in the incoming set are appended.
# Uses JSON-level manipulation (same pattern as addCRIdentifier) to avoid typed record issues.
#
# + existingPatient - The patient currently stored in the database
# + incomingPatient - The patient from the update payload
# + return - The incoming patient with merged identifiers, or an error
isolated function mergeIdentifiers(pdqm:PDQmPatient existingPatient, pdqm:PDQmPatient incomingPatient)
        returns pdqm:PDQmPatient|error {
    json|error ej = existingPatient.toJson();
    if ej is error {
        return ej;
    }
    json|error ij = incomingPatient.toJson();
    if ij is error {
        return ij;
    }

    map<json> existingMap = check ej.ensureType();
    map<json> incomingMap = check ij.ensureType();

    // Start with incoming identifiers (they take precedence)
    json incomingIds = incomingMap["identifier"];
    json[] mergedIds = incomingIds is json[] ? incomingIds : [];

    // Track system|value keys already present
    string[] addedKeys = [];
    foreach json iid in mergedIds {
        map<json> idObj = check iid.ensureType();
        string sys = (idObj["system"] ?: "").toString();
        string val = (idObj["value"] ?: "").toString();
        addedKeys.push(string `${sys}|${val}`);
    }

    // Append existing identifiers not already in the merged set
    json existingIds = existingMap["identifier"];
    if existingIds is json[] {
        foreach json eid in existingIds {
            map<json> idObj = check eid.ensureType();
            string sys = (idObj["system"] ?: "").toString();
            string val = (idObj["value"] ?: "").toString();
            string key = string `${sys}|${val}`;
            boolean alreadyAdded = false;
            foreach string ak in addedKeys {
                if ak == key {
                    alreadyAdded = true;
                    break;
                }
            }
            if !alreadyAdded {
                mergedIds.push(eid);
                addedKeys.push(key);
            }
        }
    }

    // Write merged identifiers back and return as PDQmPatient
    // (assign to json first so cloneWithType recursively converts nested types, same as addCRIdentifier)
    incomingMap["identifier"] = mergedIds;
    json updatedJson = incomingMap;
    pdqm:PDQmPatient|error result = updatedJson.cloneWithType();
    return result;
}

isolated function addCRIdentifier(pdqm:PDQmPatient newPatient, string value)
        returns pdqm:PDQmPatient|InvalidPatientError|error {
    //covert to json
    json|error j =  newPatient.toJson();     // if toJson() can return error in your type
    //error handling
    if j is error {
        return j;   
    }   
    //add CR identifier
    json newIdentifier = {
        "system": baseUrl,
        "value": "Patient/" + value
    };
    map<json> patientMap = check j.ensureType();
    json identifiers = patientMap["identifier"];
    if identifiers is json[] {
        identifiers.push(newIdentifier);
        patientMap["identifier"] = identifiers;
    } else {
        patientMap["identifier"] = [newIdentifier];
    }
    json updatedJson = patientMap;

    // Convert back to PDQmPatient
    pdqm:PDQmPatient|error updatedPatient = updatedJson.cloneWithType();
    if updatedPatient is error {
        // cloneWithType can fail for patients with complex FHIR fields (e.g. Extension choice types).
        // Fall back to the original patient so the caller can still store the record.
        log:printWarn("addCRIdentifier: cloneWithType failed — storing patient without CR identifier in resource JSON", updatedPatient);
        return newPatient;
    }

    return updatedPatient;
}
