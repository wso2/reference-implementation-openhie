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

// Comprehensive Matching Algorithm Unit Tests
// ============================================
// Tests for calculateScore, phone normalization in scoring (bug regression guard),
// individual field contributions, composite scores, algorithm variants, match grades,
// blocking key ↔ scoring consistency, and edge cases.
//
// These are pure unit tests — no running service required.

import ballerina/test;
import ballerinax/health.fhir.r4.ihe.pdqm320 as pdqm;
import ballerinax/health.fhir.r4;

// ============================================================
// SECTION 1: PHONE NORMALIZATION IN SCORING (bug regression guard)
// Prior bug: blocking keys used normalizePhone(), but calculateScore() did not.
// Two patients with the same number in different formats were found as candidates
// via the PHONE blocking key but scored 0.0 on phone because raw strings differed.
// ============================================================

@test:Config {}
function testPhoneScoringDifferentFormats() {
    // Same number, different formatting — phone MUST contribute to score after fix
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "PHONE-A1"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "+1 (555) 123-4567"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "PHONE-B1"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "555-123-4567"}]
    };
    decimal score = calculateScore(a, b);
    // Phone weight is 0.05; score must be >= 0.05 if phone matched
    test:assertTrue(score >= 0.05d,
        msg = string `Phone match across formats should contribute 0.05, got ${score}`);
}

@test:Config {}
function testPhoneScoringIdenticalRaw() {
    // Identical raw phone string — phone must match
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "PHONE-A2"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "5551234567"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "PHONE-B2"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "5551234567"}]
    };
    decimal score = calculateScore(a, b);
    test:assertTrue(score >= 0.05d,
        msg = string `Identical raw phone should contribute 0.05, got ${score}`);
}

@test:Config {}
function testPhoneScoringMismatch() {
    // Completely different phone numbers — phone must NOT contribute
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "PHONE-A3"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "5551111111"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "PHONE-B3"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "5552222222"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.0d,
        msg = string `Different phone numbers should give score 0.0, got ${score}`);
}

@test:Config {}
function testPhoneScoringMissingPhone() {
    // One patient has no phone — phone must be skipped without error
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "PHONE-A4"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "5551234567"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "PHONE-B4"}]
        // no telecom
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.0d,
        msg = string `Missing phone on one side should yield 0.0, got ${score}`);
}

@test:Config {}
function testPhoneNormalizationInternationalConsistency() {
    // Two representations of the same number with the same country code
    // must normalize to the same digit string
    string norm1 = normalizePhone("+94 77 123 4567");
    string norm2 = normalizePhone("+94771234567");
    test:assertEquals(norm1, norm2,
        msg = string `Both formats of same international number should normalize equally`);
}

// ============================================================
// SECTION 2: INDIVIDUAL FIELD SCORE CONTRIBUTIONS
// Each test creates two patients that differ in all fields except one
// and asserts score == that field's configured weight.
// ============================================================

@test:Config {}
function testScoreIdentifierOnly() {
    // Only the identifier matches (weight 0.30)
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:shared", value: "ID-001"}],
        name: [<r4:HumanName>{family: "Alpha"}],
        birthDate: "1980-01-01",
        gender: "male"
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:shared", value: "ID-001"}],
        name: [<r4:HumanName>{family: "Beta"}],
        birthDate: "1990-06-15",
        gender: "female"
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.30d,
        msg = string `Identifier-only match should score 0.30, got ${score}`);
}

@test:Config {}
function testScoreIdentifierSystemMismatch() {
    // Same value but different system — must NOT match
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:system-a", value: "ID-001"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:system-b", value: "ID-001"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.0d,
        msg = string `Same value, different system should not match, got ${score}`);
}

@test:Config {}
function testScoreFamilyNameOnly() {
    // Only family name matches (weight 0.20)
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "FAM-A"}],
        name: [<r4:HumanName>{family: "Johnson"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "FAM-B"}],
        name: [<r4:HumanName>{family: "Johnson"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.20d,
        msg = string `Family-only match should score 0.20, got ${score}`);
}

@test:Config {}
function testScoreGivenNameOnly() {
    // Only given name matches (weight 0.15)
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "GIV-A"}],
        name: [<r4:HumanName>{family: "Alpha", given: ["Alice"]}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "GIV-B"}],
        name: [<r4:HumanName>{family: "Beta", given: ["Alice"]}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.15d,
        msg = string `Given-only match should score 0.15, got ${score}`);
}

