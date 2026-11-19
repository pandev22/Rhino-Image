#!/usr/bin/env bash
# ==============================================================================
# Rhino Panel - Image DevSecOps Verification Script
# Validates security compliance, least-privilege, and runtime behavior:
# - Non-root execution (UID 1000, GID 1000)
# - Read-only rootfs enforcement (--read-only)
# - Full capability drop (--cap-drop=ALL)
# - Privilege escalation blocking (--security-opt=no-new-privileges:true)
# - PID 1 Rust entrypoint signal handling (SIGTERM propagation)
# - Safe environment variable interpolation ({{VAR}} / ${VAR})
# - Child process exit code propagation
# ==============================================================================

set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PASSED_COUNT=0
FAILED_COUNT=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    PASSED_COUNT=$((PASSED_COUNT + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    FAILED_COUNT=$((FAILED_COUNT + 1))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${CYAN}${BOLD}================================================================${NC}"
echo -e "${CYAN}${BOLD}       🦏 Rhino Images - DevSecOps Verification Suite           ${NC}"
echo -e "${CYAN}${BOLD}================================================================${NC}"
echo -e "Repository root: ${REPO_ROOT}"
echo

# ------------------------------------------------------------------------------
# 1. Entrypoint Rust Unit & Format Tests
# ------------------------------------------------------------------------------
echo -e "${BOLD}--- Step 1: Validating Entrypoint Rust Codebase ---${NC}"
if command -v cargo >/dev/null 2>&1; then
    log_info "Running cargo test in entrypoint/..."
    if (cd "${REPO_ROOT}/entrypoint" && cargo test --quiet); then
        log_pass "Entrypoint unit tests passed"
    else
        log_fail "Entrypoint unit tests failed"
    fi

    log_info "Running cargo clippy in entrypoint/..."
    if (cd "${REPO_ROOT}/entrypoint" && cargo clippy --quiet --all-targets -- -D warnings); then
        log_pass "Entrypoint clippy (0 warnings) passed"
    else
        log_fail "Entrypoint clippy checks failed"
    fi
else
    log_warn "Cargo not found on host, skipping local Rust compilation checks (will be checked in Docker)"
fi

echo

# ------------------------------------------------------------------------------
# 2. Build Test Target (images/generic/Dockerfile)
# ------------------------------------------------------------------------------
echo -e "${BOLD}--- Step 2: Building Test Image (Generic Runtime) ---${NC}"
TEST_IMAGE_TAG="rhino-verify-test:local"

log_info "Building ${TEST_IMAGE_TAG}..."
if docker build -q -f "${REPO_ROOT}/images/generic/Dockerfile" -t "${TEST_IMAGE_TAG}" "${REPO_ROOT}" >/dev/null; then
    log_pass "Successfully built test image: ${TEST_IMAGE_TAG}"
else
    log_fail "Failed to build test image"
    exit 1
fi

echo

# ------------------------------------------------------------------------------
# 3. Security Profile: Non-root execution
# ------------------------------------------------------------------------------
echo -e "${BOLD}--- Step 3: Verifying Least-Privilege & Non-Root Execution ---${NC}"
UID_GID_OUT=$(docker run --rm "${TEST_IMAGE_TAG}" id -u -g 2>/dev/null || docker run --rm -e STARTUP="id -u -g" "${TEST_IMAGE_TAG}" 2>&1 | grep -E "^1000 1000" || true)

CONTAINER_UID=$(docker run --rm -e STARTUP="id -u" "${TEST_IMAGE_TAG}" 2>&1 | tail -n 3 | grep -oE "^[0-9]+" || echo "unknown")
CONTAINER_GID=$(docker run --rm -e STARTUP="id -g" "${TEST_IMAGE_TAG}" 2>&1 | tail -n 3 | grep -oE "^[0-9]+" || echo "unknown")

if [ "${CONTAINER_UID}" = "1000" ] && [ "${CONTAINER_GID}" = "1000" ]; then
    log_pass "Container runs strictly as unprivileged user 'rhino' (UID=1000, GID=1000)"
else
    log_fail "Non-root verification failed (got UID=${CONTAINER_UID}, GID=${CONTAINER_GID}, expected 1000/1000)"
fi

# ------------------------------------------------------------------------------
# 4. Security Profile: Read-Only Root Filesystem & Dropped Capabilities
# ------------------------------------------------------------------------------
echo -e "${BOLD}--- Step 4: Testing Hardened Container Isolation ---${NC}"
log_info "Testing container run with --read-only, --cap-drop=ALL, and no-new-privileges..."

RO_TEST_CMD='sh -c "touch /read_only_test 2>/dev/null && echo WRITABLE || echo READONLY"'
RO_RESULT=$(docker run --rm \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid \
    --tmpfs /home/container:rw,exec,nosuid \
    --cap-drop=ALL \
    --security-opt=no-new-privileges:true \
    -e STARTUP="${RO_TEST_CMD}" \
    "${TEST_IMAGE_TAG}" 2>&1 | grep -E "READONLY|WRITABLE" || echo "ERROR")

if [[ "${RO_RESULT}" == *"READONLY"* ]]; then
    log_pass "Root filesystem is strictly READ-ONLY (arbitrary writes to / are rejected)"
else
    log_fail "Read-only test failed or root filesystem was writable"
fi

# Test that /home/container is writable via tmpfs/volume
WRITABLE_WORKDIR=$(docker run --rm \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid \
    --tmpfs /home/container:rw,exec,nosuid \
    --cap-drop=ALL \
    --security-opt=no-new-privileges:true \
    -e STARTUP='sh -c "touch /home/container/testfile && echo OK || echo FAIL"' \
    "${TEST_IMAGE_TAG}" 2>&1 | grep -E "OK|FAIL" || echo "FAIL")

if [[ "${WRITABLE_WORKDIR}" == *"OK"* ]]; then
    log_pass "Game server working directory (/home/container) is properly writable under hardened profile"
else
    log_fail "Working directory was not writable"
fi

# ------------------------------------------------------------------------------
# 5. Variable Interpolation (Rhino {{VAR}} and POSIX ${VAR})
# ------------------------------------------------------------------------------
echo -e "${BOLD}--- Step 5: Testing Safe Variable Interpolation in Rust PID 1 ---${NC}"

INTERP_OUTPUT=$(docker run --rm \
    -e SERVER_PORT=25565 \
    -e SERVER_MEMORY=4096 \
    -e STARTUP='echo "RhinoServer: Port {{SERVER_PORT}} Memory ${SERVER_MEMORY}M"' \
    "${TEST_IMAGE_TAG}" 2>&1 | grep "RhinoServer:" || echo "NOT_FOUND")

EXPECTED="RhinoServer: Port 25565 Memory 4096M"
if [[ "${INTERP_OUTPUT}" == *"${EXPECTED}"* ]]; then
    log_pass "Safe variable interpolation succeeded: '${EXPECTED}'"
else
    log_fail "Variable interpolation mismatch. Got: '${INTERP_OUTPUT}'"
fi

# ------------------------------------------------------------------------------
# 6. Exit Code Propagation
# ------------------------------------------------------------------------------
echo -e "${BOLD}--- Step 6: Testing Exit Code Propagation ---${NC}"

set +e
docker run --rm -e STARTUP='sh -c "exit 42"' "${TEST_IMAGE_TAG}" >/dev/null 2>&1
ACTUAL_EXIT_CODE=$?
set -e

if [ "${ACTUAL_EXIT_CODE}" -eq 42 ]; then
    log_pass "Child process exit code (42) successfully forwarded by PID 1 entrypoint"
else
    log_fail "Exit code propagation failed (got ${ACTUAL_EXIT_CODE}, expected 42)"
fi

# ------------------------------------------------------------------------------
# 7. Signal Handling & Graceful Shutdown (SIGTERM)
# ------------------------------------------------------------------------------
echo -e "${BOLD}--- Step 7: Testing Signal Handling (SIGTERM Graceful Stop) ---${NC}"

CONTAINER_ID=$(docker run -d \
    -e STARTUP='sh -c "trap \"echo TerminatingGracefully; exit 0\" TERM; while true; do sleep 1; done"' \
    "${TEST_IMAGE_TAG}")

sleep 1
log_info "Sending SIGTERM to container ${CONTAINER_ID:0:12}..."
docker stop -t 5 "${CONTAINER_ID}" >/dev/null 2>&1 || true

LOGS=$(docker logs "${CONTAINER_ID}" 2>&1 || true)
docker rm -f "${CONTAINER_ID}" >/dev/null 2>&1 || true

if [[ "${LOGS}" == *"SIGTERM"* ]] || [[ "${LOGS}" == *"TerminatingGracefully"* ]]; then
    log_pass "PID 1 entrypoint trapped SIGTERM and forwarded it to child process group"
else
    log_fail "SIGTERM forwarding did not produce expected graceful shutdown logs"
fi

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
docker rmi "${TEST_IMAGE_TAG}" >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# Final Summary
# ------------------------------------------------------------------------------
echo
echo -e "${CYAN}${BOLD}================================================================${NC}"
echo -e "${BOLD}Verification Summary: ${GREEN}${PASSED_COUNT} Passed${NC}, ${RED}${FAILED_COUNT} Failed${NC}"
echo -e "${CYAN}${BOLD}================================================================${NC}"

if [ "${FAILED_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ All Rhino DevSecOps standards and runtime checks passed!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}✗ Some checks failed. Review logs above.${NC}"
    exit 1
fi
