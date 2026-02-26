-- Direct H2 seeder for 1,000,000 PDQm-style patients
-- Target schema: cr-core/db_repository.bal initDatabase()
--
-- Run with the MPI service stopped (to avoid H2 file lock conflicts).
-- DB URL in this repo is typically: jdbc:h2:file:./data/mpi;AUTO_SERVER=TRUE
--
-- Usage (H2 Shell example):
--   java -cp h2*.jar org.h2.tools.Shell -url "jdbc:h2:file:./data/mpi" -user sa -password "" -sql "RUNSCRIPT FROM 'cr-core/scripts/seed_1m_pdqm_patients_h2.sql'"
--
-- Notes:
-- - This script assumes an empty/fresh database.
-- - It inserts:
--   1) patients
--   2) identifiers (1 official MRN per patient)
--   3) blocking_keys (all current block types used by the app)
-- - Generated data is synthetic but valid FHIR Patient JSON for this project.

SET AUTOCOMMIT FALSE;

-- Optional safety checks (uncomment if you want to verify emptiness before insert)
-- SELECT COUNT(*) AS patients_before FROM patients;
-- SELECT COUNT(*) AS identifiers_before FROM identifiers;
-- SELECT COUNT(*) AS blocking_before FROM blocking_keys;

INSERT INTO patients (
    id,
    resource_json,
    active,
    family_name,
    given_name,
    gender,
    birth_date,
    phone,
    email,
    city,
    state,
    postal_code,
    country,
    created_at,
    updated_at,
    version,
    blocking_keys_at
)
SELECT
    'seed-' || RIGHT('0000000' || CAST(X AS VARCHAR), 7) AS id,
    '{' ||
      '"resourceType":"Patient",' ||
      '"id":"seed-' || RIGHT('0000000' || CAST(X AS VARCHAR), 7) || '",' ||
      '"identifier":[{' ||
        '"use":"official",' ||
        '"system":"http://seed.local/mr",' ||
        '"value":"MR-' || RIGHT('0000000' || CAST(X AS VARCHAR), 7) || '"' ||
      '}],' ||
      '"active":true,' ||
      '"name":[{' ||
        '"use":"official",' ||
        '"family":"Family' || RIGHT('0000' || CAST(MOD(X, 5000) AS VARCHAR), 4) || '",' ||
        '"given":["Given' || RIGHT('0000000' || CAST(X AS VARCHAR), 7) || '"]' ||
      '}],' ||
      '"telecom":[' ||
        '{"system":"phone","value":"+9477' || RIGHT('00000000' || CAST(X AS VARCHAR), 8) || '","use":"mobile"},' ||
        '{"system":"email","value":"patient' || CAST(X AS VARCHAR) || '@seed.local","use":"home"}' ||
      '],' ||
      '"gender":"' || CASE WHEN MOD(X, 2) = 0 THEN 'male' ELSE 'female' END || '",' ||
      '"birthDate":"' || FORMATDATETIME(DATEADD('DAY', MOD(X, 20000), DATE '1960-01-01'), 'yyyy-MM-dd') || '",' ||
      '"address":[{' ||
        '"use":"home",' ||
        '"line":["No. ' || CAST(MOD(X, 500) + 1 AS VARCHAR) || ', Seed Street"],' ||
        '"city":"' ||
          CASE MOD(X, 6)
            WHEN 0 THEN 'Colombo'
            WHEN 1 THEN 'Kandy'
            WHEN 2 THEN 'Galle'
            WHEN 3 THEN 'Jaffna'
            WHEN 4 THEN 'Kurunegala'
            ELSE 'Matara'
          END || '",' ||
        '"district":"' ||
          CASE MOD(X, 6)
            WHEN 0 THEN 'Western'
            WHEN 1 THEN 'Central'
            WHEN 2 THEN 'Southern'
            WHEN 3 THEN 'Northern'
            WHEN 4 THEN 'North Western'
            ELSE 'Southern'
          END || '",' ||
        '"postalCode":"' || RIGHT('00000' || CAST(10000 + MOD(X, 90000) AS VARCHAR), 5) || '",' ||
        '"country":"LK"' ||
      '}],' ||
      '"meta":{' ||
        '"versionId":"1",' ||
        '"lastUpdated":"2026-02-26T00:00:00Z"' ||
      '}' ||
    '}' AS resource_json,
    TRUE AS active,
    'Family' || RIGHT('0000' || CAST(MOD(X, 5000) AS VARCHAR), 4) AS family_name,
    'Given' || RIGHT('0000000' || CAST(X AS VARCHAR), 7) AS given_name,
    CASE WHEN MOD(X, 2) = 0 THEN 'male' ELSE 'female' END AS gender,
    FORMATDATETIME(DATEADD('DAY', MOD(X, 20000), DATE '1960-01-01'), 'yyyy-MM-dd') AS birth_date,
    '+9477' || RIGHT('00000000' || CAST(X AS VARCHAR), 8) AS phone,
    'patient' || CAST(X AS VARCHAR) || '@seed.local' AS email,
    CASE MOD(X, 6)
      WHEN 0 THEN 'Colombo'
      WHEN 1 THEN 'Kandy'
      WHEN 2 THEN 'Galle'
      WHEN 3 THEN 'Jaffna'
      WHEN 4 THEN 'Kurunegala'
      ELSE 'Matara'
    END AS city,
    CASE MOD(X, 6)
      WHEN 0 THEN 'Western'
      WHEN 1 THEN 'Central'
      WHEN 2 THEN 'Southern'
      WHEN 3 THEN 'Northern'
      WHEN 4 THEN 'North Western'
      ELSE 'Southern'
    END AS state,
    RIGHT('00000' || CAST(10000 + MOD(X, 90000) AS VARCHAR), 5) AS postal_code,
    'LK' AS country,
    '2026-02-26T00:00:00Z' AS created_at,
    '2026-02-26T00:00:00Z' AS updated_at,
    1 AS version,
    '2026-02-26T00:00:00Z' AS blocking_keys_at