@test:Config {}
function testScoreBirthDateOnly() {
    // Only birthDate matches (weight 0.20)
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "DOB-A"}],
        name: [<r4:HumanName>{family: "Alpha"}],
        birthDate: "1985-03-20"
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "DOB-B"}],
        name: [<r4:HumanName>{family: "Beta"}],
        birthDate: "1985-03-20"
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.20d,
        msg = string `BirthDate-only match should score 0.20, got ${score}`);
}

@test:Config {}
function testScoreGenderOnly() {
    // Only gender matches (weight 0.05)
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "GEN-A"}],
        birthDate: "1970-01-01",
        gender: "male"
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "GEN-B"}],
        birthDate: "1990-12-31",
        gender: "male"
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.05d,
        msg = string `Gender-only match should score 0.05, got ${score}`);
}

@test:Config {}
function testScorePhoneOnly() {
    // Only phone matches (weight 0.05) — verifies the bug fix end-to-end
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "PH-A"}],
        name: [<r4:HumanName>{family: "Alpha", given: ["Ann"]}],
        birthDate: "1970-01-01",
        gender: "female",
        telecom: [<r4:ContactPoint>{system: "phone", value: "2125551234"}],
        address: [<r4:Address>{postalCode: "10001"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "PH-B"}],
        name: [<r4:HumanName>{family: "Beta", given: ["Bob"]}],
        birthDate: "1990-06-15",
        gender: "male",
        telecom: [<r4:ContactPoint>{system: "phone", value: "(212) 555-1234"}],
        address: [<r4:Address>{postalCode: "90210"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.05d,
        msg = string `Phone-only match (normalized) should score 0.05, got ${score}`);
}

@test:Config {}
function testScorePostalCodeOnly() {
    // Only postal code matches (weight 0.05)
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "ZIP-A"}],
        address: [<r4:Address>{postalCode: "12345"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "ZIP-B"}],
        address: [<r4:Address>{postalCode: "12345"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.05d,
        msg = string `PostalCode-only match should score 0.05, got ${score}`);
}

// ============================================================
// SECTION 3: COMPOSITE SCORE SCENARIOS
// ============================================================

@test:Config {}
function testScoreNameAndDOB() {
    // family (0.20) + given (0.15) + birthDate (0.20) = 0.55
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "COMP-A1"}],
        name: [<r4:HumanName>{family: "Williams", given: ["Sarah"]}],
        birthDate: "1992-07-04",
        gender: "male"
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "COMP-B1"}],
        name: [<r4:HumanName>{family: "Williams", given: ["Sarah"]}],
        birthDate: "1992-07-04",
        gender: "female"
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.55d,
        msg = string `family+given+DOB should score 0.55, got ${score}`);
}

@test:Config {}
function testScoreNameDOBGender() {
    // family (0.20) + given (0.15) + birthDate (0.20) + gender (0.05) = 0.60
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "COMP-A2"}],
        name: [<r4:HumanName>{family: "Brown", given: ["James"]}],
        birthDate: "1975-11-22",
        gender: "male"
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "COMP-B2"}],
        name: [<r4:HumanName>{family: "Brown", given: ["James"]}],
        birthDate: "1975-11-22",
        gender: "male"
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.60d,
        msg = string `family+given+DOB+gender should score 0.60, got ${score}`);
    test:assertEquals(getMatchGrade(score), "possible");
}

@test:Config {}
function testScorePhonePlusNames() {
    // phone (0.05) + family (0.20) + given (0.15) = 0.40
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "COMP-A3"}],
        name: [<r4:HumanName>{family: "Davis", given: ["Emily"]}],
        birthDate: "1960-01-01",
        telecom: [<r4:ContactPoint>{system: "phone", value: "4155559999"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "COMP-B3"}],
        name: [<r4:HumanName>{family: "Davis", given: ["Emily"]}],
        birthDate: "1980-12-31",
        telecom: [<r4:ContactPoint>{system: "phone", value: "(415) 555-9999"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.40d,
        msg = string `phone+family+given should score 0.40, got ${score}`);
}

@test:Config {}
function testScorePhonePlusNamesAndDOB() {
    // phone (0.05) + family (0.20) + given (0.15) + DOB (0.20) = 0.60
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "COMP-A4"}],
        name: [<r4:HumanName>{family: "Garcia", given: ["Luis"]}],
        birthDate: "1988-05-15",
        gender: "female",
        telecom: [<r4:ContactPoint>{system: "phone", value: "3105550000"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "COMP-B4"}],
        name: [<r4:HumanName>{family: "Garcia", given: ["Luis"]}],
        birthDate: "1988-05-15",
        gender: "male",
        telecom: [<r4:ContactPoint>{system: "phone", value: "310-555-0000"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.60d,
        msg = string `phone+family+given+DOB should score 0.60, got ${score}`);
    test:assertEquals(getMatchGrade(score), "possible");
}

