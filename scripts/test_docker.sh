#!/usr/bin/env bash
# ==============================================================================
# EasyLens Docker Automated Verification Suite
# Validates all deployment options documented in README.md & DOCKER.md
# ==============================================================================

set -euo pipefail

PORT=8080
BASE_URL="http://localhost:${PORT}"
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    exit 1
}

cleanup() {
    log_info "Cleaning up potential leftover containers..."
    docker compose down --remove-orphans >/dev/null 2>&1 || true
    docker rm -f easylens_app >/dev/null 2>&1 || true
    docker rm -f easylens_live >/dev/null 2>&1 || true
}

trap cleanup EXIT

# 0. Check Docker daemon availability
log_info "Checking Docker daemon status..."
if ! docker info >/dev/null 2>&1; then
    log_fail "Docker daemon is not running. Please start Docker Desktop."
fi
log_pass "Docker daemon is active and responsive."

cleanup

# ------------------------------------------------------------------------------
# Test 1: Option 1 - Local Build via Docker Compose
# ------------------------------------------------------------------------------
log_info "Starting Test 1: Option 1 (Docker Compose)..."
docker compose up --build -d

log_info "Waiting for container health check to report healthy (timeout 30s)..."
healthy=false
for i in $(seq 1 15); do
    STATUS=$(docker compose ps --format json 2>/dev/null | grep -o '"Health":"[^"]*"' | head -n1 || echo "")
    if [[ "$STATUS" == *'"Health":"healthy"'* ]] || [[ "$(docker inspect --format='{{.State.Health.Status}}' easylens_mobile_server 2>/dev/null || echo "")" == "healthy" ]]; then
        healthy=true
        break
    fi
    sleep 2
done

if [ "$healthy" = true ]; then
    log_pass "Container reported healthy."
else
    log_info "Container healthcheck still starting, proceeding with HTTP probe..."
fi

log_info "Probing ${BASE_URL} via curl..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/")
if [ "$HTTP_STATUS" -eq 200 ]; then
    log_pass "Option 1 (Docker Compose) returned HTTP ${HTTP_STATUS} OK."
else
    log_fail "Option 1 expected HTTP 200 but received ${HTTP_STATUS}."
fi

log_info "Tearing down Docker Compose..."
docker compose down
log_pass "Option 1 passed and torn down cleanly."

# ------------------------------------------------------------------------------
# Test 2: Option 2 - Standalone Docker CLI (Local Build)
# ------------------------------------------------------------------------------
log_info "Starting Test 2: Option 2 (Standalone Docker CLI)..."
docker build -t easylens:latest .
docker run -d --name easylens_app -p "${PORT}:80" --restart always easylens:latest

sleep 3
log_info "Probing ${BASE_URL} via curl..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/")
if [ "$HTTP_STATUS" -eq 200 ]; then
    log_pass "Option 2 (Standalone Docker CLI) returned HTTP ${HTTP_STATUS} OK."
else
    log_fail "Option 2 expected HTTP 200 but received ${HTTP_STATUS}."
fi

log_info "Stopping and removing easylens_app..."
docker stop easylens_app >/dev/null
docker rm easylens_app >/dev/null
log_pass "Option 2 passed and cleaned up."

# ------------------------------------------------------------------------------
# Test 3: Option 3 - GHCR Pre-Built Package
# ------------------------------------------------------------------------------
log_info "Starting Test 3: Option 3 (GitHub Container Registry Image)..."
docker run -d --name easylens_live -p "${PORT}:80" --restart always ghcr.io/thes-is-it/easylens:latest

sleep 3
log_info "Probing ${BASE_URL} via curl..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/")
if [ "$HTTP_STATUS" -eq 200 ]; then
    log_pass "Option 3 (GHCR Image) returned HTTP ${HTTP_STATUS} OK."
else
    log_fail "Option 3 expected HTTP 200 but received ${HTTP_STATUS}."
fi

log_info "Stopping and removing easylens_live..."
docker stop easylens_live >/dev/null
docker rm easylens_live >/dev/null
log_pass "Option 3 passed and cleaned up."

echo ""
echo "=============================================================================="
log_pass "ALL DOCKER README COMMANDS VERIFIED AND FULLY FUNCTIONAL!"
echo "=============================================================================="
