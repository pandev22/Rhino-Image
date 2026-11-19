#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Velocity Modern Proxy (PaperMC)
# Uses PaperMC Fill v3 API (fill.papermc.io)
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

VELOCITY_VERSION="${VELOCITY_VERSION:-latest}"
BUILD_NUMBER="${BUILD_NUMBER:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-velocity.jar}"
PROXY_PORT="${SERVER_PORT:-25577}"

RHINO_UA="RhinoPanel/1.0 (https://rhino.overnode.fr)"
API_BASE="https://fill.papermc.io/v3/projects/velocity"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Velocity Proxy in ${TARGET_DIR}..."

# ---------------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------------
if [ "${VELOCITY_VERSION}" = "latest" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Resolving latest stable Velocity version from Fill API..."
    PROJECT_DATA=$(curl -fsSL -H "User-Agent: ${RHINO_UA}" "${API_BASE}")
    VELOCITY_VERSION=$(echo "${PROJECT_DATA}" | jq -r '
        .versions | keys_unsorted[0] as $group | .[$group]
        | map(select(test("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$")))
        | if length > 0 then .[0] else error("no stable") end
    ' 2>/dev/null || echo "${PROJECT_DATA}" | jq -r '.versions | keys_unsorted[0] as $g | .[$g][0]')
    if [ -z "${VELOCITY_VERSION}" ] || [ "${VELOCITY_VERSION}" = "null" ]; then
        echo -e "\e[1;31m[rhino-installer]\e[0m Failed to resolve latest Velocity version."
        exit 1
    fi
    echo -e "\e[1;32m[rhino-installer]\e[0m Resolved latest Velocity version: ${VELOCITY_VERSION}"
fi

# ---------------------------------------------------------------------------
# Resolve build and get download URL
# ---------------------------------------------------------------------------
echo -e "\e[1;33m[rhino-installer]\e[0m Fetching builds for Velocity ${VELOCITY_VERSION}..."
BUILDS_DATA=$(curl -fsSL -H "User-Agent: ${RHINO_UA}" "${API_BASE}/versions/${VELOCITY_VERSION}/builds")

if [ "${BUILD_NUMBER}" = "latest" ]; then
    DOWNLOAD_URL=$(echo "${BUILDS_DATA}" | jq -r '(map(select(.channel == "STABLE")) | last // last) | .downloads["server:default"].url')
    BUILD_NUMBER=$(echo "${BUILDS_DATA}" | jq -r '(map(select(.channel == "STABLE")) | last // last) | .id')
else
    DOWNLOAD_URL=$(echo "${BUILDS_DATA}" | jq -r --argjson id "${BUILD_NUMBER}" 'map(select(.id == $id)) | .[0] | .downloads["server:default"].url')
fi

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Failed to find download URL for Velocity ${VELOCITY_VERSION} build ${BUILD_NUMBER}."
    exit 1
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Resolved build: #${BUILD_NUMBER}"
echo -e "\e[1;33m[rhino-installer]\e[0m Downloading Velocity JAR -> ${SERVER_JARFILE}..."
if ! curl -fsSL -H "User-Agent: ${RHINO_UA}" -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Download failed (HTTP error)."
    exit 1
fi
JAR_SIZE=$(stat -c%s "${SERVER_JARFILE}" 2>/dev/null || stat -f%z "${SERVER_JARFILE}")
if [ "${JAR_SIZE:-0}" -lt 102400 ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Downloaded file too small (${JAR_SIZE} bytes)."
    rm -f "${SERVER_JARFILE}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Baseline velocity.toml
# ---------------------------------------------------------------------------
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
    echo -e "\e[1;32m[rhino-installer]\e[0m Generated baseline velocity.toml configured for port ${PROXY_PORT}."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Velocity proxy installation completed successfully."
