#!/bin/bash

# Add Ballerina to PATH (needed when running via Git Bash on Windows)
export PATH="/c/Program Files/Ballerina/bin:$PATH"

SCRIPT_DIR="$(pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# Array to hold background service PIDs
SERVICE_PIDS=()

# Wait until a URL responds with any HTTP status (2xx/3xx/4xx/5xx = service is up)
wait_for() {
    local name="$1"
    local url="$2"
    local max_wait="${3:-120}"
    echo "Waiting for $name to be ready..."
    local elapsed=0
    until curl -sk -o /dev/null -w "%{http_code}" "$url" | grep -qE "^[2345]"; do
        if [ "$elapsed" -ge "$max_wait" ]; then
            echo "ERROR: $name did not become ready within ${max_wait}s. Check logs."
            exit 1
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    echo "$name is ready."
}

run_service() {
    local name="$1"
    local dir="$2"
    echo "Starting $name..."
    cd "$SCRIPT_DIR/$dir" || { echo "Failed to enter $dir"; return 1; }
    local log_file_name
    log_file_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    bal.bat run >> "$LOG_DIR/${log_file_name}.log" 2>&1 &
    SERVICE_PIDS+=($!)
    echo "$name starting in background. Logs: logs/${log_file_name}.log"
    cd "$SCRIPT_DIR" > /dev/null
}

stop_services() {
    # Clear trap first to prevent re-entrant calls
    trap - SIGINT SIGTERM

    echo "Stopping Ballerina services..."
    for pid in "${SERVICE_PIDS[@]}"; do
        taskkill //PID "$pid" //F > /dev/null 2>&1 || kill "$pid" 2>/dev/null
    done

    echo "Stopping OpenSearch and HAPI FHIR..."
    cd "$SCRIPT_DIR/opensearch" || true
    docker-compose down

    echo "All services stopped."
    exit 0
}

# Trap SIGINT and SIGTERM to stop services on exit
trap stop_services SIGINT SIGTERM

# ── Step 1: Start Docker services first (HAPI FHIR + OpenSearch) ──────────────
echo "Starting Docker services (HAPI FHIR + OpenSearch)..."
cd "$SCRIPT_DIR/opensearch" || exit 1
docker-compose up -d
cd "$SCRIPT_DIR"

# Wait for HAPI FHIR before starting services that depend on it
wait_for "HAPI FHIR" "http://localhost:8081/fhir/metadata" 180

# ── Step 2: Start WebSubHub ───────────────────────────────────────────────────
run_service "WebSubHub" "websubhub/hub"
wait_for "WebSubHub" "http://localhost:9095/hub" 120

# ── Step 3: Start FHIR Workflow and Audit Service (both depend on the above) ──
run_service "FHIR Workflow" "fhir-workflows/patient-demographic-management-service"
run_service "Audit Service" "audit-service"
wait_for "FHIR Workflow" "http://localhost:9092" 120

# ── Step 4: Start IoL Core (depends on WebSubHub + FHIR Workflow) ─────────────
run_service "IoL Core" "iol-core"
wait_for "IoL Core" "http://localhost:9093" 120

echo ""
echo "All services started successfully."
echo "  IoL Core HTTP : http://localhost:9093"
echo "  IoL Core TCP  : tcp://localhost:9094"
echo "  Audit Service : http://localhost:9091"
echo "  WebSub Hub    : http://localhost:9095/hub"
echo "  FHIR Workflow : http://localhost:9092"
echo "  OpenSearch    : http://localhost:5601"
echo ""

read -p "Press Enter to stop all services..."
stop_services
