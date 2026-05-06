// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0

// IHE PDQm/PIXm MPI Service with H2 Database
// ==========================================
// Implements ITI-78, ITI-104, ITI-119
// With FHIR Audit Service Integration (ITI-20 ATNA)

import ballerina/http;
import ballerina/log;
import ballerina/uuid;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhirr4;
import ballerinax/health.fhir.r4.ihe.pdqm320 as pdqm;

configurable string baseUrl = ?;

// Initialize database on startup
function init() returns error? {
    check validateFieldsConfig(matchingConfig);
    if matchThreshold < 0.0d || matchThreshold > 1.0d {
        return error("matchThreshold " + matchThreshold.toString() + " is out of range [0.0, 1.0]");
    }
    if dedupThreshold < 0.0d || dedupThreshold > 1.0d {
        return error("dedupThreshold " + dedupThreshold.toString() + " is out of range [0.0, 1.0]");
    }
    check initDatabase();
    int count = check getPatientCount();
    log:printInfo(string `MPI Service started. Database has ${count} patients.`);

    // Migrate blocking keys for existing patients that don't have them yet
    if blocking.enabled {
        int processed = 1;
        int totalMigrated = 0;
        while processed > 0 {
            processed = check refreshBlockingKeys(blocking.refreshBatchSize);
            totalMigrated += processed;
        }
        if totalMigrated > 0 {
            log:printInfo(string `Blocking key migration complete: ${totalMigrated} patients processed.`);
        }
    }
}

// FHIR API Config

