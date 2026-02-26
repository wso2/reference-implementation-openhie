#!/bin/bash
# =============================================================
# Seed 158 test patients for demo (with duplicate groups)
# Usage: bash seed-demo.sh
# Requires: curl, base64, backend running on localhost:9090
# =============================================================

BASE_URL="http://localhost:9090/fhir/r4"
SYSTEM="http://www.acme.com/identifiers/patient"

TOKEN=$(echo -n '{"sub":"admin@demo.org","role":"admin","exp":9999999999999}' | base64 -w 0 2>/dev/null || echo -n '{"sub":"admin@demo.org","role":"admin","exp":9999999999999}' | base64)

SUCCESS=0
FAIL=0
COUNT=0
TOTAL=158

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
    printf "  [%3d/${TOTAL}] ✓ %-22s %-14s %-16s %s\n" "$COUNT" "$GIVEN $MIDDLE" "$FAMILY" "$CITY" "$LABEL"
  else
    FAIL=$((FAIL + 1))
    printf "  [%3d/${TOTAL}] ✗ %-22s %-14s HTTP %s\n" "$COUNT" "$GIVEN $MIDDLE" "$FAMILY" "$HTTP_CODE"
  fi

  sleep 0.3
}

echo "=========================================================="
echo "  Seeding ${TOTAL} patients (with duplicate groups)"
echo "  Backend: ${BASE_URL}"
echo "=========================================================="
echo ""

# =====================================================================
# DUPLICATE GROUPS (40 records across 13 duplicate groups)
# =====================================================================

echo "--- DUP GROUP 1: James Smith (x3) ---"
send_patient "D01-A" "James" "Alexander" "Smith" "male" "1985-03-15" "+15551000001" \
  "42" "Oak Avenue" "New York" "Manhattan" "10001" "[DUP-1]"
send_patient "D01-B" "James" "Alexander" "Smith" "male" "1985-03-15" "+15551000002" \
  "108" "Elm Street" "Chicago" "Cook County" "60601" "[DUP-1]"
send_patient "D01-C" "James" "A" "Smith" "male" "1985-03-15" "+15551000003" \
  "7" "Main Street" "New York" "Manhattan" "10001" "[DUP-1]"

echo "--- DUP GROUP 2: Mary Johnson (x2) ---"
send_patient "D02-A" "Mary" "Catherine" "Johnson" "female" "1990-07-22" "+15551000004" \
  "15" "Maple Drive" "Los Angeles" "LA County" "90001" "[DUP-2]"
send_patient "D02-B" "Mary" "Catherine" "Johnson" "female" "1990-07-22" "+15551000005" \
  "200" "Broadway" "Los Angeles" "LA County" "90001" "[DUP-2]"

echo "--- DUP GROUP 3: Robert Williams (x4) ---"
send_patient "D03-A" "Robert" "Edward" "Williams" "male" "1978-11-08" "+15551000006" \
  "33" "Pine Road" "Houston" "Harris County" "77001" "[DUP-3]"
send_patient "D03-B" "Robert" "Edward" "Williams" "male" "1978-11-08" "+15551000007" \
  "89" "Cedar Lane" "Dallas" "Dallas County" "75201" "[DUP-3]"
send_patient "D03-C" "Robert" "E" "Williams" "male" "1978-11-08" "+15551000008" \
  "5" "Washington Blvd" "Houston" "Harris County" "77001" "[DUP-3]"
send_patient "D03-D" "Robert" "Edward" "Williams" "male" "1978-11-08" "+15551000009" \
  "162" "Lincoln Avenue" "Phoenix" "Maricopa" "85001" "[DUP-3]"

echo "--- DUP GROUP 4: Jennifer Davis (x2) ---"
send_patient "D04-A" "Jennifer" "Marie" "Davis" "female" "1995-01-30" "+15551000010" \
  "77" "Park Place" "Philadelphia" "Philadelphia" "19101" "[DUP-4]"
send_patient "D04-B" "Jennifer" "Marie" "Davis" "female" "1995-01-30" "+15551000011" \
  "22" "Oak Avenue" "Philadelphia" "Philadelphia" "19101" "[DUP-4]"

