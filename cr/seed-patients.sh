#!/bin/bash
# =============================================================
# Seed 70 test patients into the FHIR R4 backend (IHE PDQm)
# Includes intentional duplicate groups for dedup demo
# Usage: bash seed-patients.sh
# Requires: curl, base64, backend running on localhost:9090
# =============================================================

BASE_URL="http://localhost:9090/fhir/r4"
SYSTEM="http://www.acme.com/identifiers/patient"

# Admin token (base64-encoded simulated JWT)
TOKEN=$(echo -n '{"sub":"admin@demo.org","role":"admin","exp":9999999999999}' | base64 -w 0 2>/dev/null || echo -n '{"sub":"admin@demo.org","role":"admin","exp":9999999999999}' | base64)

SUCCESS=0
FAIL=0
COUNT=0

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

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT "${BASE_URL}/Patient?identifier=${ENCODED_SYSTEM}|${NIC}" \
    -H "Content-Type: application/fhir+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "${PATIENT}")

  if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    SUCCESS=$((SUCCESS + 1))
    printf "  [%2d/70] ✓ %-20s %-12s %-15s (%s) %s\n" "$COUNT" "$GIVEN $MIDDLE" "$FAMILY" "$CITY" "$GENDER" "$LABEL"
  else
    FAIL=$((FAIL + 1))
    printf "  [%2d/70] ✗ %-20s %-12s — HTTP %s\n" "$COUNT" "$GIVEN $MIDDLE" "$FAMILY" "$HTTP_CODE"
  fi

  sleep 0.3
}

echo "=== Seeding 70 patients (with duplicate groups for dedup demo) ==="
echo "Backend: ${BASE_URL}"
echo ""

# =====================================================================
# DUPLICATE GROUP 1: "James Smith" — 3 records (triple match)
# Same name, DOB, gender — different identifiers, slight address/phone variations
# Expected score: family(0.20) + given(0.15) + DOB(0.20) + gender(0.05) = 0.60 (possible)
# =====================================================================
echo "--- Group 1: James Smith (x3 — triple duplicate) ---"
send_patient "PAT-001" "James" "Alexander" "Smith" "male" "1985-03-15" "+15551000001" \
  "42" "Oak Avenue" "New York" "Manhattan" "10001" "[DUP-GROUP-1]"
send_patient "PAT-002" "James" "Alexander" "Smith" "male" "1985-03-15" "+15551000002" \
  "108" "Elm Street" "Chicago" "Cook County" "60601" "[DUP-GROUP-1]"
send_patient "PAT-003" "James" "A" "Smith" "male" "1985-03-15" "+15551000003" \
  "7" "Main Street" "New York" "Manhattan" "10001" "[DUP-GROUP-1]"

# =====================================================================
# DUPLICATE GROUP 2: "Mary Johnson" — 2 records (pair match)
# =====================================================================
echo "--- Group 2: Mary Johnson (x2 — pair duplicate) ---"
send_patient "PAT-004" "Mary" "Catherine" "Johnson" "female" "1990-07-22" "+15551000004" \
  "15" "Maple Drive" "Los Angeles" "LA County" "90001" "[DUP-GROUP-2]"
send_patient "PAT-005" "Mary" "Catherine" "Johnson" "female" "1990-07-22" "+15551000005" \
  "200" "Broadway" "Los Angeles" "LA County" "90001" "[DUP-GROUP-2]"

# =====================================================================
# DUPLICATE GROUP 3: "Robert Williams" — 4 records (quad match)
# =====================================================================
echo "--- Group 3: Robert Williams (x4 — quad duplicate) ---"
send_patient "PAT-006" "Robert" "Edward" "Williams" "male" "1978-11-08" "+15551000006" \
  "33" "Pine Road" "Houston" "Harris County" "77001" "[DUP-GROUP-3]"
send_patient "PAT-007" "Robert" "Edward" "Williams" "male" "1978-11-08" "+15551000007" \
  "89" "Cedar Lane" "Dallas" "Dallas County" "75201" "[DUP-GROUP-3]"
send_patient "PAT-008" "Robert" "E" "Williams" "male" "1978-11-08" "+15551000008" \
  "5" "Washington Blvd" "Houston" "Harris County" "77001" "[DUP-GROUP-3]"
send_patient "PAT-009" "Robert" "Edward" "Williams" "male" "1978-11-08" "+15551000009" \
  "162" "Lincoln Avenue" "Phoenix" "Maricopa" "85001" "[DUP-GROUP-3]"

# =====================================================================
# DUPLICATE GROUP 4: "Jennifer Davis" — 2 records
# =====================================================================
echo "--- Group 4: Jennifer Davis (x2) ---"
send_patient "PAT-010" "Jennifer" "Marie" "Davis" "female" "1995-01-30" "+15551000010" \
  "77" "Park Place" "Philadelphia" "Philadelphia" "19101" "[DUP-GROUP-4]"
send_patient "PAT-011" "Jennifer" "Marie" "Davis" "female" "1995-01-30" "+15551000011" \
  "22" "Oak Avenue" "Philadelphia" "Philadelphia" "19101" "[DUP-GROUP-4]"

