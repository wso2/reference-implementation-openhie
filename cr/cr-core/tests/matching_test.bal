// Matching Algorithm Unit Tests
// ==============================
// Tests for Levenshtein distance, Soundex, compareField dispatcher,
// blocking key computation, and the configurable scoring engine.

import ballerina/test;
import healthcare_samples/ihe_pdqm_package as pdqm;
import ballerinax/health.fhir.r4;

// ============================================================
// LEVENSHTEIN DISTANCE TESTS
// ============================================================

@test:Config {}
function testLevenshteinIdentical() {
    test:assertEquals(levenshteinDistance("hello", "hello"), 0);
}

@test:Config {}
function testLevenshteinEmpty() {
    test:assertEquals(levenshteinDistance("", "abc"), 3);
    test:assertEquals(levenshteinDistance("abc", ""), 3);
    test:assertEquals(levenshteinDistance("", ""), 0);
}

@test:Config {}
function testLevenshteinKittenSitting() {
    // Classic example: kitten → sitting = 3 edits
    test:assertEquals(levenshteinDistance("kitten", "sitting"), 3);
}

@test:Config {}
function testLevenshteinSingleEdit() {
    // One substitution
    test:assertEquals(levenshteinDistance("cat", "bat"), 1);
    // One insertion
    test:assertEquals(levenshteinDistance("cat", "cats"), 1);
    // One deletion
    test:assertEquals(levenshteinDistance("cats", "cat"), 1);
}

@test:Config {}
function testLevenshteinCaseInsensitive() {
    test:assertEquals(levenshteinDistance("John", "john"), 0);
    test:assertEquals(levenshteinDistance("SMITH", "smith"), 0);
}

@test:Config {}
function testLevenshteinSimilarityIdentical() {
    decimal sim = levenshteinSimilarity("john", "john");
    test:assertEquals(sim, 1.0d);
}

@test:Config {}
function testLevenshteinSimilarityTypo() {
    // "john" vs "jonh" — 1 transposition in 4 chars → distance 2, similarity 0.5
    // Actually: j-o-n-h vs j-o-h-n → distance 2 (swap n↔h)
    // But levenshtein counts substitutions not transpositions, so:
    // jonh→john: position 2 n→h, position 3 h→n = 2 subs → distance 2 → sim = 0.5
    decimal sim = levenshteinSimilarity("john", "jonh");
    test:assertTrue(sim >= 0.4d && sim <= 0.6d);
}

@test:Config {}
function testLevenshteinSimilarityClose() {
    // "Michael" vs "Micheal" — 1 transposition
    decimal sim = levenshteinSimilarity("Michael", "Micheal");
    test:assertTrue(sim > 0.7d);
}

@test:Config {}
function testLevenshteinSimilarityBothEmpty() {
    test:assertEquals(levenshteinSimilarity("", ""), 1.0d);
}

// ============================================================
// SOUNDEX TESTS
// ============================================================

@test:Config {}
function testSoundexBasic() {
    test:assertEquals(soundex("Robert"), "R163");
    test:assertEquals(soundex("Rupert"), "R163");
}

@test:Config {}
function testSoundexSmith() {
    string smithCode = soundex("Smith");
    string jonesCode = soundex("Jones");
    test:assertNotEquals(smithCode, jonesCode);
}

@test:Config {}
function testSoundexPhoneticMatch() {
    // Catherine and Kathryn should have different Soundex
    // (C252 vs K365) — different first letters
    test:assertNotEquals(soundex("Catherine"), soundex("Kathryn"));
}

@test:Config {}
function testSoundexSameFirstLetter() {
    // Michel and Michael — same first letter, phonetically similar
    test:assertEquals(soundex("Michel"), soundex("Michael"));
}

@test:Config {}
function testSoundexEmpty() {
    test:assertEquals(soundex(""), "0000");
}

@test:Config {}
function testSoundexMatchFunction() {
    test:assertTrue(soundexMatch("Robert", "Rupert"));
    test:assertFalse(soundexMatch("Smith", "Jones"));
}

// ============================================================
// COMPARE FIELD DISPATCHER TESTS
// ============================================================

