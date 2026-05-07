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

// Authentication & Authorization for Client Registry
// ===================================================
// Validates Bearer tokens and checks role-based permissions.
// Currently works with simulated JWT (base64-encoded JSON).
// To upgrade to real JWT: replace decodeToken() with proper JWT validation.

import ballerina/io;
import ballerina/log;
import ballerina/mime;
import ballerina/time;
import ballerinax/health.fhir.r4;

// Authenticated user record
type AuthUser record {|
    string email;
    string role;
|};

// Auth error types
type AuthenticationError distinct error;
type AuthorizationError distinct error;

// Role constants
const string ROLE_ADMIN = "admin";
const string ROLE_VIEWER = "viewer";

# Authenticate the request and authorize against allowed roles.
#
# + ctx - The FHIR context object (provides access to request headers)
# + allowedRoles - Roles permitted for this endpoint
# + return - AuthUser on success, or auth error
function authenticateAndAuthorize(r4:FHIRContext ctx, string[] allowedRoles)
        returns AuthUser|AuthenticationError|AuthorizationError {

    // Extract Authorization header from FHIR context's HTTP request
    r4:HTTPRequest? httpReq = ctx.getHTTPRequest();
    if httpReq is () {
        log:printError("Auth failed: No HTTP request in context");
        return error AuthenticationError("Missing HTTP request");
    }

    // Look up Authorization header (case-insensitive — HTTP headers may be lowercased)
    string[]? authValues = ();
    foreach var [key, vals] in httpReq.headers.entries() {
        if key.toLowerAscii() == "authorization" {
            authValues = vals;
            break;
        }
    }
    if authValues is () || authValues.length() == 0 {
        log:printError("Auth failed: Missing Authorization header");
        return error AuthenticationError("Missing Authorization header");
    }

    string authHeader = authValues[0];

    // Check Bearer prefix
    if !authHeader.startsWith("Bearer ") {
        log:printError("Auth failed: Invalid Authorization format");
        return error AuthenticationError("Invalid Authorization header format");
    }

    string token = authHeader.substring(7);

    // Decode token
    AuthUser|AuthenticationError user = decodeToken(token);
    if user is AuthenticationError {
        return user;
    }

    // Check role authorization
    if allowedRoles.indexOf(user.role) is () {
        log:printError(string `Authorization failed: role '${user.role}' not in ${allowedRoles.toString()}`);
        return error AuthorizationError(
            string `Insufficient permissions. Required roles: ${allowedRoles.toString()}`
        );
    }

    log:printInfo(string `Authenticated: ${user.email} [${user.role}]`);
    return user;
}

# Decode a simulated JWT token (base64-encoded JSON).
# Replace this function with real JWT verification when ready.
#
# + token - The base64-encoded token string
# + return - AuthUser on success, or AuthenticationError
function decodeToken(string token) returns AuthUser|AuthenticationError {

    // Base64 decode
    string|byte[]|io:ReadableByteChannel|mime:DecodeError decoded = mime:base64Decode(token);
    if decoded is mime:DecodeError|io:ReadableByteChannel {
        log:printError("Auth failed: Invalid token encoding");
        return error AuthenticationError("Invalid token encoding");
    }

    string jsonStr;
    if decoded is byte[] {
        string|error str = string:fromBytes(decoded);
        if str is error {
            log:printError("Auth failed: Invalid token bytes");
            return error AuthenticationError("Invalid token content");
        }
        jsonStr = str;
    } else {
        jsonStr = decoded;
    }

    json|error payload = jsonStr.fromJsonString();
    if payload is error {
        log:printError("Auth failed: Invalid token JSON");
        return error AuthenticationError("Invalid token payload");
    }

    // Extract claims
    json|error subField = payload.sub;
    json|error roleField = payload.role;
    json|error expField = payload.exp;

    if subField is error || roleField is error {
        log:printError("Auth failed: Missing required claims (sub, role)");
        return error AuthenticationError("Missing required token claims");
    }

    string email = subField.toString();
    string role = roleField.toString();

    // Validate role value
    if role != ROLE_ADMIN && role != ROLE_VIEWER {
        log:printError(string `Auth failed: Unknown role '${role}'`);
        return error AuthenticationError(string `Unknown role: ${role}`);
    }

    // Check expiration
    if expField is json {
        int|error exp = expField.cloneWithType();
        if exp is int {
            int currentTimeMs = time:utcNow()[0] * 1000;
            if exp < currentTimeMs {
                log:printError("Auth failed: Token expired");
                return error AuthenticationError("Token expired");
            }
        }
    }

    return {email, role};
}

