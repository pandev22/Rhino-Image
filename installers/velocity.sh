#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Velocity Modern Proxy (PaperMC)
# Uses the PaperMC Fill v3 API (fill.papermc.io) with checksum verification.
#
# Security / reliability rules:
# - HTTPS only (redirects restricted to HTTPS).
# - Download to a temporary file, verify SHA-256, then rename atomically.
# - API errors / empty results fail the installation.
# - SERVER_JARFILE, VELOCITY_VERSION, BUILD_NUMBER and SERVER_PORT are validated.
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

VELOCITY_VERSION="${VELOCITY_VERSION:-latest}"
BUILD_NUMBER="${BUILD_NUMBER:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-velocity.jar}"
PROXY_PORT="${SERVER_PORT:-25577}"

RHINO_UA="RhinoPanel/1.0 (https://rhino.overnode.fr)"
API_BASE="https://fill.papermc.io/v3/projects/velocity"

TMP_DIR="${TARGET_DIR}/.rhino-install-$$"
mkdir -p "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT

info() { printf '\033[1;33m[rhino-installer]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[rhino-installer]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[rhino-installer]\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }

need curl
need jq
need sha256sum

case "${SERVER_JARFILE}" in
    ""|*/*|*..*|*[!A-Za-z0-9._-]*) fail "invalid SERVER_JARFILE: ${SERVER_JARFILE}" ;;
esac
case "${SERVER_JARFILE}" in
    *.jar) ;;
    *) fail "SERVER_JARFILE must end with .jar" ;;
esac
case "${PROXY_PORT}" in
    ""|*[!0-9]*) fail "invalid SERVER_PORT: ${PROXY_PORT}" ;;
esac
[ "${PROXY_PORT}" -ge 1 ] && [ "${PROXY_PORT}" -le 65535 ] || fail "SERVER_PORT out of range"
case "${VELOCITY_VERSION}" in
    latest) ;;
    *[!0-9A-Za-z._-]*) fail "invalid VELOCITY_VERSION: ${VELOCITY_VERSION}" ;;
esac
case "${BUILD_NUMBER}" in
    latest) ;;
    *[!0-9]*) fail "invalid BUILD_NUMBER: ${BUILD_NUMBER}" ;;
esac

fetch() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 \
        --proto '=https' --proto-redir '=https' \
        -H "User-Agent: ${RHINO_UA}" "$1"
}

download() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 900 \
        --proto '=https' --proto-redir '=https' \
        -H "User-Agent: ${RHINO_UA}" -o "$2" "$1"
}

info "Setting up Velocity Proxy in ${TARGET_DIR}..."

if [ "${VELOCITY_VERSION}" = "latest" ]; then
    info "Resolving the latest supported Velocity version from the Fill API..."
    VERSIONS_DATA=$(fetch "${API_BASE}/versions") || fail "cannot reach the PaperMC Fill API"
    VELOCITY_VERSION=$(printf '%s' "${VERSIONS_DATA}" | jq -er '
        ([.versions[] | select(.version.support.status == "SUPPORTED")][0].version.id)
        // .versions[0].version.id
    ') || fail "cannot resolve the latest Velocity version"
    case "${VELOCITY_VERSION}" in
        ""|*[!0-9A-Za-z._-]*) fail "invalid Velocity version returned by the API" ;;
    esac
    ok "Resolved Velocity version: ${VELOCITY_VERSION}"
fi

info "Fetching Velocity builds for ${VELOCITY_VERSION}..."
BUILDS_DATA=$(fetch "${API_BASE}/versions/${VELOCITY_VERSION}/builds") \
    || fail "cannot fetch Velocity builds for ${VELOCITY_VERSION}"

if [ "${BUILD_NUMBER}" = "latest" ]; then
    BUILD_JSON=$(printf '%s' "${BUILDS_DATA}" | jq -ec '
        if any(.channel == "STABLE") then
            (map(select(.channel == "STABLE")) | first)
        else
            .[0]
        end
    ') || fail "no Velocity build available for ${VELOCITY_VERSION}"
else
    BUILD_JSON=$(printf '%s' "${BUILDS_DATA}" | jq -ec --argjson id "${BUILD_NUMBER}" '
        map(select(.id == $id)) | first
    ') || fail "Velocity build #${BUILD_NUMBER} not found for ${VELOCITY_VERSION}"
fi

DOWNLOAD_URL=$(printf '%s' "${BUILD_JSON}" | jq -er '.downloads["server:default"].url') \
    || fail "Velocity download URL missing"
SHA256=$(printf '%s' "${BUILD_JSON}" | jq -er '.downloads["server:default"].checksums.sha256') \
    || fail "Velocity checksum missing"
RESOLVED_BUILD=$(printf '%s' "${BUILD_JSON}" | jq -er '.id') \
    || fail "Velocity build id missing"
case "${DOWNLOAD_URL}" in
    https://*) ;;
    *) fail "refusing a non-HTTPS Velocity download URL" ;;
esac
case "${SHA256}" in
    *[!0-9a-fA-F]*|"") fail "invalid Velocity checksum" ;;
esac
[ "${#SHA256}" -eq 64 ] || fail "invalid Velocity checksum length"

ok "Resolved Velocity build #${RESOLVED_BUILD}"
info "Downloading Velocity ${VELOCITY_VERSION} build ${RESOLVED_BUILD}..."
download "${DOWNLOAD_URL}" "${TMP_DIR}/velocity.jar" || fail "Velocity download failed"
printf '%s  %s\n' "${SHA256}" "${TMP_DIR}/velocity.jar" | sha256sum -c - >/dev/null \
    || fail "Velocity checksum verification failed"
mv -f "${TMP_DIR}/velocity.jar" "${SERVER_JARFILE}"
chmod 0644 "${SERVER_JARFILE}"
ok "Velocity JAR saved to ${SERVER_JARFILE}"

if [ ! -f "velocity.toml" ]; then
    cat <<EOF > velocity.toml
config-version = "2.7"
bind = "0.0.0.0:${PROXY_PORT}"
motd = "<#f59e0b>A Rhino Velocity Proxy"
show-max-players = 500
online-mode = true
force-key-authentication = true
prevent-client-proxy-connections = false
player-info-forwarding-mode = "modern"
forwarding-secret-file = "forwarding.secret"

[servers]
lobby = "127.0.0.1:25565"
try = [ "lobby" ]

[forced-hosts]

[advanced]
compression-threshold = 256
compression-level = -1
login-ratelimit = 3000
connection-timeout = 5000
read-timeout = 30000
EOF
    ok "Generated baseline velocity.toml configured for port ${PROXY_PORT}."
fi

ok "Velocity proxy installation completed successfully (build ${RESOLVED_BUILD})."
