#!/usr/bin/env bash
# Starts all CR services: audit-service, cr-core, and cr-frontend.
# Press Ctrl+C to stop everything.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDS=()

# Locate the bal executable (Git Bash on Windows requires the full .bat path)
if command -v bal &>/dev/null; then
    BAL="bal"
elif [ -f "/c/Program Files/Ballerina/bin/bal.bat" ]; then
    BAL="/c/Program Files/Ballerina/bin/bal.bat"
else
    echo "Error: 'bal' not found. Install Ballerina 2201.13.1 from https://ballerina.io/downloads/" >&2
    exit 1
fi

cleanup() {
    echo ""
    echo "Stopping all services..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null
    echo "Done."
}
trap cleanup EXIT INT TERM

# 1. Audit service (cr-core sends audit events to it, so start first)
echo "Starting audit-service on :9093..."
(cd "$ROOT/audit-service" && "$BAL" run) &
PIDS+=($!)

# Give audit-service time to bind before cr-core tries to connect
sleep 4

# 2. MPI backend
echo "Starting cr-core on :9090..."
(cd "$ROOT/cr-core" && "$BAL" run) &
PIDS+=($!)

# 3. Frontend (install deps if node_modules is missing)
if [ ! -d "$ROOT/cr-frontend/node_modules" ]; then
    echo "Installing frontend dependencies..."
    (cd "$ROOT/cr-frontend" && npm install)
fi
echo "Starting cr-frontend on :5173..."
(cd "$ROOT/cr-frontend" && npm run dev) &
PIDS+=($!)

echo ""
echo "All services started:"
echo "  Audit Service  → http://localhost:9093"
echo "  MPI Backend    → http://localhost:9090/fhir/r4"
echo "  Frontend       → http://localhost:5173"
echo ""
echo "Press Ctrl+C to stop all services."

wait