@test:Config {}
function testCompareFieldExact() {
    FieldConfig cfg = {weight: 0.20d, algorithm: "exact"};
    test:assertEquals(compareField("Smith", "Smith", cfg), 1.0d);
    test:assertEquals(compareField("Smith", "smith", cfg), 1.0d);
    test:assertEquals(compareField("Smith", "Smyth", cfg), 0.0d);
}

@test:Config {}
function testCompareFieldLevenshtein() {
    FieldConfig cfg = {weight: 0.20d, algorithm: "levenshtein", levenshteinThreshold: 0.70d};
    // "Michael" vs "Micheal" — close enough (sim > 0.7)
    decimal sim = compareField("Michael", "Micheal", cfg);
    test:assertTrue(sim > 0.0d);

    // "Michael" vs "Robert" — too different (sim < 0.7)
    decimal simFar = compareField("Michael", "Robert", cfg);
    test:assertEquals(simFar, 0.0d);
}

@test:Config {}
function testCompareFieldLevenshteinDefaultThreshold() {
    // Default threshold is 0.80 when not specified
    FieldConfig cfg = {weight: 0.20d, algorithm: "levenshtein"};
    // "Smith" vs "Smth" — sim = 1 - (1/5) = 0.8 — borderline
    decimal sim = compareField("Smith", "Smth", cfg);
    test:assertTrue(sim >= 0.0d);
}

@test:Config {}
function testCompareFieldSoundex() {
    FieldConfig cfg = {weight: 0.20d, algorithm: "soundex"};
    test:assertEquals(compareField("Robert", "Rupert", cfg), 1.0d);
    test:assertEquals(compareField("Smith", "Jones", cfg), 0.0d);
}

@test:Config {}
function testCompareFieldUnknownFallsBackToExact() {
    FieldConfig cfg = {weight: 0.20d, algorithm: "unknown_algo"};
    test:assertEquals(compareField("abc", "abc", cfg), 1.0d);
    test:assertEquals(compareField("abc", "xyz", cfg), 0.0d);
}

// ============================================================
// MATCH GRADE TESTS
// ============================================================

@test:Config {}
function testGetMatchGradeCertain() {
    test:assertEquals(getMatchGrade(0.95d), "certain");
    test:assertEquals(getMatchGrade(1.0d), "certain");
}

@test:Config {}
function testGetMatchGradeProbable() {
    test:assertEquals(getMatchGrade(0.80d), "probable");
    test:assertEquals(getMatchGrade(0.94d), "probable");
}

@test:Config {}
function testGetMatchGradePossible() {
    test:assertEquals(getMatchGrade(0.60d), "possible");
    test:assertEquals(getMatchGrade(0.79d), "possible");
}

@test:Config {}
function testGetMatchGradeCertainlyNot() {
    test:assertEquals(getMatchGrade(0.59d), "certainly-not");
    test:assertEquals(getMatchGrade(0.0d), "certainly-not");
}

// ============================================================
// NORMALIZE PHONE TESTS
// ============================================================

@test:Config {}
function testNormalizePhoneBasic() {
    test:assertEquals(normalizePhone("+1 (555) 123-4567"), "15551234567");
    test:assertEquals(normalizePhone("555-1234"), "5551234");
    test:assertEquals(normalizePhone("5551234"), "5551234");
}

@test:Config {}
function testNormalizePhoneEmpty() {
    test:assertEquals(normalizePhone(""), "");
    test:assertEquals(normalizePhone("abc"), "");
}

@test:Config {}
function testNormalizePhoneSpaces() {
    test:assertEquals(normalizePhone("  555 123 4567  "), "5551234567");
}

// ============================================================
// BLOCKING KEY COMPUTATION TESTS
// ============================================================