@test:Config {}
function testScoreAllFieldsMatch() {
    // All fields match → score = 1.0, grade = "certain"
    pdqm:PDQmPatient p = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "FULL-001"}],
        name: [<r4:HumanName>{family: "Taylor", given: ["Chris"]}],
        birthDate: "1995-08-20",
        gender: "male",
        telecom: [<r4:ContactPoint>{system: "phone", value: "6175554321"}],
        address: [<r4:Address>{postalCode: "02101"}]
    };
    decimal score = calculateScore(p, p);
    test:assertEquals(score, 1.0d,
        msg = string `Identical patient should score 1.0, got ${score}`);
    test:assertEquals(getMatchGrade(score), "certain");
}

@test:Config {}
function testScoreNoFieldsMatch() {
    // Nothing in common → 0.0, grade = "certainly-not"
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "NONE-A"}],
        name: [<r4:HumanName>{family: "Alpha", given: ["Ann"]}],
        birthDate: "1970-01-01",
        gender: "female",
        telecom: [<r4:ContactPoint>{system: "phone", value: "1111111111"}],
        address: [<r4:Address>{postalCode: "00001"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "NONE-B"}],
        name: [<r4:HumanName>{family: "Zeta", given: ["Zara"]}],
        birthDate: "2000-12-31",
        gender: "male",
        telecom: [<r4:ContactPoint>{system: "phone", value: "9999999999"}],
        address: [<r4:Address>{postalCode: "99999"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.0d,
        msg = string `No matching fields should score 0.0, got ${score}`);
    test:assertEquals(getMatchGrade(score), "certainly-not");
}

@test:Config {}
function testScoreIdentifierPlusDOBAndName() {
    // identifier (0.30) + family (0.20) + given (0.15) + DOB (0.20) = 0.85 → "probable"
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:shared", value: "COMB-001"}],
        name: [<r4:HumanName>{family: "Martinez", given: ["Rosa"]}],
        birthDate: "2001-03-10",
        gender: "male"
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:shared", value: "COMB-001"}],
        name: [<r4:HumanName>{family: "Martinez", given: ["Rosa"]}],
        birthDate: "2001-03-10",
        gender: "female"
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.85d,
        msg = string `identifier+family+given+DOB should score 0.85, got ${score}`);
    test:assertEquals(getMatchGrade(score), "probable");
}

// ============================================================
// SECTION 4: ALGORITHM VARIANTS PER FIELD
// These test compareField() directly with different FieldConfig settings.
// ============================================================

@test:Config {}
function testAlgoExactMatchNormalized() {
    // Exact match on normalized phone digits
    FieldConfig cfg = {weight: 0.05d, algorithm: "exact"};
    test:assertEquals(compareField("5551234567", "5551234567", cfg), 1.0d);
}

@test:Config {}
function testAlgoExactMismatch() {
    // Different strings → 0.0
    FieldConfig cfg = {weight: 0.05d, algorithm: "exact"};
    test:assertEquals(compareField("5551234567", "5559876543", cfg), 0.0d);
}

@test:Config {}
function testAlgoExactCaseInsensitive() {
    // Exact algorithm is case-insensitive (toLowerAscii)
    FieldConfig cfg = {weight: 0.20d, algorithm: "exact"};
    test:assertEquals(compareField("SMITH", "smith", cfg), 1.0d);
    test:assertEquals(compareField("Male", "male", cfg), 1.0d);
}

@test:Config {}
function testAlgoLevenshteinCloseMatch() {
    // "Micheal" vs "Michael" — 1 edit, sim > 0.70
    FieldConfig cfg = {weight: 0.20d, algorithm: "levenshtein", levenshteinThreshold: 0.70d};
    decimal sim = compareField("Micheal", "Michael", cfg);
    test:assertTrue(sim > 0.0d,
        msg = string `Levenshtein('Micheal','Michael') at 0.70 threshold should pass, got ${sim}`);
}