echo "--- DUP GROUP 5: Michael Brown (x3 + same phone) ---"
send_patient "D05-A" "Michael" "Thomas" "Brown" "male" "1982-06-14" "+15559999001" \
  "55" "Main Street" "Chicago" "Cook County" "60601" "[DUP-5]"
send_patient "D05-B" "Michael" "Thomas" "Brown" "male" "1982-06-14" "+15559999001" \
  "12" "Elm Street" "Chicago" "Cook County" "60601" "[DUP-5]"
send_patient "D05-C" "Michael" "T" "Brown" "male" "1982-06-14" "+15559999001" \
  "301" "Cedar Lane" "Chicago" "Cook County" "60601" "[DUP-5]"

echo "--- DUP GROUP 6: Elizabeth Garcia (x2) ---"
send_patient "D06-A" "Elizabeth" "Anne" "Garcia" "female" "1988-09-03" "+15551000015" \
  "18" "Broadway" "San Diego" "San Diego" "92101" "[DUP-6]"
send_patient "D06-B" "Elizabeth" "Anne" "Garcia" "female" "1988-09-03" "+15551000016" \
  "44" "Pine Road" "San Diego" "San Diego" "92101" "[DUP-6]"

echo "--- DUP GROUP 7: David Anderson (x3) ---"
send_patient "D07-A" "David" "James" "Anderson" "male" "1975-12-25" "+15551000017" \
  "90" "Washington Blvd" "Austin" "Travis County" "73301" "[DUP-7]"
send_patient "D07-B" "David" "James" "Anderson" "male" "1975-12-25" "+15551000018" \
  "63" "Lincoln Avenue" "Dallas" "Dallas County" "75201" "[DUP-7]"
send_patient "D07-C" "David" "J" "Anderson" "male" "1975-12-25" "+15551000019" \
  "8" "Oak Avenue" "Austin" "Travis County" "73301" "[DUP-7]"

echo "--- DUP GROUP 8: Sarah Martinez (x2) ---"
send_patient "D08-A" "Sarah" "Rose" "Martinez" "female" "1992-04-18" "+15551000020" \
  "25" "Maple Drive" "Phoenix" "Maricopa" "85001" "[DUP-8]"
send_patient "D08-B" "Sarah" "Rose" "Martinez" "female" "1992-04-18" "+15551000021" \
  "140" "Park Place" "Phoenix" "Maricopa" "85001" "[DUP-8]"

echo "--- DUP GROUP 9: William Taylor (x3) ---"
send_patient "D09-A" "William" "Henry" "Taylor" "male" "1970-02-10" "+15551000022" \
  "31" "Main Street" "New York" "Manhattan" "10001" "[DUP-9]"
send_patient "D09-B" "William" "Henry" "Taylor" "male" "1970-02-10" "+15551000023" \
  "85" "Cedar Lane" "New York" "Manhattan" "10001" "[DUP-9]"
send_patient "D09-C" "William" "H" "Taylor" "male" "1970-02-10" "+15551000024" \
  "210" "Broadway" "Philadelphia" "Philadelphia" "19101" "[DUP-9]"

echo "--- DUP GROUP 10: Patricia Thomas (x2) ---"
send_patient "D10-A" "Patricia" "Lynn" "Thomas" "female" "1983-08-05" "+15551000025" \
  "67" "Oak Avenue" "Los Angeles" "LA County" "90001" "[DUP-10]"
send_patient "D10-B" "Patricia" "Lynn" "Thomas" "female" "1983-08-05" "+15551000026" \
  "112" "Maple Drive" "Los Angeles" "LA County" "90001" "[DUP-10]"

echo "--- DUP GROUP 11: Aisha Khan (x3, same DOB+ZIP) ---"
send_patient "D11-A" "Aisha" "Noor" "Khan" "female" "1991-02-11" "+15551000027" \
  "17" "Cedar Lane" "Houston" "Harris County" "77001" "[DUP-11]"
send_patient "D11-B" "Ayesha" "Noor" "Khan" "female" "1991-02-11" "+15551000028" \
  "200" "Maple Drive" "Houston" "Harris County" "77001" "[DUP-11]"
send_patient "D11-C" "Aisha" "N" "Khan" "female" "1991-02-11" "+15551000029" \
  "74" "Elm Street" "Houston" "Harris County" "77001" "[DUP-11]"