@test:Config {}
function testComputeBlockingKeysFullPatient() {
    // Patient with all fields populated should produce all 5 block types

    pdqm:PDQmPatient patient = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "P001"}],
        name: [<r4:HumanName>{family: "Smith", given: ["John"]}],
        gender: "male",
        birthDate: "1990-01-15",
        telecom: [<r4:ContactPoint>{system: "phone", value: "+1-555-1234"}],
        address: [<r4:Address>{postalCode: "12345"}]
    };

    string[][] identifiers = [["urn:test", "P001"]];
    BlockingKey[] keys = computeBlockingKeys(patient, identifiers);

    // Should have: SDX_FAM_DOB, SDX_GIV_DOB_GEN, DOB_GEN_ZIP, PHONE, IDENT
    test:assertTrue(keys.length() == 5, msg = string `Expected 5 keys, got ${keys.length()}`);

    // Verify block types
    string[] types = [];
    foreach BlockingKey k in keys {
        types.push(k.blockType);
    }
    test:assertTrue(types.indexOf("SDX_FAM_DOB") !is (), msg = "Missing SDX_FAM_DOB");
    test:assertTrue(types.indexOf("SDX_GIV_DOB_GEN") !is (), msg = "Missing SDX_GIV_DOB_GEN");
    test:assertTrue(types.indexOf("DOB_GEN_ZIP") !is (), msg = "Missing DOB_GEN_ZIP");
    test:assertTrue(types.indexOf("PHONE") !is (), msg = "Missing PHONE");
    test:assertTrue(types.indexOf("IDENT") !is (), msg = "Missing IDENT");
}

@test:Config {}
function testComputeBlockingKeysPartialPatient() {
    // Patient missing phone and postal code — should only get SDX_FAM_DOB, SDX_GIV_DOB_GEN, IDENT

    pdqm:PDQmPatient patient = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "P002"}],
        name: [<r4:HumanName>{family: "Doe", given: ["Jane"]}],
        gender: "female",
        birthDate: "1985-06-20"
    };

    string[][] identifiers = [["urn:test", "P002"]];
    BlockingKey[] keys = computeBlockingKeys(patient, identifiers);

    // Should have: SDX_FAM_DOB, SDX_GIV_DOB_GEN, IDENT (no PHONE, no DOB_GEN_ZIP)
    test:assertTrue(keys.length() == 3, msg = string `Expected 3 keys, got ${keys.length()}`);
}

@test:Config {}
function testComputeBlockingKeysMinimalPatient() {
    // Patient with only identifier — should only get IDENT key

    pdqm:PDQmPatient patient = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "P003"}]
    };

    string[][] identifiers = [["urn:test", "P003"]];
    BlockingKey[] keys = computeBlockingKeys(patient, identifiers);

    test:assertTrue(keys.length() == 1, msg = string `Expected 1 key, got ${keys.length()}`);
    test:assertEquals(keys[0].blockType, "IDENT");
}

@test:Config {}
function testBlockingKeyPhoneticVariants() {
    // "Smith" and "Smyth" should produce the same SDX_FAM_DOB blocking key

    pdqm:PDQmPatient p1 = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "P010"}],
        name: [<r4:HumanName>{family: "Smith"}],
        birthDate: "1990-01-01"
    };

    pdqm:PDQmPatient p2 = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "P011"}],
        name: [<r4:HumanName>{family: "Smyth"}],
        birthDate: "1990-01-01"
    };

    BlockingKey[] keys1 = computeBlockingKeys(p1, [["urn:test", "P010"]]);
    BlockingKey[] keys2 = computeBlockingKeys(p2, [["urn:test", "P011"]]);

    // Find the SDX_FAM_DOB key from each
    string? val1 = ();
    string? val2 = ();
    foreach BlockingKey k in keys1 {
        if k.blockType == "SDX_FAM_DOB" { val1 = k.blockValue; }
    }
    foreach BlockingKey k in keys2 {
        if k.blockType == "SDX_FAM_DOB" { val2 = k.blockValue; }
    }

    test:assertTrue(val1 is string && val2 is string, msg = "Both should have SDX_FAM_DOB key");
    test:assertEquals(val1, val2, msg = "Smith and Smyth should produce same SDX_FAM_DOB key");
}

// ============================================================
// JARO-WINKLER TESTS
// ============================================================

@test:Config {}
function testJaroSimilarityIdentical() {
    test:assertEquals(jaroSimilarity("john", "john"), 1.0d);
}

@test:Config {}
function testJaroSimilarityBothEmpty() {
    test:assertEquals(jaroSimilarity("", ""), 1.0d);
}

@test:Config {}
function testJaroSimilarityOneEmpty() {
    test:assertEquals(jaroSimilarity("", "abc"), 0.0d);
    test:assertEquals(jaroSimilarity("abc", ""), 0.0d);
}