@test:Config {}
function testAlgoLevenshteinDistantFail() {
    // "Smith" vs "Jones" — very different, must not pass at threshold 0.70
    FieldConfig cfg = {weight: 0.20d, algorithm: "levenshtein", levenshteinThreshold: 0.70d};
    test:assertEquals(compareField("Smith", "Jones", cfg), 0.0d);
}

@test:Config {}
function testAlgoLevenshteinHighThresholdFail() {
    // Even a close pair may fail at a strict threshold
    FieldConfig cfg = {weight: 0.20d, algorithm: "levenshtein", levenshteinThreshold: 0.99d};
    decimal sim = compareField("Smith", "Smyth", cfg);
    // "Smith"/"Smyth" have edit distance 1, maxLen=5, sim=0.8 — below 0.99
    test:assertEquals(sim, 0.0d);
}

@test:Config {}
function testAlgoSoundexPhoneticMatch() {
    // "Robert" and "Rupert" share Soundex code R163
    FieldConfig cfg = {weight: 0.20d, algorithm: "soundex"};
    test:assertEquals(compareField("Robert", "Rupert", cfg), 1.0d);
}

@test:Config {}
function testAlgoSoundexPhoneticEquivalent() {
    // "Smith" and "Smyth" — phonetically equivalent
    FieldConfig cfg = {weight: 0.20d, algorithm: "soundex"};
    test:assertEquals(compareField("Smith", "Smyth", cfg), 1.0d,
        msg = "Smith and Smyth should soundex-match");
}

@test:Config {}
function testAlgoSoundexDistinctFail() {
    // "Smith" vs "Jones" — different Soundex codes
    FieldConfig cfg = {weight: 0.20d, algorithm: "soundex"};
    test:assertEquals(compareField("Smith", "Jones", cfg), 0.0d);
}

@test:Config {}
function testAlgoJaroWinklerCloseMatch() {
    // "Martha" vs "Marhta" — JW ≈ 0.961 > default threshold 0.85
    FieldConfig cfg = {weight: 0.20d, algorithm: "jarowinkler"};
    decimal sim = compareField("Martha", "Marhta", cfg);
    test:assertTrue(sim > 0.0d,
        msg = string `JW('Martha','Marhta') should pass default threshold, got ${sim}`);
}

@test:Config {}
function testAlgoJaroWinklerHighThresholdFail() {
    // Very high threshold — "Smith" vs "Jones" must not pass
    FieldConfig cfg = {weight: 0.20d, algorithm: "jarowinkler", jaroWinklerThreshold: 0.99d};
    test:assertEquals(compareField("Smith", "Jones", cfg), 0.0d);
}

@test:Config {}
function testValidateFieldAlgorithmRejectsUnknown() {
    // validateFieldAlgorithm must return an error for unsupported algorithm names
    error? result = validateFieldAlgorithm("family", "fuzzy");
    test:assertTrue(result is error, msg = "Expected error for unknown algorithm 'fuzzy'");
}

// ============================================================
// SECTION 5: MATCH GRADE ASSIGNMENT
// ============================================================

@test:Config {}
function testMatchGradeCertainBoundary() {
    test:assertEquals(getMatchGrade(0.95d), "certain", msg = "0.95 → certain");
    test:assertEquals(getMatchGrade(1.0d), "certain", msg = "1.0 → certain");
}

@test:Config {}
function testMatchGradeProbableBoundary() {
    test:assertEquals(getMatchGrade(0.80d), "probable", msg = "0.80 → probable");
    test:assertEquals(getMatchGrade(0.94d), "probable", msg = "0.94 → probable");
}

@test:Config {}
function testMatchGradePossibleBoundary() {
    test:assertEquals(getMatchGrade(0.60d), "possible", msg = "0.60 → possible");
    test:assertEquals(getMatchGrade(0.79d), "possible", msg = "0.79 → possible");
}

@test:Config {}
function testMatchGradeCertainlyNotBoundary() {
    test:assertEquals(getMatchGrade(0.59d), "certainly-not", msg = "0.59 → certainly-not");
    test:assertEquals(getMatchGrade(0.0d), "certainly-not", msg = "0.0 → certainly-not");
}

@test:Config {}
function testMatchGradeAtExactThresholds() {
    // Boundary values must map to their UPPER grade (≥ is inclusive)
    test:assertEquals(getMatchGrade(0.60d), "possible", msg = "0.60 inclusive → possible");
    test:assertEquals(getMatchGrade(0.80d), "probable", msg = "0.80 inclusive → probable");
    test:assertEquals(getMatchGrade(0.95d), "certain", msg = "0.95 inclusive → certain");
}

