// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0

// PostgreSQL Database Provider
// ============================
// Implements DatabaseProvider for PostgreSQL.
// Used when dbType = "postgresql".
//
// SQL differences from H2:
//   CLOB          → TEXT
//   AUTO_INCREMENT → SERIAL (built into column type)
//   MERGE INTO    → INSERT ... ON CONFLICT DO UPDATE

import ballerina/sql;
import ballerinax/java.jdbc;

public class PostgreSQLDatabaseProvider {
    *DatabaseProvider;

    public function initSchema(jdbc:Client dbClient) returns error? {
        // Patients table
        _ = check dbClient->execute(`
            CREATE TABLE IF NOT EXISTS patients (
                id VARCHAR(64) PRIMARY KEY,
                resource_json TEXT NOT NULL,
                active BOOLEAN DEFAULT TRUE,
                family_name VARCHAR(255),
                given_name VARCHAR(255),
                gender VARCHAR(20),
                birth_date VARCHAR(10),
                phone VARCHAR(50),
                email VARCHAR(255),
                city VARCHAR(100),
                state VARCHAR(100),
                postal_code VARCHAR(20),
                country VARCHAR(100),
                created_at VARCHAR(30),
                updated_at VARCHAR(30),
                version INT DEFAULT 1,
                blocking_keys_at VARCHAR(30)
            )
        `);

        // Identifiers table
        _ = check dbClient->execute(`
            CREATE TABLE IF NOT EXISTS identifiers (
                row_id SERIAL PRIMARY KEY,
                patient_id VARCHAR(64) NOT NULL,
                system VARCHAR(500) NOT NULL,
                value VARCHAR(500) NOT NULL,
                FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
                UNIQUE (system, value)
            )
        `);

        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_ident_patient ON identifiers(patient_id)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_family ON patients(family_name)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_given ON patients(given_name)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_dob ON patients(birth_date)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_gender ON patients(gender)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_active ON patients(active)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_updated_at ON patients(updated_at)`);

        // Blocking keys table
        _ = check dbClient->execute(`
            CREATE TABLE IF NOT EXISTS blocking_keys (
                row_id SERIAL PRIMARY KEY,
                patient_id VARCHAR(64) NOT NULL,
                block_type VARCHAR(30) NOT NULL,
                block_value VARCHAR(255) NOT NULL,
                FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
            )
        `);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_block_lookup ON blocking_keys(block_type, block_value)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_block_patient ON blocking_keys(patient_id)`);

        // Dedup compared pairs table
        _ = check dbClient->execute(`
            CREATE TABLE IF NOT EXISTS dedup_compared_pairs (
                patient_id_1 VARCHAR(64) NOT NULL,
                patient_id_2 VARCHAR(64) NOT NULL,
                compared_at VARCHAR(30) NOT NULL,
                score DECIMAL(5,4),
                PRIMARY KEY (patient_id_1, patient_id_2)
            )
        `);

        // Dedup pair decisions table
        _ = check dbClient->execute(`
            CREATE TABLE IF NOT EXISTS dedup_pair_decisions (
                patient_id_1 VARCHAR(64) NOT NULL,
                patient_id_2 VARCHAR(64) NOT NULL,
                decision_id VARCHAR(64) NOT NULL,
                status VARCHAR(30) NOT NULL,
                active BOOLEAN DEFAULT TRUE,
                created_at VARCHAR(30) NOT NULL,
                updated_at VARCHAR(30) NOT NULL,
                resolved_at VARCHAR(30),
                created_by VARCHAR(255),
                resolved_by VARCHAR(255),
                resolution_reason VARCHAR(255),
                PRIMARY KEY (patient_id_1, patient_id_2),
                FOREIGN KEY (patient_id_1) REFERENCES patients(id) ON DELETE CASCADE,
                FOREIGN KEY (patient_id_2) REFERENCES patients(id) ON DELETE CASCADE
            )
        `);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_pair_decisions_p1_status ON dedup_pair_decisions(patient_id_1, status)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_pair_decisions_p2_status ON dedup_pair_decisions(patient_id_2, status)`);
        _ = check dbClient->execute(`CREATE INDEX IF NOT EXISTS idx_pair_decisions_active ON dedup_pair_decisions(active)`);
    }

    public function getUpsertComparePair(
        string pid1, string pid2, string now, decimal score
    ) returns sql:ParameterizedQuery {
        return `INSERT INTO dedup_compared_pairs (patient_id_1, patient_id_2, compared_at, score)
                VALUES (${pid1}, ${pid2}, ${now}, ${score})
                ON CONFLICT (patient_id_1, patient_id_2) DO UPDATE
                SET compared_at = EXCLUDED.compared_at, score = EXCLUDED.score`;
    }

    public function getUpsertPairDecision(
        string pid1, string pid2, string decisionId, string now, string rejectedBy
    ) returns sql:ParameterizedQuery {
        return `INSERT INTO dedup_pair_decisions (
                    patient_id_1, patient_id_2, decision_id, status, active,
                    created_at, updated_at, resolved_at, created_by, resolved_by, resolution_reason
                ) VALUES (
                    ${pid1}, ${pid2}, ${decisionId}, 'rejected', false,
                    ${now}, ${now}, ${now}, ${rejectedBy}, ${rejectedBy}, 'manual_not_a_match'
                )
                ON CONFLICT (patient_id_1, patient_id_2) DO UPDATE SET
                    decision_id       = ${decisionId},
                    status            = 'rejected',
                    active            = false,
                    updated_at        = ${now},
                    resolved_at       = ${now},
                    resolved_by       = ${rejectedBy},
                    resolution_reason = 'manual_not_a_match'`;
    }

    public function getDatabaseType() returns string => "postgresql";
}