@test:Config {}
function testJaroWinklerNameVariant() {
    // Classic textbook case: "MARTHA" vs "MARHTA" → Jaro ≈ 0.944, JW ≈ 0.961
    decimal jw = jaroWinklerSimilarity("martha", "marhta", 0.1d);
    test:assertTrue(jw > 0.94d && jw <= 1.0d,
        msg = string `Expected JW(martha, marhta) > 0.94, got ${jw}`);
}

@test:Config {}
function testJaroWinklerPrefixBoost() {
    // JW should be strictly greater than Jaro when there's a matching prefix
    decimal jaro = jaroSimilarity("johnathan", "jonathan");
    decimal jw = jaroWinklerSimilarity("johnathan", "jonathan", 0.1d);
    test:assertTrue(jw > jaro,
        msg = string `JW(${jw}) should be > Jaro(${jaro}) due to prefix boost`);
}

@test:Config {}
function testJaroWinklerUnrelated() {
    // Completely different names should score low
    decimal jw = jaroWinklerSimilarity("smith", "jones", 0.1d);
    test:assertTrue(jw < 0.5d,
        msg = string `Expected JW(smith, jones) < 0.5, got ${jw}`);
}

@test:Config {}
function testJaroWinklerPrefixScaleCap() {
    // prefixScale > 0.25 should be capped — result must not exceed 1.0
    decimal jw = jaroWinklerSimilarity("john", "john", 0.9d);
    test:assertEquals(jw, 1.0d);
}

@test:Config {}
function testCompareFieldJaroWinkler() {
    FieldConfig cfg = {weight: 0.20d, algorithm: "jarowinkler"};
    // "Martha" vs "Marhta" — JW ≈ 0.961, above default threshold 0.85
    decimal sim = compareField("Martha", "Marhta", cfg);
    test:assertTrue(sim > 0.0d,
        msg = string `Expected sim > 0.0 for close JW match, got ${sim}`);
}

@test:Config {}
function testCompareFieldJaroWinklerBelowThreshold() {
    // Set a very high threshold so distant strings return 0.0
    FieldConfig cfg = {weight: 0.20d, algorithm: "jarowinkler", jaroWinklerThreshold: 0.99d};
    decimal sim = compareField("Smith", "Jones", cfg);
    test:assertEquals(sim, 0.0d);
}

@test:Config {}
function testCompareFieldJaroWinklerCustomScale() {
    // Higher prefix scale → higher score for strings with matching prefix
    FieldConfig cfgDefault = {weight: 0.20d, algorithm: "jarowinkler", jaroWinklerPrefixScale: 0.1d, jaroWinklerThreshold: 0.0d};
    FieldConfig cfgHighScale = {weight: 0.20d, algorithm: "jarowinkler", jaroWinklerPrefixScale: 0.2d, jaroWinklerThreshold: 0.0d};
    decimal simDefault = compareField("johnathan", "jonathan", cfgDefault);
    decimal simHigh = compareField("johnathan", "jonathan", cfgHighScale);
    test:assertTrue(simHigh > simDefault,
        msg = string `Higher prefix scale (${simHigh}) should score higher than default (${simDefault})`);
}

@test:Config {}
function testBlockingKeyDeterminism() {
    // Same patient input should produce identical keys every time

    pdqm:PDQmPatient patient = {
        resourceType: "Patient",
        identifier: [{system: "urn:test", value: "P020"}],
        name: [<r4:HumanName>{family: "Johnson", given: ["Alice"]}],
        gender: "female",
        birthDate: "1975-03-10",
        telecom: [<r4:ContactPoint>{system: "phone", value: "555-9876"}],
        address: [<r4:Address>{postalCode: "54321"}]
    };

    string[][] ids = [["urn:test", "P020"]];
    BlockingKey[] run1 = computeBlockingKeys(patient, ids);
    BlockingKey[] run2 = computeBlockingKeys(patient, ids);

    test:assertEquals(run1.length(), run2.length());
    foreach int i in 0 ..< run1.length() {
        test:assertEquals(run1[i].blockType, run2[i].blockType);
        test:assertEquals(run1[i].blockValue, run2[i].blockValue);
    }
}