# =====================================================================
# DUPLICATE GROUP 5: "Michael Brown" — 3 records (same phone too)
# Higher score due to matching phone
# =====================================================================
echo "--- Group 5: Michael Brown (x3 — with same phone) ---"
send_patient "PAT-012" "Michael" "Thomas" "Brown" "male" "1982-06-14" "+15559999001" \
  "55" "Main Street" "Chicago" "Cook County" "60601" "[DUP-GROUP-5]"
send_patient "PAT-013" "Michael" "Thomas" "Brown" "male" "1982-06-14" "+15559999001" \
  "12" "Elm Street" "Chicago" "Cook County" "60601" "[DUP-GROUP-5]"
send_patient "PAT-014" "Michael" "T" "Brown" "male" "1982-06-14" "+15559999001" \
  "301" "Cedar Lane" "Chicago" "Cook County" "60601" "[DUP-GROUP-5]"

# =====================================================================
# DUPLICATE GROUP 6: "Elizabeth Garcia" — 2 records
# =====================================================================
echo "--- Group 6: Elizabeth Garcia (x2) ---"
send_patient "PAT-015" "Elizabeth" "Anne" "Garcia" "female" "1988-09-03" "+15551000015" \
  "18" "Broadway" "San Diego" "San Diego" "92101" "[DUP-GROUP-6]"
send_patient "PAT-016" "Elizabeth" "Anne" "Garcia" "female" "1988-09-03" "+15551000016" \
  "44" "Pine Road" "San Diego" "San Diego" "92101" "[DUP-GROUP-6]"

# =====================================================================
# DUPLICATE GROUP 7: "David Anderson" — 3 records
# =====================================================================
echo "--- Group 7: David Anderson (x3) ---"
send_patient "PAT-017" "David" "James" "Anderson" "male" "1975-12-25" "+15551000017" \
  "90" "Washington Blvd" "Austin" "Travis County" "73301" "[DUP-GROUP-7]"
send_patient "PAT-018" "David" "James" "Anderson" "male" "1975-12-25" "+15551000018" \
  "63" "Lincoln Avenue" "Dallas" "Dallas County" "75201" "[DUP-GROUP-7]"
send_patient "PAT-019" "David" "J" "Anderson" "male" "1975-12-25" "+15551000019" \
  "8" "Oak Avenue" "Austin" "Travis County" "73301" "[DUP-GROUP-7]"

# =====================================================================
# DUPLICATE GROUP 8: "Sarah Martinez" — 2 records
# =====================================================================
echo "--- Group 8: Sarah Martinez (x2) ---"
send_patient "PAT-020" "Sarah" "Rose" "Martinez" "female" "1992-04-18" "+15551000020" \
  "25" "Maple Drive" "Phoenix" "Maricopa" "85001" "[DUP-GROUP-8]"
send_patient "PAT-021" "Sarah" "Rose" "Martinez" "female" "1992-04-18" "+15551000021" \
  "140" "Park Place" "Phoenix" "Maricopa" "85001" "[DUP-GROUP-8]"

# =====================================================================
# UNIQUE PATIENTS (no duplicates) — 49 patients
# =====================================================================
echo ""
echo "--- Unique patients (no duplicates) ---"