echo "--- DUP GROUP 12: Ethan Clarke (x2, surname variant) ---"
send_patient "D12-A" "Ethan" "James" "Clarke" "male" "1986-10-05" "+15551000030" \
  "91" "Oak Avenue" "Dallas" "Dallas County" "75201" "[DUP-12]"
send_patient "D12-B" "Ethan" "J" "Clark" "male" "1986-10-05" "+15551000031" \
  "44" "Pine Road" "Dallas" "Dallas County" "75201" "[DUP-12]"

echo "--- DUP GROUP 13: Lucas Mendes (x3, same phone) ---"
send_patient "D13-A" "Lucas" "Andre" "Mendes" "male" "1993-06-19" "+15559999002" \
  "38" "Broadway" "Phoenix" "Maricopa" "85001" "[DUP-13]"
send_patient "D13-B" "Lucas" "A" "Mendez" "male" "1993-06-19" "+15559999002" \
  "121" "Washington Blvd" "Phoenix" "Maricopa" "85001" "[DUP-13]"
send_patient "D13-C" "Lukas" "Andre" "Mendes" "male" "1993-06-19" "+15559999002" \
  "16" "Park Place" "Phoenix" "Maricopa" "85001" "[DUP-13]"

# =====================================================================
# UNIQUE PATIENTS (no duplicates) — 118 patients
# =====================================================================
echo ""
echo "--- Unique patients ---"

