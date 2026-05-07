#!/bin/bash
# =====================================================================
# Seed patients to test ALL deduplication scenarios
# Tests: true duplicates, false positives, near-misses, edge cases
#
# Scoring weights (from db_repository.bal):
#   Identifier: 0.30  |  Family: 0.20  |  Given: 0.15
#   BirthDate:  0.20  |  Gender: 0.05  |  Phone: 0.05  |  Postal: 0.05
#
# Dedup threshold: 0.60  |  Grades: certain(>=0.95) probable(>=0.80) possible(>=0.60)
#
# Usage: bash seed-dedup-scenarios.sh
# Requires: curl, base64, python3, backend running on localhost:9090
# =====================================================================

BASE_URL="http://localhost:9090/fhir/r4"
SYSTEM="http://www.acme.com/identifiers/patient"

TOKEN=$(echo -n '{"sub":"admin@demo.org","role":"admin","exp":9999999999999}' | base64 -w 0 2>/dev/null || echo -n '{"sub":"admin@demo.org","role":"admin","exp":9999999999999}' | base64)

SUCCESS=0
FAIL=0
CREATED=0
UPDATED=0
COUNT=0
TOTAL=22

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# =====================================================================
# Helper: extract JSON field using python3
# =====================================================================
json_field() {
  python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    keys = '$1'.split('.')
    val = data
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k, 'N/A')
        else:
            val = 'N/A'
            break
    print(val if val is not None else 'N/A')
except:
    print('N/A')
" 2>/dev/null
}

# =====================================================================
# PUT a patient and display the server response
# =====================================================================
send_patient() {
  local NIC="$1" GIVEN="$2" MIDDLE="$3" FAMILY="$4" GENDER="$5" BIRTHDATE="$6" PHONE="$7"
  local HOUSE="$8" STREET="$9" CITY="${10}" DISTRICT="${11}" POSTCODE="${12}" LABEL="${13}"

  COUNT=$((COUNT + 1))

  ENCODED_SYSTEM=$(echo -n "$SYSTEM" | sed 's/:/%3A/g; s/\//%2F/g; s/\./%2E/g')

  PATIENT=$(cat <<EOF
{
  "resourceType": "Patient",
  "identifier": [
    {
      "use": "official",
      "system": "${SYSTEM}",
      "value": "${NIC}"
    }
  ],
  "active": true,
  "name": [
    {
      "use": "official",
      "family": "${FAMILY}",
      "given": ["${GIVEN}", "${MIDDLE}"]
    }
  ],
  "telecom": [
    {
      "system": "phone",
      "value": "${PHONE}",
      "use": "mobile"
    }
  ],
  "gender": "${GENDER}",
  "birthDate": "${BIRTHDATE}",
  "address": [
    {
      "use": "home",
      "line": ["${HOUSE}", "${STREET}"],
      "city": "${CITY}",
      "district": "${DISTRICT}",
      "postalCode": "${POSTCODE}",
      "country": "US"
    }
  ]
}
EOF
)

  HTTP_CODE=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
    -X PUT "${BASE_URL}/Patient?identifier=${ENCODED_SYSTEM}|${NIC}" \
    -H "Content-Type: application/fhir+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "${PATIENT}")

  # Parse response
  local RESP_ID=$(cat "$TMPFILE" | json_field "id")
  local RESP_VER=$(cat "$TMPFILE" | json_field "meta.versionId")
  local RESP_UPDATED=$(cat "$TMPFILE" | json_field "meta.lastUpdated")

  if [[ "$HTTP_CODE" == "201" ]]; then
    SUCCESS=$((SUCCESS + 1))
    CREATED=$((CREATED + 1))
    printf "  [%2d/${TOTAL}] %-7s %-22s %-14s id=%-38s ver=%s %s\n" \
      "$COUNT" "CREATED" "$GIVEN $MIDDLE" "$FAMILY" "$RESP_ID" "$RESP_VER" "$LABEL"
  elif [[ "$HTTP_CODE" == "200" ]]; then
    SUCCESS=$((SUCCESS + 1))
    UPDATED=$((UPDATED + 1))
    printf "  [%2d/${TOTAL}] %-7s %-22s %-14s id=%-38s ver=%s %s\n" \
      "$COUNT" "UPDATED" "$GIVEN $MIDDLE" "$FAMILY" "$RESP_ID" "$RESP_VER" "$LABEL"
  else
    FAIL=$((FAIL + 1))
    local ERR_MSG=$(cat "$TMPFILE" | json_field "issue" 2>/dev/null || echo "unknown")
    printf "  [%2d/${TOTAL}] %-7s %-22s %-14s HTTP %s — %s\n" \
      "$COUNT" "FAILED" "$GIVEN $MIDDLE" "$FAMILY" "$HTTP_CODE" "$ERR_MSG"
  fi

  sleep 0.3
}

