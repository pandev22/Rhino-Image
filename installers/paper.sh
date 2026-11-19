#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - PaperMC (Minecraft High-Performance Server)
# Uses PaperMC Fill v3 API (fill.papermc.io)
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

MINECRAFT_VERSION="${MINECRAFT_VERSION:-latest}"
BUILD_NUMBER="${BUILD_NUMBER:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-server.jar}"
AUTO_EULA="${AUTO_EULA:-true}"

RHINO_UA="RhinoPanel/1.0 (https://rhino.overnode.fr)"
API_BASE="https://fill.papermc.io/v3/projects/paper"

echo -e "\e[1;33m[rhino-installer]\e[0m Starting PaperMC setup in ${TARGET_DIR}..."

# ---------------------------------------------------------------------------
# Resolve Minecraft version
# ---------------------------------------------------------------------------
if [ "${MINECRAFT_VERSION}" = "latest" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Resolving latest stable Minecraft version from Fill API..."
    PROJECT_DATA=$(curl -fsSL -H "User-Agent: ${RHINO_UA}" "${API_BASE}")
    # versions is an object: {"26.3": [...], "1.21": [...]}
    # Keys are sorted by the API in descending order; first key = latest group.
    # We pick the first STABLE-like version (non-rc, non-pre) in the latest group.
    MINECRAFT_VERSION=$(echo "${PROJECT_DATA}" | jq -r '
        .versions
        | keys_unsorted[0] as $group
        | .[$group]
        | map(select(test("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$")))
        | if length > 0 then .[0] else error("no stable version") end
    ' 2>/dev/null || echo "${PROJECT_DATA}" | jq -r '.versions | keys_unsorted[0] as $group | .[$group][0]')
    if [ -z "${MINECRAFT_VERSION}" ] || [ "${MINECRAFT_VERSION}" = "null" ]; then
        echo -e "\e[1;31m[rhino-installer]\e[0m Failed to resolve latest Minecraft version."
        exit 1
    fi
    echo -e "\e[1;32m[rhino-installer]\e[0m Detected latest Minecraft version: ${MINECRAFT_VERSION}"
fi

# ---------------------------------------------------------------------------
# Resolve build and get download URL directly from API response
# ---------------------------------------------------------------------------
echo -e "\e[1;33m[rhino-installer]\e[0m Fetching builds for Paper ${MINECRAFT_VERSION}..."
BUILDS_DATA=$(curl -fsSL -H "User-Agent: ${RHINO_UA}" "${API_BASE}/versions/${MINECRAFT_VERSION}/builds")

if [ "${BUILD_NUMBER}" = "latest" ]; then
    # Pick latest STABLE build; fall back to any build if none is STABLE.
    DOWNLOAD_URL=$(echo "${BUILDS_DATA}" | jq -r '
        (map(select(.channel == "STABLE")) | last // last)
        | .downloads["server:default"].url
    ')
    BUILD_NUMBER=$(echo "${BUILDS_DATA}" | jq -r '
        (map(select(.channel == "STABLE")) | last // last) | .id
    ')
else
    DOWNLOAD_URL=$(echo "${BUILDS_DATA}" | jq -r --argjson id "${BUILD_NUMBER}" '
        map(select(.id == $id)) | .[0] | .downloads["server:default"].url
    ')
fi

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Failed to find download URL for Paper ${MINECRAFT_VERSION} build ${BUILD_NUMBER}."
    exit 1
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Resolved build: #${BUILD_NUMBER}"
echo -e "\e[1;33m[rhino-installer]\e[0m Downloading Paper from ${DOWNLOAD_URL} -> ${SERVER_JARFILE}..."
if ! curl -fsSL -H "User-Agent: ${RHINO_UA}" -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Download failed (HTTP error)."
    exit 1
fi
JAR_SIZE=$(stat -c%s "${SERVER_JARFILE}" 2>/dev/null || stat -f%z "${SERVER_JARFILE}")
if [ "${JAR_SIZE:-0}" -lt 1048576 ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Downloaded file is too small (${JAR_SIZE} bytes) — not a valid JAR."
    rm -f "${SERVER_JARFILE}"
    exit 1
fi

# ---------------------------------------------------------------------------
# EULA + server.properties
# ---------------------------------------------------------------------------
if [ "${AUTO_EULA}" = "true" ] || [ "${AUTO_EULA}" = "1" ]; then
    echo "eula=true" > eula.txt
    echo -e "\e[1;32m[rhino-installer]\e[0m EULA accepted (eula.txt created)."
fi

if [ ! -f "server.properties" ]; then
    cat <<EOF > server.properties
server-port=${SERVER_PORT:-25565}
motd=A Rhino Paper Server
max-players=${MAX_PLAYERS:-20}
online-mode=true
enable-rcon=false
white-list=false
view-distance=10
difficulty=easy
gamemode=survival
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Created baseline server.properties on port ${SERVER_PORT:-25565}."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Paper server installation completed successfully (100% ready)."
