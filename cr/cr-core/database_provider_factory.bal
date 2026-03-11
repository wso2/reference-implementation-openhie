// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0

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