# =====================================================================
# POST $match for a patient and display scores
# =====================================================================
run_match() {
  local LABEL="$1" GIVEN="$2" FAMILY="$3" GENDER="$4" BIRTHDATE="$5" PHONE="$6" POSTCODE="$7"

  local MATCH_BODY=$(cat <<EOF
{
  "resourceType": "Parameters",
  "parameter": [
    {
      "name": "resource",
      "resource": {
        "resourceType": "Patient",
        "name": [{ "family": "${FAMILY}", "given": ["${GIVEN}"] }],
        "gender": "${GENDER}",
        "birthDate": "${BIRTHDATE}",
        "telecom": [{ "system": "phone", "value": "${PHONE}" }],
        "address": [{ "postalCode": "${POSTCODE}" }]
      }
    },
    {
      "name": "count",
      "valueInteger": 5
    }
  ]
}
EOF
)

  HTTP_CODE=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
    -X POST "${BASE_URL}/Patient/\$match" \
    -H "Content-Type: application/fhir+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "${MATCH_BODY}")

  if [[ "$HTTP_CODE" == "200" ]]; then
    local MATCH_COUNT=$(cat "$TMPFILE" | json_field "total")
    echo "  ${LABEL}: ${MATCH_COUNT} match(es) found"

    # Parse each match entry
    python3 -c "
import json, sys
try:
    data = json.load(open('$TMPFILE'))
    entries = data.get('entry', [])
    if not entries:
        print('    (no matches above threshold)')
    for e in entries:
        res = e.get('resource', {})
        search = e.get('search', {})
        score = search.get('score', 0)
        pid = res.get('id', 'N/A')
        names = res.get('name', [{}])
        family = names[0].get('family', '?') if names else '?'
        given = names[0].get('given', ['?'])[0] if names else '?'
        active = res.get('active', '?')
        grade = 'certain' if score >= 0.95 else 'probable' if score >= 0.80 else 'possible' if score >= 0.60 else 'certainly-not'
        marker = '>>>' if score >= 0.60 else '   '
        print(f'    {marker} score={score:.2f} ({grade:12s})  {given} {family}  id={pid}  active={active}')
except Exception as ex:
    print(f'    Error parsing: {ex}')
" 2>/dev/null
  else
    echo "  ${LABEL}: HTTP ${HTTP_CODE} — match request failed"
    cat "$TMPFILE" | python3 -m json.tool 2>/dev/null | head -5
  fi
}

echo "=========================================================================="
echo "  DEDUP SCENARIO TESTER — ${TOTAL} patients across 10 scenarios"
echo "  Backend: ${BASE_URL}"
echo "=========================================================================="
echo ""
echo "  Response key:  CREATED = 201 (new patient)"
echo "                 UPDATED = 200 (patient already existed, was updated)"
echo ""

# =====================================================================
# SCENARIO 1: TRUE DUPLICATE — Max score without shared identifier
# Score: family(0.20) + given(0.15) + DOB(0.20) + gender(0.05)
#      + phone(0.05) + postal(0.05) = 0.70 → POSSIBLE
# =====================================================================
echo "━━ SC1: TRUE DUPLICATE — all demographics match (expected score 0.70) ━━"
echo "   Same person, registered twice. Correct action: MERGE"
send_patient "SC1-A" "Emily" "Rose" "Carter" "female" "1992-03-14" "+15557001001" \
  "45" "Maple Drive" "Portland" "Multnomah" "97201" "[SC1-TRUE-DUP]"
