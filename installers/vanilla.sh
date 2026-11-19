#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Minecraft Vanilla (Official Mojang Server)
# Queries Mojang official version manifest and downloads the vanilla server JAR
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

VANILLA_VERSION="${VANILLA_VERSION:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-server.jar}"
AUTO_EULA="${AUTO_EULA:-true}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Minecraft Vanilla in ${TARGET_DIR}..."

MANIFEST_URL="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
echo -e "\e[1;33m[rhino-installer]\e[0m Fetching Mojang version manifest..."
MANIFEST=$(curl -sSL "${MANIFEST_URL}")

if [ "${VANILLA_VERSION}" = "latest" ]; then
    VANILLA_VERSION=$(echo "${MANIFEST}" | jq -r '.latest.release')
    echo -e "\e[1;32m[rhino-installer]\e[0m Latest vanilla release: ${VANILLA_VERSION}"
fi

VERSION_URL=$(echo "${MANIFEST}" | jq -r ".versions[] | select(.id == \"${VANILLA_VERSION}\") | .url")
if [ -z "${VERSION_URL}" ] || [ "${VERSION_URL}" = "null" ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Error: Minecraft version ${VANILLA_VERSION} not found in Mojang manifest."
    exit 1
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Fetching version package for ${VANILLA_VERSION}..."
VERSION_DATA=$(curl -sSL "${VERSION_URL}")
DOWNLOAD_URL=$(echo "${VERSION_DATA}" | jq -r '.downloads.server.url')

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Error: No official server download URL available for ${VANILLA_VERSION}."
    exit 1
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Downloading Vanilla server JAR -> ${SERVER_JARFILE}..."
if ! curl -fsSL -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Download failed (HTTP error). Check the Mojang URL."
    exit 1
fi
JAR_SIZE=$(stat -c%s "${SERVER_JARFILE}" 2>/dev/null || stat -f%z "${SERVER_JARFILE}")
if [ "${JAR_SIZE:-0}" -lt 1048576 ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Downloaded file is too small (${JAR_SIZE} bytes) — likely an error response, not a valid JAR."
    rm -f "${SERVER_JARFILE}"
    exit 1
fi

# Auto EULA
if [ "${AUTO_EULA}" = "true" ] || [ "${AUTO_EULA}" = "1" ]; then
    echo "eula=true" > eula.txt
    echo -e "\e[1;32m[rhino-installer]\e[0m EULA accepted (eula.txt created)."
fi

# Baseline server.properties
if [ ! -f "server.properties" ]; then
    cat <<EOF > server.properties
server-port=${SERVER_PORT:-25565}
motd=A Rhino Vanilla Server
max-players=${MAX_PLAYERS:-20}
online-mode=true
enable-rcon=false
view-distance=10
gamemode=survival
difficulty=easy
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Created baseline server.properties on port ${SERVER_PORT:-25565}."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Vanilla server installation completed successfully."