send_patient "U-001" "Richard" "Lee" "Jackson" "male" "1968-05-20" "+15552000001" \
  "14" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-002" "Linda" "Grace" "White" "female" "1991-11-12" "+15552000002" \
  "88" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-003" "Joseph" "Patrick" "Harris" "male" "1979-03-28" "+15552000003" \
  "52" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-004" "Barbara" "Jean" "Martin" "female" "1965-07-04" "+15552000004" \
  "103" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-005" "Thomas" "Ray" "Thompson" "male" "1987-01-16" "+15552000005" \
  "9" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-006" "Susan" "Kay" "Robinson" "female" "1993-10-09" "+15552000006" \
  "45" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-007" "Charles" "Dean" "Clark" "male" "1972-06-22" "+15552000007" \
  "210" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-008" "Jessica" "Faye" "Lewis" "female" "1996-12-01" "+15552000008" \
  "36" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-009" "Daniel" "Scott" "Walker" "male" "1980-09-14" "+15552000009" \
  "71" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-010" "Karen" "Sue" "Hall" "female" "1974-04-27" "+15552000010" \
  "19" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-011" "Matthew" "Ryan" "Allen" "male" "1989-08-08" "+15552000011" \
  "156" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-012" "Nancy" "Jo" "Young" "female" "1967-02-19" "+15552000012" \
  "4" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-013" "Andrew" "Cole" "King" "male" "1994-05-11" "+15552000013" \
  "83" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-014" "Betty" "Ann" "Wright" "female" "1971-01-30" "+15552000014" \
  "27" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-015" "Joshua" "Blake" "Lopez" "male" "1986-11-25" "+15552000015" \
  "60" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-016" "Margaret" "Claire" "Hill" "female" "1998-03-07" "+15552000016" \
  "112" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-017" "Christopher" "Wayne" "Scott" "male" "1976-07-19" "+15552000017" \
  "48" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-018" "Sandra" "Lee" "Green" "female" "1984-10-02" "+15552000018" \
  "95" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-019" "Anthony" "Paul" "Adams" "male" "1969-06-15" "+15552000019" \
  "21" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-020" "Ashley" "Dawn" "Baker" "female" "1997-09-28" "+15552000020" \
  "130" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-021" "Mark" "Allen" "Nelson" "male" "1981-12-12" "+15552000021" \
  "6" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-022" "Emily" "Jane" "Carter" "female" "1990-04-05" "+15552000022" \
  "74" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-023" "Steven" "Grant" "Mitchell" "male" "1973-08-21" "+15552000023" \
  "39" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-024" "Donna" "Mae" "Perez" "female" "1966-01-14" "+15552000024" \
  "117" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-025" "Paul" "Victor" "Roberts" "male" "1988-05-30" "+15552000025" \
  "53" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-026" "Michelle" "Renee" "Turner" "female" "1995-07-17" "+15552000026" \
  "86" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-027" "Kevin" "Roy" "Phillips" "male" "1977-11-03" "+15552000027" \
  "28" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-028" "Dorothy" "May" "Campbell" "female" "1963-03-26" "+15552000028" \
  "141" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-029" "Brian" "Keith" "Parker" "male" "1985-09-08" "+15552000029" \
  "16" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-030" "Carol" "Diane" "Evans" "female" "1992-02-14" "+15552000030" \
  "99" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-031" "George" "Frank" "Edwards" "male" "1970-06-29" "+15552000031" \
  "34" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-032" "Amanda" "Hope" "Collins" "female" "1987-12-18" "+15552000032" \
  "62" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-033" "Edward" "Carl" "Stewart" "male" "1964-04-10" "+15552000033" \
  "107" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-034" "Melissa" "Ruth" "Sanchez" "female" "1999-08-23" "+15552000034" \
  "41" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-035" "Henry" "Louis" "Morris" "male" "1982-01-05" "+15552000035" \
  "73" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-036" "Deborah" "Irene" "Rogers" "female" "1975-05-16" "+15552000036" \
  "120" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-037" "Samuel" "John" "Reed" "male" "1991-10-30" "+15552000037" \
  "50" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-038" "Stephanie" "Eve" "Cook" "female" "1986-07-07" "+15552000038" \
  "85" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-039" "Jason" "Neil" "Morgan" "male" "1978-02-22" "+15552000039" \
  "13" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-040" "Lisa" "Beth" "Bell" "female" "1993-06-11" "+15552000040" \
  "148" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-041" "Ryan" "Charles" "Murphy" "male" "1980-11-04" "+15552000041" \
  "26" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-042" "Laura" "Kim" "Bailey" "female" "1972-09-18" "+15552000042" \
  "58" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-043" "Jacob" "Wade" "Rivera" "male" "1996-01-25" "+15552000043" \
  "91" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-044" "Cynthia" "Gail" "Cooper" "female" "1968-04-08" "+15552000044" \
  "37" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-045" "Nicholas" "Drew" "Richardson" "male" "1984-08-13" "+15552000045" \
  "66" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-046" "Angela" "Rae" "Cox" "female" "1990-12-29" "+15552000046" \
  "115" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-047" "Tyler" "James" "Howard" "male" "1977-03-02" "+15552000047" \
  "43" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-048" "Shirley" "Fern" "Ward" "female" "1962-06-18" "+15552000048" \
  "82" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-049" "Brandon" "Miles" "Torres" "male" "1994-02-07" "+15552000049" \
  "20" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-050" "Brenda" "Joy" "Peterson" "female" "1981-07-24" "+15552000050" \
  "155" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-051" "Nathan" "Craig" "Gray" "male" "1976-12-11" "+15552000051" \
  "38" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-052" "Amy" "Faith" "Ramirez" "female" "1988-04-03" "+15552000052" \
  "70" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-053" "Alexander" "Kent" "James" "male" "1971-08-16" "+15552000053" \
  "105" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-054" "Kathleen" "June" "Watson" "female" "1996-11-28" "+15552000054" \
  "29" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-055" "Patrick" "Gene" "Brooks" "male" "1983-03-19" "+15552000055" \
  "54" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-056" "Christine" "Pearl" "Kelly" "female" "1969-09-06" "+15552000056" \
  "87" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-057" "Raymond" "Earl" "Sanders" "male" "1992-01-22" "+15552000057" \
  "46" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-058" "Samantha" "Opal" "Price" "female" "1985-05-14" "+15552000058" \
  "93" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-059" "Gregory" "Todd" "Bennett" "male" "1978-10-08" "+15552000059" \
  "11" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-060" "Janet" "Iris" "Wood" "female" "1974-02-25" "+15552000060" \
  "134" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-061" "Frank" "Lloyd" "Barnes" "male" "1966-07-31" "+15552000061" \
  "47" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-062" "Catherine" "Ivy" "Ross" "female" "1997-04-17" "+15552000062" \
  "76" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-063" "Scott" "Brent" "Henderson" "male" "1989-09-10" "+15552000063" \
  "100" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-064" "Marie" "Vera" "Coleman" "female" "1973-01-02" "+15552000064" \
  "23" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-065" "Sean" "Wade" "Jenkins" "male" "1995-06-20" "+15552000065" \
  "57" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-066" "Heather" "Jade" "Perry" "female" "1980-12-13" "+15552000066" \
  "90" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-067" "Dennis" "Ross" "Powell" "male" "1963-05-27" "+15552000067" \
  "35" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-068" "Rachel" "Dawn" "Long" "female" "1991-08-09" "+15552000068" \
  "128" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-069" "Jerry" "Lane" "Patterson" "male" "1986-03-24" "+15552000069" \
  "17" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-070" "Diane" "Lois" "Hughes" "female" "1976-10-15" "+15552000070" \
  "145" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-071" "Philip" "Dale" "Flores" "male" "1982-04-28" "+15552000071" \
  "40" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-072" "Julie" "Nell" "Washington" "female" "1968-11-06" "+15552000072" \
  "68" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-073" "Keith" "Glenn" "Butler" "male" "1999-02-19" "+15552000073" \
  "96" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-074" "Virginia" "Mae" "Simmons" "female" "1972-07-11" "+15552000074" \
  "24" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-075" "Lawrence" "Clyde" "Foster" "male" "1987-12-03" "+15552000075" \
  "51" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-076" "Theresa" "Gwen" "Gonzales" "female" "1994-05-26" "+15552000076" \
  "84" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-077" "Russell" "Dean" "Bryant" "male" "1970-08-18" "+15552000077" \
  "30" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-078" "Gloria" "Faye" "Alexander" "female" "1983-01-09" "+15552000078" \
  "139" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-079" "Ralph" "Gene" "Russell" "male" "1965-06-22" "+15552000079" \
  "15" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-080" "Teresa" "Hope" "Griffin" "female" "1998-09-04" "+15552000080" \
  "150" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-081" "Roy" "Kent" "Diaz" "male" "1979-04-16" "+15552000081" \
  "44" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-082" "Jacqueline" "Rue" "Hayes" "female" "1986-10-29" "+15552000082" \
  "72" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-083" "Eugene" "Nash" "Myers" "male" "1974-03-12" "+15552000083" \
  "98" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-084" "Cheryl" "Bea" "Ford" "female" "1991-06-25" "+15552000084" \
  "22" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-085" "Wayne" "Hal" "Hamilton" "male" "1967-11-07" "+15552000085" \
  "49" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-086" "Rose" "Ada" "Graham" "female" "1995-02-18" "+15552000086" \
  "81" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-087" "Carl" "Jude" "Sullivan" "male" "1988-07-30" "+15552000087" \
  "32" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-088" "Pamela" "Kit" "Wallace" "female" "1977-12-23" "+15552000088" \
  "126" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-089" "Arthur" "Rex" "Woods" "male" "1962-05-05" "+15552000089" \
  "10" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-090" "Judith" "Lea" "Cole" "female" "1993-08-17" "+15552000090" \
  "143" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-091" "Roger" "Burt" "West" "male" "1980-01-28" "+15552000091" \
  "42" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-092" "Evelyn" "Bess" "Jordan" "female" "1971-06-10" "+15552000092" \
  "65" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-093" "Albert" "Max" "Owens" "male" "1996-09-22" "+15552000093" \
  "94" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-094" "Joan" "Pearl" "Reynolds" "female" "1984-02-04" "+15552000094" \
  "18" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-095" "Alan" "Noel" "Fisher" "male" "1975-07-16" "+15552000095" \
  "55" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-096" "Diana" "Eve" "Ellis" "female" "1989-11-29" "+15552000096" \
  "88" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-097" "Douglas" "Reid" "Chapman" "male" "1964-04-11" "+15552000097" \
  "33" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-098" "Alice" "Mae" "Warren" "female" "1997-08-24" "+15552000098" \
  "121" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-099" "Peter" "Hugh" "Dixon" "male" "1981-01-06" "+15552000099" \
  "8" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-100" "Ruby" "Belle" "Burns" "female" "1970-05-19" "+15552000100" \
  "137" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-101" "Gerald" "Boyd" "Spencer" "male" "1990-10-01" "+15552000101" \
  "56" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-102" "Frances" "Nell" "Marshall" "female" "1978-03-14" "+15552000102" \
  "78" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-103" "Louis" "Dane" "Stone" "male" "1987-06-27" "+15552000103" \
  "101" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-104" "Grace" "Joy" "Harrison" "female" "1966-09-08" "+15552000104" \
  "26" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-105" "Walter" "Beau" "Gilbert" "male" "1993-12-20" "+15552000105" \
  "59" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-106" "Martha" "Wren" "Simmonds" "female" "1982-05-03" "+15552000106" \
  "92" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-107" "Bruce" "Finn" "Ferguson" "male" "1969-08-15" "+15552000107" \
  "37" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-108" "Ann" "Faye" "Nichols" "female" "1995-01-27" "+15552000108" \
  "132" "Broadway" "Austin" "Travis County" "73301" ""