send_patient "SC1-B" "Emily" "Rose" "Carter" "female" "1992-03-14" "+15557001001" \
  "120" "Cedar Lane" "Portland" "Multnomah" "97201" "[SC1-TRUE-DUP]"
echo ""

# =====================================================================
# SCENARIO 2: TRUE DUPLICATE — Nickname variation
# "Michael" vs "Mike" — exact match only, won't match given name.
# Score: family(0.20) + DOB(0.20) + gender(0.05) + phone(0.05)
#      + postal(0.05) = 0.55 → BELOW THRESHOLD
# =====================================================================
echo "━━ SC2: TRUE DUPLICATE — nickname variation (expected score 0.55) ━━"
echo "   Same person: 'Michael' vs 'Mike'. Algorithm MISSES this!"
send_patient "SC2-A" "Michael" "James" "Rodriguez" "male" "1988-07-22" "+15557002001" \
  "33" "Oak Avenue" "Denver" "Denver" "80201" "[SC2-NICKNAME]"
send_patient "SC2-B" "Mike" "James" "Rodriguez" "male" "1988-07-22" "+15557002001" \
  "33" "Oak Avenue" "Denver" "Denver" "80201" "[SC2-NICKNAME]"
echo ""

# =====================================================================
# SCENARIO 3: FALSE POSITIVE — Different people, same name + DOB
# Score: family(0.20) + given(0.15) + DOB(0.20) + gender(0.05) = 0.60
# =====================================================================
echo "━━ SC3: FALSE POSITIVE — different people, same name+DOB (expected 0.60) ━━"
echo "   Two different 'John Smith' born same day. Correct action: REJECT"
send_patient "SC3-A" "John" "William" "Smith" "male" "1990-05-15" "+15557003001" \
  "88" "Pine Road" "Seattle" "King County" "98101" "[SC3-FALSE-POS]"
send_patient "SC3-B" "John" "David" "Smith" "male" "1990-05-15" "+15557003002" \
  "212" "Broadway" "Miami" "Miami-Dade" "33101" "[SC3-FALSE-POS]"
echo ""

# =====================================================================
# SCENARIO 4: TWINS — same household, different given names
# Score: family(0.20) + DOB(0.20) + gender(0.05) + phone(0.05)
#      + postal(0.05) = 0.55 → BELOW THRESHOLD
# =====================================================================
echo "━━ SC4: TWINS — different given names, same household (expected 0.55) ━━"
echo "   Correctly NOT flagged as duplicates."
send_patient "SC4-A" "Marcus" "Allen" "Thompson" "male" "1995-09-12" "+15557004001" \
  "17" "Elm Street" "Atlanta" "Fulton" "30301" "[SC4-TWINS]"
send_patient "SC4-B" "Martin" "Allen" "Thompson" "male" "1995-09-12" "+15557004001" \
  "17" "Elm Street" "Atlanta" "Fulton" "30301" "[SC4-TWINS]"
echo ""

# =====================================================================
# SCENARIO 5: FALSE POSITIVE — Twins with SAME first name
# "Maria Elena" vs "Maria Sofia" — given name MATCHES ("Maria").
# Score: family(0.20) + given(0.15) + DOB(0.20) + gender(0.05)
#      + phone(0.05) + postal(0.05) = 0.70 → POSSIBLE
# =====================================================================
echo "━━ SC5: FALSE POSITIVE — twins with same first name (expected 0.70) ━━"
echo "   'Maria Elena' vs 'Maria Sofia' Lopez. Correct action: REJECT"
send_patient "SC5-A" "Maria" "Elena" "Lopez" "female" "1998-02-28" "+15557005001" \
  "56" "Washington Blvd" "San Antonio" "Bexar" "78201" "[SC5-TWINS-FP]"
