#!/usr/bin/env bash
# =============================================================
# High-volume patient seeder for FHIR R4 backend (IHE PDQm)
# Usage: bash seed-large.sh [total] [concurrency] [start_index]
# Example: bash seed-large.sh 500000 40 1
# =============================================================

set -u

BASE_URL="${BASE_URL:-http://localhost:9090/fhir/r4}"
SYSTEM="${SYSTEM:-http://www.acme.com/identifiers/patient}"
TOTAL="${1:-500000}"
CONCURRENCY="${2:-40}"
START_INDEX="${3:-1}"
USER_ID="${USER_ID:-bulk-seeder}"

if ! [[ "$TOTAL" =~ ^[0-9]+$ ]] || [ "$TOTAL" -le 0 ]; then
  echo "Invalid total: $TOTAL"
  exit 1
fi

if ! [[ "$CONCURRENCY" =~ ^[0-9]+$ ]] || [ "$CONCURRENCY" -le 0 ]; then
  echo "Invalid concurrency: $CONCURRENCY"
  exit 1
fi

if ! [[ "$START_INDEX" =~ ^[0-9]+$ ]] || [ "$START_INDEX" -le 0 ]; then
  echo "Invalid start index: $START_INDEX"
  exit 1
fi

TOKEN="${TOKEN:-$(echo -n '{"sub":"admin@demo.org","role":"admin","exp":9999999999999}' | base64 -w 0 2>/dev/null || echo -n '{"sub":"admin@demo.org","role":"admin","exp":9999999999999}' | base64)}"
ENCODED_SYSTEM=$(echo -n "$SYSTEM" | sed 's/:/%3A/g; s/\//%2F/g; s/\./%2E/g')

given_names=(James Mary Robert Jennifer Michael Elizabeth David Sarah William Patricia Richard Linda Joseph Barbara Thomas Susan Charles Jessica Daniel Karen Matthew Nancy Andrew Betty Joshua Margaret Christopher Sandra Anthony Ashley Mark Emily Steven Donna Paul Michelle Kevin Dorothy Brian Carol George Amanda Edward Melissa Henry Deborah Samuel Stephanie Jason Lisa Ryan Laura Jacob Cynthia Nicholas Angela Tyler)
family_names=(Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Hernandez Lopez Gonzalez Wilson Anderson Thomas Taylor Moore Jackson Martin Lee Perez Thompson White Harris Sanchez Clark Ramirez Lewis Robinson Walker Young Allen King Wright Scott Torres Nguyen Hill Flores Green Adams Nelson Baker Hall Rivera Campbell Mitchell Carter Roberts Gomez Phillips Evans Turner Diaz Parker Cruz Edwards Collins Reyes Stewart Morris Morales Murphy Cook Rogers Gutierrez Ortiz Morgan Cooper Peterson Bailey Reed Kelly Howard Ramos Kim Cox Ward Richardson Watson Brooks Chavez Wood James Bennett Gray Mendoza Ruiz Hughes Price Alvarez Castillo Sanders Patel Myers Long Ross Foster Jimenez Powell Jenkins Perry Russell Sullivan Bell Coleman Butler Henderson Barnett Gonzales Fisher Vasquez Simmons Romero Jordan Patterson Alexander Hamilton Graham Reynolds Griffin Wallace West Cole Hayes Bryant Herrera Gibson Ellis Tran Medina Aguilar Stevens Murray Ford Castro Marshall Owens Harrison Fernandez Mcdonald Woods Washington Kennedy Wells Vargas Henry Chen Freeman Webb Tucker Guzman Burns Crawford Olson Simpson Porter Hunter Gordon Mendez Silva Shaw Snyder Mason Dixon Munoz Hunt Hicks Holmes Palmer Wagner Black Robertson Boyd Rose Stone Salazar Fox Warren Mills Meyer Rice Schmidt Garza Daniels Ferguson Nichols Stephens Soto Weaver Ryan Gardner Payne Grant Dunn Kelley Spencer Hawkins Arnold Pierce Vazquez Hansen Peters Santos Hart Bradley Knight Elliott Cunningham Duncan Armstrong Hudson Carroll Lane Riley Andrews Alvarado Ray Delgado Berry Perkins Hoffman Johnston Matthews Pena Richards Contreras Willis Carpenter Lawrence Sandoval Guerrero George Chapman Rios Estrada Ortega Watkins Greene Nunez Wheeler Valdez Harper Burke Larson Santiago Maldonado Morrison Franklin Carlson Austin Dominguez Carr Lawson Jacobs Obrien Lynch Singh Vega Bishop Montgomery Oliver Jensen Harvey Williamson Gilbert Dean Sims Espinoza Howell Li Wong Reid Hanson Leake Schultz Hartman)
streets=("Oak Avenue" "Elm Street" "Main Street" "Maple Drive" "Cedar Lane" "Pine Road" "Broadway" "Park Place" "Lincoln Avenue" "Washington Blvd")
cities=("New York|Manhattan|10001" "Los Angeles|LA County|90001" "Chicago|Cook County|60601" "Houston|Harris County|77001" "Phoenix|Maricopa|85001" "Philadelphia|Philadelphia|19101" "San Antonio|Bexar County|78201" "San Diego|San Diego|92101" "Dallas|Dallas County|75201" "Austin|Travis County|73301")

tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t bulkseed)"
ok_file="${tmp_dir}/ok.log"
fail_file="${tmp_dir}/fail.log"
touch "$ok_file" "$fail_file"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

send_patient() {
  local i="$1"
  local gn_len="${#given_names[@]}"
  local fn_len="${#family_names[@]}"
  local st_len="${#streets[@]}"
  local ct_len="${#cities[@]}"

  local given="${given_names[$((i % gn_len))]}"
  local middle="M$((i % 97))"
  local family="${family_names[$(((i * 7) % fn_len))]}"
  local gender="male"
  if (( i % 2 == 0 )); then
    gender="female"
  fi

  local year=$((1950 + (i % 61)))
  local month=$((1 + ((i / 61) % 12)))
  local day=$((1 + ((i / (61 * 12)) % 28)))
  local birth
  printf -v birth "%04d-%02d-%02d" "$year" "$month" "$day"

  local phone
  printf -v phone "+1%010d" "$((2000000000 + (i % 7000000000)))"

  local city_triplet="${cities[$(((i * 11) % ct_len))]}"
  IFS='|' read -r city district postal <<< "$city_triplet"

  local house="$((1 + (i % 9999)))"
  local street="${streets[$(((i * 13) % st_len))]}"
  local nic
  printf -v nic "BULK-%07d" "$i"

  local payload
  payload=$(cat <<EOF
{
  "resourceType": "Patient",
  "identifier": [
    {
      "use": "official",
      "system": "${SYSTEM}",
      "value": "${nic}"
    }
  ],
  "active": true,
  "name": [
    {
      "use": "official",
      "family": "${family}",
      "given": ["${given}", "${middle}"]
    }
  ],
  "telecom": [
    {
      "system": "phone",
      "value": "${phone}",
      "use": "mobile"
    }
  ],
  "gender": "${gender}",
  "birthDate": "${birth}",
  "address": [
    {
      "use": "home",
      "line": ["${house}", "${street}"],
      "city": "${city}",
      "district": "${district}",
      "postalCode": "${postal}",
      "country": "US"
    }
  ]
}
EOF
)

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT "${BASE_URL}/Patient?identifier=${ENCODED_SYSTEM}|${nic}" \
    -H "Content-Type: application/fhir+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-User-Id: ${USER_ID}" \
    --connect-timeout 5 --max-time 30 \
    -d "${payload}")

  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    echo "$i" >> "$ok_file"
  else
    echo "${i}|${nic}|${http_code}" >> "$fail_file"
  fi
}

echo "=========================================================="
echo "Bulk seeding start"
echo "Base URL:      ${BASE_URL}"
echo "Total:         ${TOTAL}"
echo "Concurrency:   ${CONCURRENCY}"
echo "Start index:   ${START_INDEX}"
echo "=========================================================="

running=0
submitted=0
start_ts="$(date +%s)"

for ((offset=0; offset<TOTAL; offset++)); do
  i=$((START_INDEX + offset))
  send_patient "$i" &
  running=$((running + 1))
  submitted=$((submitted + 1))

  if (( submitted % 1000 == 0 )); then
    elapsed=$(( $(date +%s) - start_ts ))
    echo "Submitted ${submitted}/${TOTAL} (elapsed ${elapsed}s)"
  fi

  if (( running >= CONCURRENCY )); then
    wait -n
    running=$((running - 1))
  fi
done

wait

ok_count=$(wc -l < "$ok_file" | tr -d ' ')
fail_count=$(wc -l < "$fail_file" | tr -d ' ')
end_ts="$(date +%s)"
elapsed=$((end_ts - start_ts))

echo "=========================================================="
echo "Bulk seeding completed"
echo "Success:       ${ok_count}"
echo "Failed:        ${fail_count}"
echo "Duration:      ${elapsed}s"
if (( elapsed > 0 )); then
  rate=$(( ok_count / elapsed ))
  echo "Avg success/s: ${rate}"
fi
if (( fail_count > 0 )); then
  echo "Sample failures:"
  head -n 10 "$fail_file"
fi
echo "=========================================================="