// ============================================================
// SECTION 6: BLOCKING KEY ↔ SCORING CONSISTENCY
// Verifies that the same normalization is used in both stages
// so candidates found via blocking also score non-zero.
// ============================================================

@test:Config {}
function testPhoneBlockingAndScoringConsistency() {
    // Same phone number, different raw formats
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "BK-A"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "+1 (800) 555-0100"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "BK-B"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "8005550100"}]
    };

    // 1. Blocking keys must match
    string? phoneKeyA = ();
    string? phoneKeyB = ();
    foreach BlockingKey k in computeBlockingKeys(a, [["urn:test", "BK-A"]]) {
        if k.blockType == "PHONE" { phoneKeyA = k.blockValue; }
    }
    foreach BlockingKey k in computeBlockingKeys(b, [["urn:test", "BK-B"]]) {
        if k.blockType == "PHONE" { phoneKeyB = k.blockValue; }
    }
    test:assertTrue(phoneKeyA is string, msg = "Patient A must have a PHONE blocking key");
    test:assertTrue(phoneKeyB is string, msg = "Patient B must have a PHONE blocking key");
    test:assertEquals(phoneKeyA, phoneKeyB, msg = "PHONE blocking keys must match");

    // 2. Score must include phone contribution (>= 0.05)
    decimal score = calculateScore(a, b);
    test:assertTrue(score >= 0.05d,
        msg = string `Score must include phone contribution (>= 0.05), got ${score}`);
}

@test:Config {}
function testPhoneVariantsProduceSameBlockKey() {
    // Three formatting variants of the same number → identical PHONE block_value
    pdqm:PDQmPatient p1 = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "VAR-1"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "212-555-1234"}]
    };
    pdqm:PDQmPatient p2 = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "VAR-2"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "(212) 555-1234"}]
    };
    pdqm:PDQmPatient p3 = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "VAR-3"}],
        telecom: [<r4:ContactPoint>{system: "phone", value: "+12125551234"}]
    };

    string? v1 = ();
    string? v2 = ();
    string? v3 = ();
    foreach BlockingKey k in computeBlockingKeys(p1, [["urn:test", "VAR-1"]]) {
        if k.blockType == "PHONE" { v1 = k.blockValue; }
    }
    foreach BlockingKey k in computeBlockingKeys(p2, [["urn:test", "VAR-2"]]) {
        if k.blockType == "PHONE" { v2 = k.blockValue; }
    }
    foreach BlockingKey k in computeBlockingKeys(p3, [["urn:test", "VAR-3"]]) {
        if k.blockType == "PHONE" { v3 = k.blockValue; }
    }

    test:assertEquals(v1, v2, msg = "Variant 1 and 2 PHONE keys must match");
    test:assertEquals(v2, v3, msg = "Variant 2 and 3 PHONE keys must match");
}

@test:Config {}
function testNamePhoneticBlockingAndScoringConsistency() {
    // "Smith" and "Smyth" produce the same SDX_FAM_DOB blocking key (phonetic).
    // When soundex is configured for family field, compareField also returns 1.0.
    pdqm:PDQmPatient p1 = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "SDX-1"}],
        name: [<r4:HumanName>{family: "Smith"}],
        birthDate: "1990-01-01"
    };
    pdqm:PDQmPatient p2 = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "SDX-2"}],
        name: [<r4:HumanName>{family: "Smyth"}],
        birthDate: "1990-01-01"
    };

    string? sdx1 = ();
    string? sdx2 = ();
    foreach BlockingKey k in computeBlockingKeys(p1, [["urn:test", "SDX-1"]]) {
        if k.blockType == "SDX_FAM_DOB" { sdx1 = k.blockValue; }
    }
    foreach BlockingKey k in computeBlockingKeys(p2, [["urn:test", "SDX-2"]]) {
        if k.blockType == "SDX_FAM_DOB" { sdx2 = k.blockValue; }
    }
    test:assertEquals(sdx1, sdx2,
        msg = "Smith and Smyth must share the same SDX_FAM_DOB blocking key");

    // Soundex algorithm scores them as matching
    FieldConfig soundexCfg = {weight: 0.20d, algorithm: "soundex"};
    test:assertEquals(compareField("Smith", "Smyth", soundexCfg), 1.0d,
        msg = "compareField(soundex) should return 1.0 for Smith vs Smyth");
}

// ============================================================
// SECTION 7: EDGE CASES AND BOUNDARY CONDITIONS
// ============================================================