send_patient "SC5-B" "Maria" "Sofia" "Lopez" "female" "1998-02-28" "+15557005001" \
  "56" "Washington Blvd" "San Antonio" "Bexar" "78201" "[SC5-TWINS-FP]"
echo ""

# =====================================================================
# SCENARIO 6: TRUE DUPLICATE — Transposed DOB
# Score: family(0.20) + given(0.15) + gender(0.05) + phone(0.05)
#      + postal(0.05) = 0.50 → BELOW THRESHOLD
# =====================================================================
echo "━━ SC6: TRUE DUPLICATE — transposed birth date (expected 0.50) ━━"
echo "   DOB '1985-04-12' vs '1985-12-04'. Algorithm MISSES this!"
send_patient "SC6-A" "Rachel" "Marie" "Henderson" "female" "1985-04-12" "+15557006001" \
  "78" "Lincoln Avenue" "Nashville" "Davidson" "37201" "[SC6-BAD-DOB]"
send_patient "SC6-B" "Rachel" "Marie" "Henderson" "female" "1985-12-04" "+15557006001" \
  "78" "Lincoln Avenue" "Nashville" "Davidson" "37201" "[SC6-BAD-DOB]"
echo ""

# =====================================================================
# SCENARIO 7: MIXED GROUP — 2 true dups + 1 false positive
# A↔B = family+given+DOB+gender+postal = 0.65
# A↔C = family+given+DOB+gender = 0.60
# =====================================================================
echo "━━ SC7: MIXED GROUP — 2 true dups + 1 false positive (expected 0.60+) ━━"
echo "   A & B = same person. C = different person. Action: Merge A+B, mark C unique."
send_patient "SC7-A" "Daniel" "Lee" "Park" "male" "1993-08-20" "+15557007001" \
  "42" "Oak Avenue" "Chicago" "Cook County" "60601" "[SC7-MIXED-TRUE]"
send_patient "SC7-B" "Daniel" "Lee" "Park" "male" "1993-08-20" "+15557007002" \
  "159" "Elm Street" "Chicago" "Cook County" "60601" "[SC7-MIXED-TRUE]"
send_patient "SC7-C" "Daniel" "James" "Park" "male" "1993-08-20" "+15557007003" \
  "8" "Main Street" "Boston" "Suffolk" "02101" "[SC7-MIXED-FP]"
echo ""

# =====================================================================
# SCENARIO 8: FATHER & SON — same name, 30yr DOB gap
# Score: family(0.20) + given(0.15) + gender(0.05) + phone(0.05)
#      + postal(0.05) = 0.50 → BELOW THRESHOLD
# =====================================================================
echo "━━ SC8: FATHER & SON — same name, different DOB (expected 0.50) ━━"
echo "   'Robert Chen' (1965) vs 'Robert Chen' (1995). Correctly NOT flagged."
send_patient "SC8-A" "Robert" "Wei" "Chen" "male" "1965-11-03" "+15557008001" \
  "91" "Park Place" "San Francisco" "SF County" "94101" "[SC8-FATHER]"
send_patient "SC8-B" "Robert" "Wei" "Chen" "male" "1995-11-03" "+15557008001" \
  "91" "Park Place" "San Francisco" "SF County" "94101" "[SC8-SON]"
echo ""

# =====================================================================
# SCENARIO 9: MARRIED COUPLE — same surname + same DOB
# Score: family(0.20) + DOB(0.20) + postal(0.05) + phone(0.05) = 0.50
# =====================================================================
echo "━━ SC9: MARRIED COUPLE — same last name + same DOB (expected 0.50) ━━"
echo "   Different genders, different given names. Correctly NOT flagged."
send_patient "SC9-A" "James" "Robert" "Wilson" "male" "1987-06-15" "+15557009001" \
  "204" "Cedar Lane" "Austin" "Travis" "73301" "[SC9-HUSBAND]"
send_patient "SC9-B" "Sarah" "Anne" "Wilson" "female" "1987-06-15" "+15557009001" \
  "204" "Cedar Lane" "Austin" "Travis" "73301" "[SC9-WIFE]"
echo ""

