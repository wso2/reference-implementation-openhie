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

// Database Provider Factory
// =========================
// Returns the correct DatabaseProvider implementation based on the
// configured dbType string. Add new providers here as needed.

import ballerina/log;

# Supported database types.
public enum DatabaseType {
    H2 = "h2",
    POSTGRESQL = "postgresql"
}

# Create and return a DatabaseProvider matching the given type string.
# Accepts "h2" (default) or "postgresql" / "postgres".
#
# + dbType - value of the dbType configurable (case-insensitive)
# + return - DatabaseProvider instance or error if the type is unsupported
public function getDatabaseProvider(string dbType) returns DatabaseProvider|error {
    match dbType.toLowerAscii().trim() {
        "h2" => {
            log:printInfo("Database provider: H2 (embedded)");
            return new H2DatabaseProvider();
        }
        "postgresql"|"postgres" => {
            log:printInfo("Database provider: PostgreSQL");
            return new PostgreSQLDatabaseProvider();
        }
        _ => {
            string msg = string `Unsupported dbType: "${dbType}". Supported values: "h2", "postgresql"`;
            log:printError(msg);
            return error(msg);
        }
    }
}
