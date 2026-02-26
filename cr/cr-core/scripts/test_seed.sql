SET AUTOCOMMIT FALSE;

CREATE TABLE IF NOT EXISTS patients (
    id VARCHAR(64) PRIMARY KEY,
    resource_json CLOB NOT NULL,
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
);

CREATE TABLE IF NOT EXISTS identifiers (
    row_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id VARCHAR(64) NOT NULL,
    system VARCHAR(500) NOT NULL,
    "value" VARCHAR(500) NOT NULL,
    FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
    UNIQUE (system, "value")
);

CREATE TABLE IF NOT EXISTS blocking_keys (
    row_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id VARCHAR(64) NOT NULL,
    block_type VARCHAR(30) NOT NULL,
    block_value VARCHAR(255) NOT NULL,
    FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
);

INSERT INTO patients (
    id, resource_json, active, family_name, given_name, gender, birth_date,
    phone, email, city, state, postal_code, country, created_at, updated_at,
    version, blocking_keys_at
)
SELECT
    'seed-' || RIGHT('0000000' || CAST(X AS VARCHAR), 7) AS id,
    '{"resourceType":"Patient","id":"seed-' || RIGHT('0000000' || CAST(X AS VARCHAR), 7) || '"}' AS resource_json,
    TRUE AS active,
    'Family' || RIGHT('0000' || CAST(MOD(X, 5000) AS VARCHAR), 4) AS family_name,
    'Given' || RIGHT('0000000' || CAST(X AS VARCHAR), 7) AS given_name,
    CASE WHEN MOD(X, 2) = 0 THEN 'male' ELSE 'female' END AS gender,
    FORMATDATETIME(DATEADD('DAY', MOD(X, 20000), DATE '1960-01-01'), 'yyyy-MM-dd') AS birth_date,
    '+9477' || RIGHT('00000000' || CAST(X AS VARCHAR), 8) AS phone,
    'patient' || CAST(X AS VARCHAR) || '@seed.local' AS email,
    'Colombo' AS city,
    'Western' AS state,
    '10001' AS postal_code,
    'LK' AS country,
    '2026-02-26T00:00:00Z' AS created_at,
    '2026-02-26T00:00:00Z' AS updated_at,
    1 AS version,
    '2026-02-26T00:00:00Z' AS blocking_keys_at
FROM SYSTEM_RANGE(1, 5);

SELECT id, birth_date, phone FROM patients;

INSERT INTO identifiers (patient_id, system, "value")
SELECT
    p.id,
    'http://seed.local/mr' AS system,
    REPLACE(p.id, 'seed-', 'MR-') AS "value"
FROM patients p
WHERE p.id LIKE 'seed-%';

INSERT INTO blocking_keys (patient_id, block_type, block_value)
SELECT
    p.id,
    'SDX_FAM_DOB',
    SOUNDEX(p.family_name) || '|' || p.birth_date
FROM patients p
WHERE p.active = TRUE AND p.family_name IS NOT NULL AND p.birth_date IS NOT NULL AND p.id LIKE 'seed-%';

INSERT INTO blocking_keys (patient_id, block_type, block_value)
SELECT
    p.id,
    'PHONE',
    REGEXP_REPLACE(p.phone, '[^0-9]', '')
FROM patients p
WHERE p.active = TRUE AND p.phone IS NOT NULL AND LENGTH(TRIM(p.phone)) > 0 AND p.id LIKE 'seed-%';

COMMIT;
SELECT COUNT(*) AS seeded_patients FROM patients WHERE id LIKE 'seed-%';
SELECT COUNT(*) AS seeded_identifiers FROM identifiers WHERE patient_id LIKE 'seed-%';
SELECT COUNT(*) AS seeded_blocking_keys FROM blocking_keys WHERE patient_id LIKE 'seed-%';