send_patient "PAT-022" "William" "Henry" "Taylor" "male" "1970-02-10" "+15551000022" \
  "31" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "PAT-023" "Patricia" "Lynn" "Thomas" "female" "1983-08-05" "+15551000023" \
  "67" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "PAT-024" "Richard" "Lee" "Jackson" "male" "1968-05-20" "+15551000024" \
  "14" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "PAT-025" "Linda" "Grace" "White" "female" "1991-11-12" "+15551000025" \
  "88" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "PAT-026" "Joseph" "Patrick" "Harris" "male" "1979-03-28" "+15551000026" \
  "52" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "PAT-027" "Barbara" "Jean" "Martin" "female" "1965-07-04" "+15551000027" \
  "103" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "PAT-028" "Thomas" "Ray" "Thompson" "male" "1987-01-16" "+15551000028" \
  "9" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "PAT-029" "Susan" "Kay" "Robinson" "female" "1993-10-09" "+15551000029" \
  "45" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "PAT-030" "Charles" "Dean" "Clark" "male" "1972-06-22" "+15551000030" \
  "210" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "PAT-031" "Jessica" "Faye" "Lewis" "female" "1996-12-01" "+15551000031" \
  "36" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "PAT-032" "Daniel" "Scott" "Walker" "male" "1980-09-14" "+15551000032" \
  "71" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "PAT-033" "Karen" "Sue" "Hall" "female" "1974-04-27" "+15551000033" \
  "19" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "PAT-034" "Matthew" "Ryan" "Allen" "male" "1989-08-08" "+15551000034" \
  "156" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "PAT-035" "Nancy" "Jo" "Young" "female" "1967-02-19" "+15551000035" \
  "4" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "PAT-036" "Andrew" "Cole" "King" "male" "1994-05-11" "+15551000036" \
  "83" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "PAT-037" "Betty" "Ann" "Wright" "female" "1971-01-30" "+15551000037" \
  "27" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "PAT-038" "Joshua" "Blake" "Lopez" "male" "1986-11-25" "+15551000038" \
  "60" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "PAT-039" "Margaret" "Claire" "Hill" "female" "1998-03-07" "+15551000039" \
  "112" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "PAT-040" "Christopher" "Wayne" "Scott" "male" "1976-07-19" "+15551000040" \
  "48" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "PAT-041" "Sandra" "Lee" "Green" "female" "1984-10-02" "+15551000041" \
  "95" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "PAT-042" "Anthony" "Paul" "Adams" "male" "1969-06-15" "+15551000042" \
  "21" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "PAT-043" "Ashley" "Dawn" "Baker" "female" "1997-09-28" "+15551000043" \
  "130" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "PAT-044" "Mark" "Allen" "Nelson" "male" "1981-12-12" "+15551000044" \
  "6" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "PAT-045" "Emily" "Jane" "Carter" "female" "1990-04-05" "+15551000045" \
  "74" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "PAT-046" "Steven" "Grant" "Mitchell" "male" "1973-08-21" "+15551000046" \
  "39" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "PAT-047" "Donna" "Mae" "Perez" "female" "1966-01-14" "+15551000047" \
  "117" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "PAT-048" "Paul" "Victor" "Roberts" "male" "1988-05-30" "+15551000048" \
  "53" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "PAT-049" "Michelle" "Renee" "Turner" "female" "1995-07-17" "+15551000049" \
  "86" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "PAT-050" "Kevin" "Roy" "Phillips" "male" "1977-11-03" "+15551000050" \
  "28" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "PAT-051" "Dorothy" "May" "Campbell" "female" "1963-03-26" "+15551000051" \
  "141" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "PAT-052" "Brian" "Keith" "Parker" "male" "1985-09-08" "+15551000052" \
  "16" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "PAT-053" "Carol" "Diane" "Evans" "female" "1992-02-14" "+15551000053" \
  "99" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "PAT-054" "George" "Frank" "Edwards" "male" "1970-06-29" "+15551000054" \
  "34" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "PAT-055" "Amanda" "Hope" "Collins" "female" "1987-12-18" "+15551000055" \
  "62" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "PAT-056" "Edward" "Carl" "Stewart" "male" "1964-04-10" "+15551000056" \
  "107" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "PAT-057" "Melissa" "Ruth" "Sanchez" "female" "1999-08-23" "+15551000057" \
  "41" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "PAT-058" "Henry" "Louis" "Morris" "male" "1982-01-05" "+15551000058" \
  "73" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "PAT-059" "Deborah" "Irene" "Rogers" "female" "1975-05-16" "+15551000059" \
  "120" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "PAT-060" "Samuel" "John" "Reed" "male" "1991-10-30" "+15551000060" \
  "50" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "PAT-061" "Stephanie" "Eve" "Cook" "female" "1986-07-07" "+15551000061" \
  "85" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "PAT-062" "Jason" "Neil" "Morgan" "male" "1978-02-22" "+15551000062" \
  "13" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "PAT-063" "Lisa" "Beth" "Bell" "female" "1993-06-11" "+15551000063" \
  "148" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "PAT-064" "Ryan" "Charles" "Murphy" "male" "1980-11-04" "+15551000064" \
  "26" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "PAT-065" "Laura" "Kim" "Bailey" "female" "1972-09-18" "+15551000065" \
  "58" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "PAT-066" "Jacob" "Wade" "Rivera" "male" "1996-01-25" "+15551000066" \
  "91" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "PAT-067" "Cynthia" "Gail" "Cooper" "female" "1968-04-08" "+15551000067" \
  "37" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "PAT-068" "Nicholas" "Drew" "Richardson" "male" "1984-08-13" "+15551000068" \
  "66" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "PAT-069" "Angela" "Rae" "Cox" "female" "1990-12-29" "+15551000069" \
  "115" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "PAT-070" "Tyler" "James" "Howard" "male" "1977-03-02" "+15551000070" \
  "43" "Park Place" "Dallas" "Dallas County" "75201" ""

echo ""
echo "=== Done: ${SUCCESS} created, ${FAIL} failed (out of 70) ==="
echo ""
echo "Duplicate groups for dedup demo:"
echo "  Group 1: James Smith     — 3 records (PAT-001, PAT-002, PAT-003)"
echo "  Group 2: Mary Johnson    — 2 records (PAT-004, PAT-005)"
echo "  Group 3: Robert Williams — 4 records (PAT-006, PAT-007, PAT-008, PAT-009)"
echo "  Group 4: Jennifer Davis  — 2 records (PAT-010, PAT-011)"
echo "  Group 5: Michael Brown   — 3 records (PAT-012, PAT-013, PAT-014) + same phone"
echo "  Group 6: Elizabeth Garcia — 2 records (PAT-015, PAT-016)"
echo "  Group 7: David Anderson  — 3 records (PAT-017, PAT-018, PAT-019)"
echo "  Group 8: Sarah Martinez  — 2 records (PAT-020, PAT-021)"
echo "  Unique patients: 49 (PAT-022 to PAT-070)"