# =====================================================================
# SCENARIO 10: TRUE DUPLICATE — Person relocated
# Score: family(0.20) + given(0.15) + DOB(0.20) + gender(0.05) = 0.60
# =====================================================================
echo "━━ SC10: TRUE DUPLICATE — person relocated (expected 0.60) ━━"
echo "   Same person moved cities, new phone. Barely hits threshold."
send_patient "SC10-A" "Olivia" "Grace" "Bennett" "female" "1991-01-07" "+15557010001" \
  "63" "Pine Road" "Phoenix" "Maricopa" "85001" "[SC10-RELOCATED]"
send_patient "SC10-B" "Olivia" "Grace" "Bennett" "female" "1991-01-07" "+15557010002" \
  "310" "Broadway" "Las Vegas" "Clark" "89101" "[SC10-RELOCATED]"
echo ""

# =====================================================================
# PHASE 2: VERIFY WITH $match ENDPOINT
# =====================================================================
echo ""
echo "=========================================================================="
echo "  PHASE 2: Verifying matches via POST /Patient/\$match"
echo "  (sending one patient from each detected scenario to see actual scores)"
echo "=========================================================================="
echo ""

echo "━━ SC1: Matching 'Emily Carter' ━━"
run_match "SC1" "Emily" "Carter" "female" "1992-03-14" "+15557001001" "97201"
echo ""

echo "━━ SC2: Matching 'Michael Rodriguez' (nickname test) ━━"
run_match "SC2" "Michael" "Rodriguez" "male" "1988-07-22" "+15557002001" "80201"
echo ""

echo "━━ SC3: Matching 'John Smith' (false positive test) ━━"
run_match "SC3" "John" "Smith" "male" "1990-05-15" "+15557003001" "98101"
echo ""

echo "━━ SC5: Matching 'Maria Lopez' (twin false positive) ━━"
run_match "SC5" "Maria" "Lopez" "female" "1998-02-28" "+15557005001" "78201"
echo ""

echo "━━ SC6: Matching 'Rachel Henderson' DOB=1985-04-12 (transposed DOB test) ━━"
run_match "SC6" "Rachel" "Henderson" "female" "1985-04-12" "+15557006001" "37201"
echo ""

echo "━━ SC7: Matching 'Daniel Park' (mixed group test) ━━"
run_match "SC7" "Daniel" "Park" "male" "1993-08-20" "+15557007001" "60601"
echo ""

echo "━━ SC8: Matching 'Robert Chen' DOB=1965 (father/son test) ━━"
run_match "SC8" "Robert" "Chen" "male" "1965-11-03" "+15557008001" "94101"
echo ""

echo "━━ SC10: Matching 'Olivia Bennett' (relocated test) ━━"
run_match "SC10" "Olivia" "Bennett" "female" "1991-01-07" "+15557010001" "85001"
echo ""

# =====================================================================
# PHASE 3: RUN DEDUP AND SHOW ACTUAL GROUPS
# =====================================================================
echo ""
echo "=========================================================================="
echo "  PHASE 3: Running GET /Patient/dedup — actual algorithm results"
echo "=========================================================================="
echo ""

HTTP_CODE=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
  -X GET "${BASE_URL}/Patient/dedup" \
  -H "Authorization: Bearer ${TOKEN}")

if [[ "$HTTP_CODE" == "200" ]]; then
  python3 -c "
import json, sys

data = json.load(open('$TMPFILE'))
total_patients = data.get('totalPatients', '?')
total_groups = data.get('totalGroups', '?')
threshold = data.get('threshold', '?')
timestamp = data.get('timestamp', '?')

print(f'  Total patients in DB: {total_patients}')
print(f'  Total dedup groups:   {total_groups}')
print(f'  Threshold used:       {threshold}')
print(f'  Timestamp:            {timestamp}')
print()

groups = data.get('groups', [])
if not groups:
    print('  (no dedup groups found)')
