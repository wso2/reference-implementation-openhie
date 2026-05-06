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

// Database Provider Interface
// ===========================
// Abstracts database-specific SQL so developers can switch between
// H2 (embedded, default) and PostgreSQL by changing dbType in Config.toml.

import ballerina/sql;
import ballerinax/java.jdbc;

# Database provider interface — implemented by H2DatabaseProvider and PostgreSQLDatabaseProvider.
public type DatabaseProvider object {

    # Initialize the full database schema (all tables + indexes).
    # + dbClient - active JDBC client
    # + return - error if schema creation fails
    public function initSchema(jdbc:Client dbClient) returns error?;

    # Returns an upsert query for the dedup_compared_pairs table.
    # H2 uses MERGE INTO; PostgreSQL uses INSERT ... ON CONFLICT DO UPDATE.
    # + pid1 - first patient ID
    # + pid2 - second patient ID
    # + now  - ISO timestamp string
    # + score - matching score
    # + return - parameterized upsert query
    public function getUpsertComparePair(
        string pid1, string pid2, string now, decimal score
    ) returns sql:ParameterizedQuery;

    # Returns an upsert query for the dedup_pair_decisions table.
    # H2 uses MERGE INTO; PostgreSQL uses INSERT ... ON CONFLICT DO UPDATE.
    # + pid1       - first patient ID (normalized, always ≤ pid2)
    # + pid2       - second patient ID
    # + decisionId - generated UUID for this decision
    # + now        - ISO timestamp string (used for created_at, updated_at, resolved_at)
    # + rejectedBy - user/agent performing the rejection
    # + return     - parameterized upsert query
    public function getUpsertPairDecision(
        string pid1, string pid2, string decisionId, string now, string rejectedBy
    ) returns sql:ParameterizedQuery;

    # Returns the database type identifier ("h2" or "postgresql").
    public function getDatabaseType() returns string;
};