service /fhir/r4 on new fhirr4:Listener(9090, patientApiConfig) {

    // ========================================
    // ITI-119: Patient Match
    // POST /Patient/$match
    // ========================================
    resource function post Patient/\$match(r4:FHIRContext ctx, pdqm:MatchParametersIn payload)
            returns http:Ok|http:BadRequest|http:InternalServerError|http:Unauthorized|http:Forbidden {

        log:printInfo("ITI-119: Patient Match");

        // Authenticate and authorize (read-only: admin + viewer)
        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN, ROLE_VIEWER]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }
        string agentName = authResult.email;
        string rawPayload = payload.toJsonString();

        // Extract parameters
        json? patientJson = ();
        int count = 10;
        boolean onlyCertainMatches = false;

        pdqm:MatchParametersInParameter[]? params = payload.'parameter;
        if params is () {
            auditMatch(agentName, rawPayload, "", 0, false, "Missing parameter array");
            return <http:BadRequest>{body: errorOutcome("Missing parameter array")};
        }

        foreach pdqm:MatchParametersInParameter param in params {
            match param.name {
                "resource" => {
                    r4:Resource? res = param.'resource;
                    if res is r4:Resource {
                        patientJson = res.toJson();
                    }
                }
                "count" => {
                    if param.valueInteger is int {
                        count = <int>param.valueInteger;
                    }
                }
                "onlyCertainMatches" => {
                    if param.valueBoolean is boolean {
                        onlyCertainMatches = <boolean>param.valueBoolean;
                    }
                }
            }
        }

        if patientJson is () {
            auditMatch(agentName, rawPayload, "", 0, false, "Missing resource parameter");
            return <http:BadRequest>{body: errorOutcome("Missing resource parameter")};
        }

        // Parse input patient
        pdqm:PDQmMatchInput|error inputPatient = patientJson.cloneWithType();
        if inputPatient is error {
            auditMatch(agentName, rawPayload, "", 0, false, "Invalid Patient: " + inputPatient.message());
            return <http:BadRequest>{body: errorOutcome("Invalid Patient: " + inputPatient.message())};
        }

        // Convert to PDQmPatient for matching
        pdqm:PDQmPatientIdentifier[] identifiers = [];
        r4:Identifier[]? inputIdentifiers = inputPatient.identifier;
        if inputIdentifiers is r4:Identifier[] {
            foreach r4:Identifier id in inputIdentifiers {
                string? sys = id.system;
                string? val = id.value;
                if sys is string && val is string {
                    identifiers.push({system: sys, value: val});
                }
            }
        }
        if identifiers.length() == 0 {
            identifiers = [{system: "urn:temp", value: "temp"}];
        }

        pdqm:PDQmPatient searchPatient = {
            resourceType: "Patient",
            identifier: identifiers,
            name: inputPatient.name,
            gender: inputPatient.gender is pdqm:PDQmMatchInputGender ? 
                    <pdqm:PDQmPatientGender>inputPatient.gender : (),
            birthDate: inputPatient.birthDate,
            telecom: inputPatient.telecom,
            address: inputPatient.address
        };

        // Find matches
        MatchResult[]|error matches = matchPatients(searchPatient, matchThreshold, count);
        if matches is error {
            log:printError("Match error", matches);
            auditMatch(agentName, rawPayload, "", 0, false, "Match failed: " + matches.message());
            return <http:InternalServerError>{body: errorOutcome("Match failed")};
        }

        // Filter for certain matches if requested
        MatchResult[] finalMatches = matches;
        if onlyCertainMatches {
            MatchResult[] certain = finalMatches.filter(m => m.matchGrade == "certain");
            if certain.length() > 1 {
                auditMatch(agentName, rawPayload, "", certain.length(), false, "Multiple certain matches found");
                return <http:BadRequest>{
                    body: errorOutcome("Multiple certain matches found")
                };
            }
            finalMatches = certain;
        }

        // Build Bundle — entries typed as json[] to carry the match-grade extension
        // on search (r4:BundleEntrySearch is a closed record without extension).
        json[] entries = [];
        foreach MatchResult m in finalMatches {
            json|error patientAsJson = m.patient.cloneWithType(json);
            json patientData = patientAsJson is json ? patientAsJson : {};
            entries.push({
                "fullUrl": string `${baseUrl}/Patient/${m.patient.id ?: ""}`,
                "resource": patientData,
                "search": {
                    "mode": "match",
                    "score": m.score,
                    "extension": [
                        {
                            "url": "http://hl7.org/fhir/StructureDefinition/match-grade",
                            "valueCode": m.matchGrade
                        }
                    ]
                }
            });
        }

        log:printInfo(string `ITI-119: Found ${entries.length()} matches`);

        // Audit successful match
        string firstPatientId = finalMatches.length() > 0 ? (finalMatches[0].patient.id ?: "") : "";
        auditMatch(agentName, rawPayload, firstPatientId, entries.length(), true);

        return <http:Ok>{body: {
            "resourceType": "Bundle",
            "id": uuid:createType1AsString(),
            "type": "searchset",
            "total": entries.length(),
            "entry": entries
        }};
    }

    // ========================================
    // Custom: Start Async Patient Deduplication
    // GET /Patient/dedupstart
    // ========================================
    resource function get Patient/dedupstart(r4:FHIRContext ctx)
            returns http:Response|http:Unauthorized|http:Forbidden {

        log:printInfo("Custom: Start Async Patient Deduplication");

        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN, ROLE_VIEWER]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }
        string agentName = authResult.email;

        string jobId;
        lock {
            if dedupRunning {
                // Already running — return 202 with Content-Location so client can poll
                string runningJobId = currentDedupJobId ?: "unknown";
                http:Response alreadyRunning = new;
                alreadyRunning.statusCode = 202;
                alreadyRunning.setHeader("Content-Location", "/Patient/dedupstatus");
                alreadyRunning.setJsonPayload({
                    "message": "A deduplication job is already running",
                    "jobId": runningJobId
                });
                return alreadyRunning;
            }

            jobId = uuid:createType4AsString();
            string now = getCurrentTimestamp();
            DedupJob newJob = {
                jobId: jobId,
                status: "pending",
                startedAt: now,
                completedAt: (),
                totalPatients: (),
                totalGroups: (),
                result: (),
                errorMessage: (),
                startedBy: agentName
            };
            dedupJobs[jobId] = newJob;
            dedupRunning = true;
            currentDedupJobId = jobId;
        }

        // Fire-and-forget: run dedup in a background strand
        _ = start executeDedupAsync(jobId, agentName, dedupThreshold);

        // Return 202 Accepted with Content-Location (FHIR async pattern, same as $export)
        http:Response response = new;
        response.statusCode = 202;
        response.setHeader("Content-Location", "/Patient/dedupstatus");
        return response;
    }

    // ========================================
    // Custom: Poll Dedup Job Status
    // GET /Patient/dedupstatus
    // Returns the current/latest job status (only one job runs at a time)
    // ========================================
    resource function get Patient/dedupstatus(r4:FHIRContext ctx)
            returns http:Response|http:Unauthorized|http:Forbidden {

        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN, ROLE_VIEWER]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }

        log:printInfo("Custom: Poll Dedup Job Status");

        // Find the most recent job (running first, then latest by startedAt)
        string jobId = "";
        string jobStatus = "";
        string startedAt = "";
        string completedAt = "";
        string errorMsg = "";
        DedupResult? fullResult = ();
        boolean found = false;

        lock {
            // If a job is currently running, return that
            if currentDedupJobId is string {
                string runningId = <string>currentDedupJobId;
                DedupJob? runningJob = dedupJobs[runningId];
                if runningJob is DedupJob {
                    jobId = runningJob.jobId;
                    jobStatus = runningJob.status;
                    startedAt = runningJob.startedAt;
                    found = true;
                }
            }

            // Otherwise find the most recent job
            if !found {
                string latestStartedAt = "";
                string latestKey = "";
                foreach var [key, job] in dedupJobs.entries() {
                    if job.startedAt > latestStartedAt {
                        latestStartedAt = job.startedAt;
                        latestKey = key;
                    }
                }
                if latestKey != "" {
                    DedupJob? job = dedupJobs[latestKey];
                    if job is DedupJob {
                        jobId = job.jobId;
                        jobStatus = job.status;
                        startedAt = job.startedAt;
                        completedAt = job.completedAt ?: "";
                        errorMsg = job.errorMessage ?: "";
                        fullResult = job.result;
                        found = true;
                    }
                }
            }
        }

        if !found {
            http:Response notFound = new;
            notFound.statusCode = 404;
            notFound.setJsonPayload(errorOutcome("No dedup jobs found"));
            return notFound;
        }

        log:printInfo(string `Dedup status: ${jobStatus} (job: ${jobId})`);

        if jobStatus == "completed" {
            // 200 — done, metadata only (groups are fetched separately via GET /Patient/dedup?_count=&_offset=)
            http:Response ok = new;
            ok.statusCode = 200;
            if fullResult is DedupResult {
                ok.setJsonPayload({
                    "status": "completed",
                    "jobId": jobId,
                    "totalPatients": fullResult.totalPatients,
                    "totalGroups": fullResult.totalGroups,
                    "totalGroupedPatients": fullResult.totalGroupedPatients,
                    "threshold": <float>fullResult.threshold,
                    "timestamp": fullResult.timestamp,
                    "completedAt": completedAt
                });
            }
            return ok;
        }

        if jobStatus == "failed" {
            // 500 — failed with OperationOutcome
            http:Response failed = new;
            failed.statusCode = 500;
            failed.setJsonPayload(errorOutcome(errorMsg != "" ? errorMsg : "Deduplication failed"));
            return failed;
        }

        // 202 — pending or running, still processing
        http:Response inProgress = new;
        inProgress.statusCode = 202;
        inProgress.setHeader("X-Progress", jobStatus);
        inProgress.setHeader("Retry-After", "2");
        inProgress.setJsonPayload({"jobId": jobId, "status": jobStatus, "startedAt": startedAt});
        return inProgress;
    }

    // ========================================
    // Custom: Get Latest Dedup Results
    // GET /Patient/dedup
    // ========================================
    resource function get Patient/dedup(r4:FHIRContext ctx)
            returns json|http:Unauthorized|http:Forbidden {

        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN, ROLE_VIEWER]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }

        // _count and _offset are registered valid params in api_config.bal and passed
        // through getRequestSearchParameters() by the FHIR framework.
        map<r4:RequestSearchParameter[]> rawParams = ctx.getRequestSearchParameters();
        int count = 20;
        int offset = 0;
        r4:RequestSearchParameter[]? countParam = rawParams["_count"];
        r4:RequestSearchParameter[]? offsetParam = rawParams["_offset"];
        if countParam is r4:RequestSearchParameter[] && countParam.length() > 0 {
            int|error parsed = int:fromString(countParam[0].value);
            if parsed is int && parsed > 0 { count = parsed; }
        }
        if offsetParam is r4:RequestSearchParameter[] && offsetParam.length() > 0 {
            int|error parsed = int:fromString(offsetParam[0].value);
            if parsed is int && parsed >= 0 { offset = parsed; }
        }

        // If a job is running, tell the client
        lock {
            if dedupRunning && currentDedupJobId is string {
                return {
                    "status": "running",
                    "jobId": currentDedupJobId,
                    "message": "A deduplication job is currently in progress"
                };
            }
        }

        // Find the most recent completed job
        lock {
            string latestCompletedAt = "";
            string latestJobId = "";
            foreach var [key, job] in dedupJobs.entries() {
                if job.status == "completed" && job.result is DedupResult {
                    string completedAt = job.completedAt ?: "";
                    if completedAt > latestCompletedAt {
                        latestCompletedAt = completedAt;
                        latestJobId = key;
                    }
                }
            }
            if latestJobId != "" {
                DedupJob? found = dedupJobs[latestJobId];
                if found is DedupJob && found.result is DedupResult {
                    DedupResult r = <DedupResult>found.result;
                    int endIdx = int:min(offset + count, r.groups.length());
                    DedupGroup[] page = offset < r.groups.length() ? r.groups.slice(offset, endIdx) : [];
                    return {
                        "totalPatients": r.totalPatients,
                        "totalGroups": r.totalGroups,
                        "totalGroupedPatients": r.totalGroupedPatients,
                        "threshold": <float>r.threshold,
                        "timestamp": r.timestamp,
                        "groups": page.toJson(),
                        "_count": count,
                        "_offset": offset
                    };
                }
            }
        }

        // No jobs ever run
        return {
            "totalPatients": 0,
            "totalGroups": 0,
            "threshold": <float>dedupThreshold,
            "timestamp": getCurrentTimestamp(),
            "groups": [],
            "_count": count,
            "_offset": offset
        };
    }

    // ========================================
    // Custom: Reject Dedup Match
    // GET /Patient/dedupreject?patient1=...&patient2=...
    // Marks two patients as not-a-match by recording a pair-level decision
    // ========================================
    resource function get Patient/dedupreject(r4:FHIRContext ctx)
            returns json|http:BadRequest|http:NotFound|http:InternalServerError|http:Unauthorized|http:Forbidden {

        log:printInfo("Custom: Reject Dedup Match");

        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }
        string agentName = authResult.email;

        // Extract patient IDs from search parameters
        map<r4:RequestSearchParameter[]> rawParams = ctx.getRequestSearchParameters();
        string? pid1 = ();
        string? pid2 = ();
        foreach var [key, paramArray] in rawParams.entries() {
            if key == "patient1" && paramArray.length() > 0 {
                pid1 = paramArray[0].value;
            }
            if key == "patient2" && paramArray.length() > 0 {
                pid2 = paramArray[0].value;
            }
        }

        if pid1 is () || pid2 is () {
            return <http:BadRequest>{body: errorOutcome("Request must include patient1 and patient2 query parameters")};
        }

        if pid1 == pid2 {
            return <http:BadRequest>{body: errorOutcome("Cannot reject a patient against itself")};
        }

        string|error decisionId = rejectMatch(pid1, pid2, agentName);
        if decisionId is error {
            if decisionId is PatientNotFoundError {
                return <http:NotFound>{body: errorOutcome(decisionId.message())};
            }
            log:printError("Reject match error", decisionId);
            return <http:InternalServerError>{body: errorOutcome("Failed to reject match")};
        }

        evictRejectedGroupFromDedupCache(pid1, pid2);
        log:printInfo(string `Dedup match rejected: ${pid1} <-> ${pid2} (decision: ${decisionId})`);

        return {
            "status": "rejected",
            "patientId1": pid1,
            "patientId2": pid2,
            "decisionId": decisionId
        };
    }

    // ========================================
    // ITI-78: Read Patient
    // GET /Patient/{id}
    // ========================================
    resource function get Patient/[string id](r4:FHIRContext ctx)
            returns pdqm:PDQmPatient|http:NotFound|http:InternalServerError|http:Unauthorized|http:Forbidden {

        log:printInfo(string `ITI-78: Read Patient/${id}`);

        // Authenticate and authorize (read-only: admin + viewer)
        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN, ROLE_VIEWER]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }
        string agentName = authResult.email;

        pdqm:PDQmPatient|PatientNotFoundError|error result = getPatientById(id);
        
        if result is PatientNotFoundError {
            auditRead(id, agentName, false, string `Patient ${id} not found`);
            return <http:NotFound>{body: errorOutcome(string `Patient ${id} not found`)};
        }
        if result is error {
            log:printError("Read error", result);
            auditRead(id, agentName, false, "Read failed: " + result.message());
            return <http:InternalServerError>{body: errorOutcome("Read failed")};
        }
        
        // Audit successful read
        auditRead(id, agentName, true);
        
        return result;
    }

    // ========================================
    // ITI-78: Search Patients
    // GET /Patient?params
    // ========================================
    resource function get Patient(r4:FHIRContext ctx)
            returns r4:Bundle|http:BadRequest|http:InternalServerError|http:Unauthorized|http:Forbidden {

        log:printInfo("ITI-78: Search Patient");

        // Authenticate and authorize (read-only: admin + viewer)
        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN, ROLE_VIEWER]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }
        string agentName = authResult.email;

        map<r4:RequestSearchParameter[]> rawParams = ctx.getRequestSearchParameters();
        map<string[]> params = {};
        string[] queryParts = [];
        
        foreach var [key, paramArray] in rawParams.entries() {
            string[] values = [];
            foreach var param in paramArray {
                values.push(param.value);
                queryParts.push(string `${key}=${param.value}`);
            }
            params[key] = values;
        }
        
        string queryString = string:'join("&", ...queryParts);
        
        // Handle _id search
        string[]? idParam = params["_id"];
        if idParam is string[] && idParam.length() > 0 {
            pdqm:PDQmPatient|PatientNotFoundError|error result = getPatientById(idParam[0]);
            if result is pdqm:PDQmPatient {
                auditSearch(queryString, agentName, result.id ?: "", 1, true);
                return searchBundle([result]);
            }
            auditSearch(queryString, agentName, "", 0, true);
            return searchBundle([]);
        }
        
        // Validate search parameters - only allow supported parameters
        string[] allowedParams = ["_id", "_count", "_offset", "active", "family", "given", "identifier", "telecom",
            "birthdate", "address", "address-city", "address-country", "address-postalcode",
            "address-state", "gender", "mothersMaidenName"];
        
        foreach string paramKey in params.keys() {
            if allowedParams.indexOf(paramKey) is () {
                log:printError(string `Unsupported search parameter: ${paramKey}`);
                auditSearch(queryString, agentName, "", 0, false, string `Unsupported search parameter: ${paramKey}`);
                return <http:BadRequest>{body: errorOutcome(string `Unsupported search parameter: ${paramKey}. Supported parameters: ${string:'join(", ", ...allowedParams)}`)};
            }
        }
        
        // Build search parameters
        string? identifier = getParam(params, "identifier");
        string? family = getParam(params, "family");
        string? given = getParam(params, "given");
        string? gender = getParam(params, "gender");
        string? birthdate = getParam(params, "birthdate");
        string? telecom = getParam(params, "telecom");
        string? address = getParam(params, "address");
        string? city = getParam(params, "address-city");
        string? state = getParam(params, "address-state");
        string? postalCode = getParam(params, "address-postalcode");
        string? country = getParam(params, "address-country");
        string? mothersMaidenName = getParam(params, "mothersMaidenName");
        string? activeParam = getParam(params, "active");
        boolean active = activeParam is string ? (activeParam == "true") : true;

        // Pagination params (_count and _offset are FHIR-standard)
        string? countStr = getParam(params, "_count");
        string? offsetStr = getParam(params, "_offset");
        int count = 100;
        int offset = 0;
        if countStr is string {
            int|error parsed = int:fromString(countStr);
            if parsed is int && parsed > 0 && parsed <= 500 {
                count = parsed;
            }
        }
        if offsetStr is string {
            int|error parsed = int:fromString(offsetStr);
            if parsed is int && parsed >= 0 {
                offset = parsed;
            }
        }

        if identifier is () {
            log:printInfo("No identifier parameter provided");
        } else {
            log:printInfo(string `Search parameters: identifier=${identifier}`);
        }

        // Execute search with pagination
        pdqm:PDQmPatient[]|error results = searchPatients(
            identifier, family, given, gender, birthdate, telecom, address,
            city, state, postalCode, country, mothersMaidenName, active, count, offset
        );

        if results is error {
            log:printError("Search error", results);
            auditSearch(queryString, agentName, "", 0, false, "Search failed: " + results.message());
            return <http:InternalServerError>{body: errorOutcome("Search failed")};
        }

        // Get total count: use countFilteredPatients for demographic searches,
        // but for identifier searches just use result length (identifier is an exact match)
        int total = results.length();
        if identifier is () {
            int|error countResult = countFilteredPatients(family, given, gender, birthdate, telecom, address, city, state, postalCode, country, mothersMaidenName = mothersMaidenName, active = active);
            if countResult is int {
                total = countResult;
            }
        }

        log:printInfo(string `ITI-78: Found ${results.length()} patients (total: ${total})`);

        // Audit successful search
        string firstSearchPatientId = results.length() > 0 ? (results[0].id ?: "") : "";
        auditSearch(queryString, agentName, firstSearchPatientId, results.length(), true);

        return searchBundle(results, total);
    }
    // ========================================
    // ITI-104: Conditional Update 
    // PUT /Patient?identifier=system|value
    // ========================================
    resource function put Patient(r4:FHIRContext ctx, pdqm:PDQmPatient payload)
            returns pdqm:PDQmPatient|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError|http:Response|http:Unauthorized|http:Forbidden {

        log:printInfo("ITI-104: Conditional Update Patient");

        // Authenticate and authorize (write: admin only)
        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }
        string agentName = authResult.email;
        

    // Extract identifier from search parameters (e.g., ?identifier=system|value)
    map<r4:RequestSearchParameter[]> searchParams = ctx.getRequestSearchParameters();
        string[]? identifierParams = ();
        
        foreach var [key, paramArray] in searchParams.entries() {
            if key == "identifier" {
            string[] values = [];
            foreach var param in paramArray {
                values.push(param.value);
            }
            identifierParams = values;
            break;
            }
        }
    if identifierParams is () {
            log:printInfo("No identifier search parameter provided");
        } else {
            log:printInfo(string `Identifier search parameters: ${identifierParams.toString()}`);
        }
    
    // Extract conditional update properties from FHIR context
    anydata conditionalUpdate = ctx.getProperty("conditionalUpdate");
    anydata hasIdInPayload = ctx.getProperty("hasIdInPayload");
    anydata payloadResourceId = ctx.getProperty("payloadResourceId"); 

    log:printInfo(string `ITI-104: conditionalUpdate=${conditionalUpdate.toString()}, hasIdInPayload=${hasIdInPayload.toString()}, payloadResourceId=${payloadResourceId.toString()}`);

    if identifierParams is () || identifierParams.length() == 0 {
            auditUpdate("unknown", agentName, false, "Missing identifier search parameter");
            return <http:BadRequest>{body: errorOutcome("Missing identifier search parameter")};
        }

        string identifierParam = identifierParams[0];
        
        // Parse system|value from identifier parameter
        string system = "";
        string value = "";
        int? pipeIndex = identifierParam.indexOf("|");
        if pipeIndex is int {
            system = identifierParam.substring(0, pipeIndex);
            value = identifierParam.substring(pipeIndex + 1);
        } else {
            value = identifierParam;
        }
        
        string id = value;
        
        if system == "" || value == "" {
            auditUpdate(id, agentName, false, "Identifier must have both system and value");
            return <http:BadRequest>{body: errorOutcome("Identifier must have both system and value")};
        }

        // Validate: the identifier in the query parameter must match one of the identifiers in the request body
        boolean identifierMatchesBody = false;
        foreach pdqm:PDQmPatientIdentifier bodyId in payload.identifier {
            if bodyId.system == system && bodyId.value == value {
                identifierMatchesBody = true;
                break;
            }
        }
        if !identifierMatchesBody {
            string mismatchMsg = string `Identifier parameter ${system}|${value} does not match any identifier in the request body`;
            log:printError(mismatchMsg);
            auditUpdate(id, agentName, false, mismatchMsg);
            return <http:BadRequest>{body: errorOutcome(mismatchMsg)};
        }

        // Search for existing patient using identifier + demographics from payload body
        string? sFam = getFamily(payload);
        string? sGiv = getGiven(payload);
        string? sGen = payload.gender;
        string? sDob = payload.birthDate;
        string? sPhone = getTelecom(payload, "phone");
        string? sEmail = getTelecom(payload, "email");
        string? sTelecom = sPhone is string ? sPhone : sEmail;
        string? sCity = getAddressField(payload, "city");
        string? sState = getAddressField(payload, "state");
        string? sPostal = getAddressField(payload, "postalCode");
        string? sCountry = getAddressField(payload, "country");
        json payloadJson = payload.toJson();
        map<json>? payloadJsonMap = payloadJson is map<json> ? payloadJson : ();
        pdqm:PDQmPatient[]|error searchResults = searchPatients(
            identifier = identifierParam,
            family = sFam,
            given = sGiv,
            gender = sGen,
            birthdate = sDob,
            telecom = sTelecom,
            city = sCity,
            state = sState,
            postalCode = sPostal,
            country = sCountry,
            patientJson = payloadJsonMap
        );
        if searchResults is error {
            log:printError("Search error", searchResults);
            auditUpdate(id, agentName, false, "Search failed: " + searchResults.message());
            return <http:InternalServerError>{body: errorOutcome("Search failed")};
        }
        
        // CREATE if not found
        if searchResults.length() == 0 {
            pdqm:PDQmPatient|InvalidPatientError|DuplicatePatientError|error result = createPatient(payload);

            if result is InvalidPatientError {
                auditCreate("unknown", agentName, false, "Invalid patient: " + result.message());
                return <http:BadRequest>{body: errorOutcome(result.message())};
            }
            if result is DuplicatePatientError {
                auditCreate("unknown", agentName, false, "Duplicate patient: " + result.message());
                return <http:Conflict>{body: errorOutcome(result.message())};
            }
            if result is error {
                log:printError("Create error", result);
                auditCreate("unknown", agentName, false, "Create failed: " + result.message());
                return <http:InternalServerError>{body: errorOutcome("Create failed")};
            }
        
            log:printInfo(string `ITI-104: Created Patient/${result.id ?: ""}`);
            
            // Audit successful create
            auditCreate(result.id ?: "unknown", agentName, true);

            http:Response res = new;
            res.statusCode = 201;
            res.setHeader("Location", string `${baseUrl}/Patient/${result.id ?: ""}`);
            res.setHeader("ETag", string `W/"${result.meta?.versionId ?: "1"}"`);
            res.setJsonPayload(result.toJson());
            return res;
        }

        // ------------------------------------------------
        // ITI-104 §2.3.104.4.2: Resolve Duplicate Patient
        // Detect merge: active=false + link[type=replaced-by]
        // ------------------------------------------------
        string existingId = searchResults[0].id ?: "";

        boolean isMerge = false;
        string survivingIdentifier = "";

        if payload.active == false {
            pdqm:PDQmPatientLink[]? links = payload.link;
            if links is pdqm:PDQmPatientLink[] {
                foreach pdqm:PDQmPatientLink link in links {
                    if link.'type == pdqm:CODE_TYPE_REPLACED_BY {
                        isMerge = true;
                        // Extract surviving patient identifier from link.other
                        r4:Identifier? otherIdentifier = link.other.identifier;
                        if otherIdentifier is r4:Identifier {
                            survivingIdentifier = string `${otherIdentifier.system ?: ""}|${otherIdentifier.value ?: ""}`;
                        }
                        break;
                    }
                }
            }
        }

        if isMerge {
            log:printInfo(string `ITI-104: Resolve Duplicate — subsumed=${existingId}, surviving=${survivingIdentifier}`);

            // Validate surviving patient exists
            if survivingIdentifier == "" || survivingIdentifier == "|" {
                auditMerge(existingId, "unknown", agentName, false, "Missing surviving patient identifier in link");
                return <http:BadRequest>{body: errorOutcome("Link must contain surviving patient identifier (other.identifier)")};
            }

            pdqm:PDQmPatient[]|error survivingResults = searchPatients(identifier = survivingIdentifier);
            if survivingResults is error {
                auditMerge(existingId, survivingIdentifier, agentName, false, "Search for surviving patient failed");
                return <http:InternalServerError>{body: errorOutcome("Failed to verify surviving patient")};
            }
            if survivingResults.length() == 0 {
                auditMerge(existingId, survivingIdentifier, agentName, false, "Surviving patient not found");
                return <http:BadRequest>{body: errorOutcome(string `Surviving patient ${survivingIdentifier} not found`)};
            }

            // Resolve: mark subsumed patient inactive with replaced-by link
            pdqm:PDQmPatient|PatientNotFoundError|error resolveResult = resolvePatient(existingId, payload);
            if resolveResult is PatientNotFoundError {
                auditMerge(existingId, survivingIdentifier, agentName, false, "Subsumed patient not found");
                return <http:NotFound>{body: errorOutcome(string `Patient ${existingId} not found`)};
            }
            if resolveResult is error {
                log:printError("Resolve duplicate error", resolveResult);
                auditMerge(existingId, survivingIdentifier, agentName, false, "Resolve failed: " + resolveResult.message());
                return <http:InternalServerError>{body: errorOutcome("Resolve duplicate failed")};
            }

            evictPatientFromDedupCache(existingId);
            log:printInfo(string `ITI-104: Resolved duplicate Patient/${existingId} → replaced-by ${survivingIdentifier}`);
            auditMerge(existingId, survivingResults[0].id ?: survivingIdentifier, agentName, true);

            return resolveResult;
        }

        // ------------------------------------------------
        // Normal UPDATE if found (not a merge)
        // ------------------------------------------------
        pdqm:PDQmPatient|PatientNotFoundError|DuplicatePatientError|InvalidPatientError|error result =
            updatePatient(existingId, payload);
        
        if result is PatientNotFoundError {
            auditUpdate(existingId, agentName, false, string `Patient ${existingId} not found`);
            return <http:NotFound>{body: errorOutcome(string `Patient ${existingId} not found`)};
        }
        if result is DuplicatePatientError {
            auditUpdate(existingId, agentName, false, "Duplicate patient: " + result.message());
            return <http:Conflict>{body: errorOutcome(result.message())};
        }
        if result is InvalidPatientError {
            auditUpdate(existingId, agentName, false, "Invalid patient: " + result.message());
            return <http:BadRequest>{body: errorOutcome(result.message())};
        }
        if result is error {
            log:printError("Update error", result);
            auditUpdate(existingId, agentName, false, "Update failed: " + result.message());
            return <http:InternalServerError>{body: errorOutcome("Update failed")};
        }
        
        log:printInfo(string `ITI-104: Updated Patient/${existingId}`);
        
        // Audit successful update
        auditUpdate(existingId, agentName, true);
        
        return result;
    }


    // ========================================
    // ITI-104: Delete Patient (soft delete)
    // DELETE /Patient/{id}
    // ========================================
    resource function delete Patient(r4:FHIRContext ctx)
            returns http:NoContent|http:InternalServerError|http:BadRequest|http:NotFound|http:Unauthorized|http:Forbidden {

        // Authenticate and authorize (write: admin only)
        AuthUser|AuthenticationError|AuthorizationError authResult = authenticateAndAuthorize(ctx, [ROLE_ADMIN]);
        if authResult is AuthenticationError {
            return <http:Unauthorized>{body: errorOutcome(authResult.message())};
        }
        if authResult is AuthorizationError {
            return <http:Forbidden>{body: errorOutcome(authResult.message())};
        }
        string agentName = authResult.email;

        // Extract identifier from search parameters (e.g., ?identifier=system|value)
        r4:RequestSearchParameter[]? searchParams = ctx.getRequestSearchParameter("identifier");
        string[]? identifierParams = ();
        
        if searchParams is (){
            log:printInfo("No identifier search parameter provided");
            return <http:BadRequest>{body: errorOutcome("Missing identifier search parameter")};
        } 
        string[] values = [];
        foreach var param in searchParams {
            values.push(param.value);
        }
        identifierParams = values;
        log:printInfo(string `Identifier search parameters: ${identifierParams.toString()}`);
        
        if identifierParams is () || identifierParams.length() == 0 {
            auditDelete("unknown", agentName, false, "Missing identifier search parameter");
            return <http:BadRequest>{body: errorOutcome("Missing identifier search parameter")};
        }
        
        string identifierParam = identifierParams[0];
        
        // Parse system|value from identifier parameter
        string system = "";
        string value = "";
        int? pipeIndex = identifierParam.indexOf("|");
        if pipeIndex is int {
            system = identifierParam.substring(0, pipeIndex);
            value = identifierParam.substring(pipeIndex + 1);
        } else {
            value = identifierParam;
        }
        
        string id = value;
        
        if system == "" || value == "" {
            auditDelete(id, agentName, false, "Identifier must have both system and value");
            return <http:BadRequest>{body: errorOutcome("Identifier must have both system and value")};
        }

        // Search for existing patient by identifier
        pdqm:PDQmPatient[]|error searchResults = searchPatients(identifierParam);
        if searchResults is error {
            log:printError("Search error", searchResults);
            auditDelete(id, agentName, false, "Search failed: " + searchResults.message());
            return <http:InternalServerError>{body: errorOutcome("Search failed")};
        }

        if searchResults.length() == 0 {
            auditDelete(id, agentName, false, string `Patient with identifier ${identifierParam} not found`);
            return <http:NotFound>{body: errorOutcome(string `Patient with identifier ${identifierParam} not found`)};
        }

        string CRUID = searchResults[0].id ?: "";
        if CRUID == "" {
            auditDelete("unknown", agentName, false, "Patient record has no ID");
            return <http:BadRequest>{body: errorOutcome("Patient record has no ID")};
        }

        log:printInfo(string `ITI-104: Delete Patient/${CRUID}`);
        
        boolean|PatientNotFoundError|error result = deletePatient(CRUID);
        
        if result is PatientNotFoundError {
            auditDelete(CRUID, agentName, false, string `Patient ${CRUID} not found`);
            return <http:NotFound>{body: errorOutcome(string `Patient ${CRUID} not found`)};
        }
        if result is error {
            log:printError("Delete error", result);
            auditDelete(CRUID, agentName, false, "Delete failed: " + result.message());
            return <http:InternalServerError>{body: errorOutcome("Delete failed")};
        }
        
        log:printInfo(string `ITI-104: Deleted Patient/${CRUID}`);
        
        // Audit successful delete
        auditDelete(CRUID, agentName, true);
        
        return <http:NoContent>{};
    }

    // ========================================
    // Capabilities Interaction (FHIR §3.2.0.10)
    // GET /fhir/r4/metadata
    // ITI-104 §2.3.104.4.1.3: SHALL advertise conditionalUpdate on Patient
    // ========================================
    resource function get metadata(r4:FHIRContext ctx) returns json {
        return {
            "resourceType": "CapabilityStatement",
            "id": "openhie-cr-capabilities",
            "name": "OpenHIEClientRegistryCapabilities",
            "title": "OpenHIE Client Registry Capability Statement",
            "status": "active",
            "experimental": false,
            "date": "2025-01-01",
            "publisher": "OpenHIE",
            "description": "Capability Statement for the OpenHIE Client Registry. Implements IHE ITI-78 (PDQm), ITI-104 (PIXm Feed), and ITI-119 (Patient Match).",
            "kind": "instance",
            "fhirVersion": "4.0.1",
            "format": ["application/fhir+json", "json"],
            "implementationGuide": [
                "https://profiles.ihe.net/ITI/PDQm/ImplementationGuide/ihe.iti.pdqm",
                "https://profiles.ihe.net/ITI/PIXm/ImplementationGuide/ihe.iti.pixm"
            ],
            "rest": [
                {
                    "mode": "server",
                    "resource": [
                        {
                            "type": "Patient",
                            "profile": "https://profiles.ihe.net/ITI/PDQm/StructureDefinition/IHE.PDQm.Patient",
                            "interaction": [
                                {"code": "read"},
                                {"code": "search-type"},
                                {"code": "update"},
                                {"code": "delete"}
                            ],
                            // ITI-104 §2.3.104.4.1.3: conditionalUpdate SHALL be true
                            "conditionalUpdate": true,
                            // ITI-104 §2.3.104.4.1.3: conditionalDelete SHALL be advertised when Remove Patient is supported
                            "conditionalDelete": "single",
                            "searchParam": [
                                {"name": "identifier",       "type": "string"}
                            ],
                            "operation": [
                                {
                                    "name": "match",
                                    "definition": "http://hl7.org/fhir/OperationDefinition/Patient-match"
                                }
                            ]
                        }
                    ]
                }
            ]
        };
    }
}

// ============================================================
// HELPER FUNCTIONS
// ============================================================

function getParam(map<string[]> params, string name) returns string? {
    string[]? values = params[name];
    if values is string[] && values.length() > 0 {
        return values[0];
    }
    return ();
}

function searchBundle(pdqm:PDQmPatient[] patients, int? total = ()) returns r4:Bundle {
    r4:BundleEntry[] entries = [];
    foreach pdqm:PDQmPatient p in patients {
        entries.push({
            fullUrl: string `${baseUrl}/Patient/${p.id ?: ""}`,
            'resource: p,
            search: {mode: "match"}
        });
    }
    return {
        resourceType: "Bundle",
        id: uuid:createType1AsString(),
        'type: "searchset",
        total: total ?: entries.length(),
        entry: entries
    };
}

function errorOutcome(string message) returns json {
    return {
        "resourceType": "OperationOutcome",
        "issue": [{"severity": "error", "code": "processing", "diagnostics": message}]
    };
}

function createErrorResponse(int statusCode, string message) returns http:Response {
    http:Response response = new;
    response.statusCode = statusCode;
    response.setJsonPayload(errorOutcome(message));
    return response;
}