send_patient "U-109" "Harold" "Tate" "Carpenter" "male" "1973-04-09" "+15552000109" \
  "14" "Main Street" "New York" "Manhattan" "10001" ""
send_patient "U-110" "Kathryn" "Joy" "Lawrence" "female" "1986-09-21" "+15552000110" \
  "147" "Oak Avenue" "Los Angeles" "LA County" "90001" ""
send_patient "U-111" "Harry" "Quinn" "Stephens" "male" "1961-12-04" "+15552000111" \
  "41" "Maple Drive" "Chicago" "Cook County" "60601" ""
send_patient "U-112" "Jean" "Skye" "Palmer" "female" "1992-03-16" "+15552000112" \
  "69" "Elm Street" "Houston" "Harris County" "77001" ""
send_patient "U-113" "Howard" "Drew" "Grant" "male" "1984-07-29" "+15552000113" \
  "97" "Cedar Lane" "Phoenix" "Maricopa" "85001" ""
send_patient "U-114" "Sara" "Belle" "Dunn" "female" "1976-11-10" "+15552000114" \
  "21" "Pine Road" "Philadelphia" "Philadelphia" "19101" ""
send_patient "U-115" "Vincent" "Cole" "Webb" "male" "1998-04-23" "+15552000115" \
  "52" "Washington Blvd" "San Antonio" "Bexar County" "78201" ""