@test:Config {}
function testScoreMinimalDifferentPatients() {
    // Only different identifiers — score 0.0
    pdqm:PDQmPatient a = {resourceType: "Patient", identifier: [{system: "urn:a", value: "MIN-1"}]};
    pdqm:PDQmPatient b = {resourceType: "Patient", identifier: [{system: "urn:b", value: "MIN-2"}]};
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.0d,
        msg = string `Minimal different patients should score 0.0, got ${score}`);
}

@test:Config {}
function testScoreIdenticalPatientObject() {
    // Passing the same object twice → 1.0
    pdqm:PDQmPatient p = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "SELF-001"}],
        name: [<r4:HumanName>{family: "Lee", given: ["Alex"]}],
        birthDate: "1993-04-12",
        gender: "female",
        telecom: [<r4:ContactPoint>{system: "phone", value: "5055554321"}],
        address: [<r4:Address>{postalCode: "87101"}]
    };
    decimal score = calculateScore(p, p);
    test:assertEquals(score, 1.0d,
        msg = string `Same patient vs itself should score 1.0, got ${score}`);
}

@test:Config {}
function testScoreMultipleIdentifiersOneMatch() {
    // Patient A has 3 identifiers, only the second one matches patient B.
    // Identifier scoring must count it exactly once.
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [
            {system: "urn:x", value: "X001"},
            {system: "urn:shared", value: "SHARED-1"},
            {system: "urn:z", value: "Z999"}
        ]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:shared", value: "SHARED-1"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.30d,
        msg = string `Multi-identifier match must score 0.30 exactly once, got ${score}`);
}

@test:Config {}
function testScoreNoTelecomVsEmptyTelecom() {
    // Absent vs empty telecom array — no panic, phone skipped, score = 0.0
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "urn:a", value: "TEL-A"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:b", value: "TEL-B"}],
        telecom: []
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.0d,
        msg = string `Missing/empty telecom should not panic and score 0.0, got ${score}`);
}

@test:Config {}
function testScoreGenderCaseInsensitive() {
    // exact algorithm uses toLowerAscii — "MALE" vs "male" should match
    // Tested via compareField since PDQmPatientGender only accepts lowercase values
    FieldConfig cfg = {weight: 0.05d, algorithm: "exact"};
    test:assertEquals(compareField("MALE", "male", cfg), 1.0d,
        msg = "exact algo must be case-insensitive: 'MALE' vs 'male' should match");
    test:assertEquals(compareField("FEMALE", "female", cfg), 1.0d,
        msg = "exact algo must be case-insensitive: 'FEMALE' vs 'female' should match");
}

@test:Config {}
function testScoreIdentifierCaseSensitive() {
    // Identifier system/value comparison uses strict == (not toLowerAscii)
    // "URN:TEST" vs "urn:test" — must NOT match
    pdqm:PDQmPatient a = {
        resourceType: "Patient",
        identifier: [{system: "URN:TEST", value: "ID-UPPER"}]
    };
    pdqm:PDQmPatient b = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "ID-UPPER"}]
    };
    decimal score = calculateScore(a, b);
    test:assertEquals(score, 0.0d,
        msg = string `Identifier system comparison must be case-sensitive, got ${score}`);
}

@test:Config {}
function testScoreCappedAtOne() {
    // Score must never exceed 1.0 (capped in calculateScore)
    pdqm:PDQmPatient p = {
        resourceType: "Patient",
        identifier: [{system: "urn:cap", value: "CAP-001"}],
        name: [<r4:HumanName>{family: "King", given: ["Sam"]}],
        birthDate: "2000-01-01",
        gender: "male",
        telecom: [<r4:ContactPoint>{system: "phone", value: "9998887777"}],
        address: [<r4:Address>{postalCode: "55555"}]
    };
    decimal score = calculateScore(p, p);
    test:assertTrue(score <= 1.0d,
        msg = string `Score must be capped at 1.0, got ${score}`);
    test:assertEquals(score, 1.0d);
}

@test:Config {}
function testNormalizePhoneAllDigits() {
    // Plain digit string stays unchanged
    test:assertEquals(normalizePhone("2125551234"), "2125551234");
}

@test:Config {}
function testNormalizePhoneEmptyString() {
    // Empty input → empty output, no panic
    test:assertEquals(normalizePhone(""), "");
}

@test:Config {}
function testNormalizePhoneLettersOnly() {
    // No digits → empty result
    test:assertEquals(normalizePhone("abc-def"), "");
}