else:
    for i, g in enumerate(groups):
        gid = g.get('id', '?')
        score = g.get('score', 0)
        grade = g.get('matchGrade', '?')
        status = g.get('status', '?')
        matched = g.get('matchedFields', [])
        unmatched = g.get('unmatchedFields', [])
        patients = g.get('patients', [])

        print(f'  ┌── Group {i+1}: score={score:.2f} grade={grade} status={status}')
        print(f'  │   Matched fields:   {', '.join(matched) if matched else '(none)'}')
        print(f'  │   Unmatched fields:  {', '.join(unmatched) if unmatched else '(none)'}')
        print(f'  │   Patients ({len(patients)}):')
        for p in patients:
            pid = p.get('id', '?')
            names = p.get('name', [{}])
            family = names[0].get('family', '?') if names else '?'
            given_list = names[0].get('given', ['?']) if names else ['?']
            given = ' '.join(given_list) if given_list else '?'
            dob = p.get('birthDate', '?')
            gender = p.get('gender', '?')
            ids = p.get('identifier', [{}])
            nic = ids[0].get('value', '?') if ids else '?'
            telecoms = p.get('telecom', [{}])
            phone = telecoms[0].get('value', '?') if telecoms else '?'
            addrs = p.get('address', [{}])
            city = addrs[0].get('city', '?') if addrs else '?'
            postal = addrs[0].get('postalCode', '?') if addrs else '?'
            print(f'  │     [{nic:6s}] {given:20s} {family:14s} {gender:6s} DOB={dob} phone={phone} city={city} postal={postal}')
        print(f'  └──')
        print()
" 2>/dev/null
else
  echo "  Dedup request failed: HTTP ${HTTP_CODE}"
  cat "$TMPFILE" | python3 -m json.tool 2>/dev/null | head -10
fi

# =====================================================================
# PHASE 4: EXPECTED vs ACTUAL SUMMARY
# =====================================================================
echo ""
echo "=========================================================================="
echo "  PHASE 4: SUMMARY"
echo "=========================================================================="
echo ""
echo "  Seeding: ${SUCCESS} succeeded (${CREATED} created, ${UPDATED} updated), ${FAIL} failed"
echo ""
echo "  ┌──────────┬──────────────────────────────────────────┬────────┬──────────────┬────────────┐"
echo "  │ Scenario │ Description                              │ Expect │ Should detect │ Action     │"
echo "  ├──────────┼──────────────────────────────────────────┼────────┼──────────────┼────────────┤"
echo "  │ SC1      │ TRUE DUP: all demographics match         │ 0.70   │ YES possible │ MERGE      │"
echo "  │ SC2      │ TRUE DUP: nickname Michael/Mike          │ 0.55   │ NO  (gap!)   │ —          │"
echo "  │ SC3      │ FALSE POS: 2x John Smith same DOB        │ 0.60   │ YES possible │ REJECT     │"
echo "  │ SC4      │ TWINS: diff given names, same household  │ 0.55   │ NO  (correct)│ —          │"
echo "  │ SC5      │ FALSE POS: twins same first name Maria   │ 0.70   │ YES possible │ REJECT     │"
echo "  │ SC6      │ TRUE DUP: transposed DOB 04-12/12-04    │ 0.50   │ NO  (gap!)   │ —          │"
echo "  │ SC7      │ MIXED: 2 true dups + 1 false positive    │ 0.60+  │ YES possible │ MERGE+UNIQ │"
echo "  │ SC8      │ FATHER/SON: same name, 30yr DOB gap      │ 0.50   │ NO  (correct)│ —          │"
echo "  │ SC9      │ MARRIED: same surname + birthday          │ 0.50   │ NO  (correct)│ —          │"
echo "  │ SC10     │ TRUE DUP: person relocated, new phone    │ 0.60   │ YES possible │ MERGE      │"
echo "  └──────────┴──────────────────────────────────────────┴────────┴──────────────┴────────────┘"
echo ""
echo "  Compare the ACTUAL dedup groups above against this table."
echo "  If a scenario appears in dedup that shouldn't (or vice versa), the algorithm"
echo "  behaves differently than the calculated score predicts."
echo ""
echo "  KEY: First run = all CREATED (201). Second run = all UPDATED (200)."