send_patient "U-116" "Lori" "Beth" "Harper" "female" "1980-08-05" "+15552000116" \
  "83" "Lincoln Avenue" "San Diego" "San Diego" "92101" ""
send_patient "U-117" "Ernest" "Joel" "Hicks" "male" "1967-01-17" "+15552000117" \
  "31" "Park Place" "Dallas" "Dallas County" "75201" ""
send_patient "U-118" "Megan" "Ivy" "Ray" "female" "1994-06-30" "+15552000118" \
  "127" "Broadway" "Austin" "Travis County" "73301" ""

echo ""
echo "=========================================================="
echo "  Done: ${SUCCESS} created, ${FAIL} failed (out of ${TOTAL})"
echo "=========================================================="
echo ""
echo "Duplicate groups (40 records across 13 groups):"
echo "  Group 1:  James Smith      x3  (D01-A, D01-B, D01-C)"
echo "  Group 2:  Mary Johnson     x2  (D02-A, D02-B)"
echo "  Group 3:  Robert Williams  x4  (D03-A, D03-B, D03-C, D03-D)"
echo "  Group 4:  Jennifer Davis   x2  (D04-A, D04-B)"
echo "  Group 5:  Michael Brown    x3  (D05-A, D05-B, D05-C) + same phone"
echo "  Group 6:  Elizabeth Garcia  x2  (D06-A, D06-B)"
echo "  Group 7:  David Anderson   x3  (D07-A, D07-B, D07-C)"
echo "  Group 8:  Sarah Martinez   x2  (D08-A, D08-B)"
echo "  Group 9:  William Taylor   x3  (D09-A, D09-B, D09-C)"
echo "  Group 10: Patricia Thomas  x2  (D10-A, D10-B)"
echo "  Group 11: Aisha Khan       x3  (D11-A, D11-B, D11-C)"
echo "  Group 12: Ethan Clark/e    x2  (D12-A, D12-B)"
echo "  Group 13: Lucas Mendes     x3  (D13-A, D13-B, D13-C) + same phone"
echo ""
echo "Unique patients: 118 (U-001 to U-118)"