FROM SYSTEM_RANGE(1, 1000000);

INSERT INTO identifiers (patient_id, system, "value")
SELECT
    p.id,
    'http://seed.local/mr' AS system,
    REPLACE(p.id, 'seed-', 'MR-') AS "value"
FROM patients p
WHERE p.id LIKE 'seed-%';

-- Blocking key type 1: Soundex(family) + DOB
INSERT INTO blocking_keys (patient_id, block_type, block_value)
SELECT
    p.id,
    'SDX_FAM_DOB',
    SOUNDEX(p.family_name) || '|' || p.birth_date
FROM patients p
WHERE p.active = TRUE
  AND p.family_name IS NOT NULL
  AND p.birth_date IS NOT NULL
  AND p.id LIKE 'seed-%';

-- Blocking key type 2: Soundex(given) + DOB + gender
INSERT INTO blocking_keys (patient_id, block_type, block_value)
SELECT
    p.id,
    'SDX_GIV_DOB_GEN',
    SOUNDEX(p.given_name) || '|' || p.birth_date || '|' || p.gender
FROM patients p
WHERE p.active = TRUE
  AND p.given_name IS NOT NULL
  AND p.birth_date IS NOT NULL
  AND p.gender IS NOT NULL
  AND p.id LIKE 'seed-%';

-- Blocking key type 3: DOB + gender + postal code
INSERT INTO blocking_keys (patient_id, block_type, block_value)
SELECT
    p.id,
    'DOB_GEN_ZIP',
    p.birth_date || '|' || p.gender || '|' || p.postal_code
FROM patients p
WHERE p.active = TRUE
  AND p.birth_date IS NOT NULL
  AND p.gender IS NOT NULL
  AND p.postal_code IS NOT NULL
  AND p.id LIKE 'seed-%';

-- Blocking key type 4: Phone (normalized digits only)
INSERT INTO blocking_keys (patient_id, block_type, block_value)
SELECT
    p.id,
    'PHONE',
    REGEXP_REPLACE(p.phone, '[^0-9]', '')
FROM patients p
WHERE p.active = TRUE
  AND p.phone IS NOT NULL
  AND LENGTH(TRIM(p.phone)) > 0
  AND p.id LIKE 'seed-%';

-- Blocking key type 5: Identifier exact key
INSERT INTO blocking_keys (patient_id, block_type, block_value)
SELECT
    i.patient_id,
    'IDENT',
    i.system || '|' || i."value"
FROM identifiers i
WHERE i.patient_id LIKE 'seed-%';

COMMIT;

-- Verification
SELECT COUNT(*) AS seeded_patients FROM patients WHERE id LIKE 'seed-%';
SELECT COUNT(*) AS seeded_identifiers FROM identifiers WHERE patient_id LIKE 'seed-%';
SELECT COUNT(*) AS seeded_blocking_keys FROM blocking_keys WHERE patient_id LIKE 'seed-%';
