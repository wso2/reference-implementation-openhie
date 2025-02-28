#!/bin/bash

LOG_DIR="$(pwd)/logs"
mkdir -p "$LOG_DIR"

run_service() {
    sleep 5
    echo "Starting $1..."
    cd "$2" || exit 1
    log_file_name=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    bal run >> "$LOG_DIR/${log_file_name}.log" 2>&1 &
    echo "$1 started successfully. Logs are being written to ${1}.log"
    cd - > /dev/null  # Return to the original directory
}

stop_services() {
    docker-compose down

    ALL_PIDS=""

    echo "Checking for processes for websubhub on port 9095..."
    PIDS=$(lsof -ti:9095)
    if [ -n "$PIDS" ]; then
        ALL_PIDS="$ALL_PIDS $PIDS"
        echo "Stopped WebSubHub."
    else
        echo "No processes found on port 9095."
    fi
    
    echo "Checking for processes for iol-core on port 9080..."
    PIDS=$(lsof -ti:9080)
    if [ -n "$PIDS" ]; then
        ALL_PIDS="$ALL_PIDS $PIDS"
        echo "Stopped HTTP Listener on IoL Core."
    else
        echo "No processes found on port 9080."
    fi

    echo "Checking for processes for iol-core on port 9081..."
    PIDS=$(lsof -ti:9081)
    if [ -n "$PIDS" ]; then
        ALL_PIDS="$ALL_PIDS $PIDS"
        echo "Stopped TCP Listener on IoL Core."
    else
        echo "No processes found on port 9081."
    fi

    echo "Checking for processes for audit-service on port 9091..."
    PIDS=$(lsof -ti:9091)
    if [ -n "$PIDS" ]; then
        ALL_PIDS="$ALL_PIDS $PIDS"
        echo "Stopped Audit Service."
    else
        echo "No processes found on port 9091."
    fi

    echo "Checking for processes for patient demographic service on port 9092..."
    PIDS=$(lsof -ti:9092)
    if [ -n "$PIDS" ]; then
        ALL_PIDS="$ALL_PIDS $PIDS"
        echo "Stopped Patient Demographic Service."
    else
        echo "No processes found on port 9092."
    fi

    if [ -n "$ALL_PIDS" ]; then
        kill $ALL_PIDS
    else
        echo "No processes to kill."
    fi

    echo "All services stopped."
}

# Trap SIGINT and SIGTERM to stop services on exit
trap stop_services SIGINT SIGTERM

# Array to hold service PIDs
SERVICE_PIDS=()

# Start WebSubHub
run_service "WebSubHub" "websubhub/hub"

# Start IoL Core
run_service "IoL Core" "iol-core"

# Start Audit Service
run_service "Audit Service" "audit-service"

# Start FHIR Workflow
run_service "FHIR Workflow" "fhir-workflows/patient-demographic-management-service"

# Start OpenSearch
echo "Starting OpenSearch..."
cd opensearch || exit 1
docker-compose up -d
echo "All services started successfully."

read -p "Press Enter to stop all services..." 
stop_services