#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Fabric Minecraft Server
# Downloads Fabric server launcher from official Fabric Meta API
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

MINECRAFT_VERSION="${MINECRAFT_VERSION:-latest}"
LOADER_VERSION="${LOADER_VERSION:-latest}"
INSTALLER_VERSION="${INSTALLER_VERSION:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-server.jar}"
AUTO_EULA="${AUTO_EULA:-true}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Fabric Server in ${TARGET_DIR}..."

# Query Fabric Meta API for Game Versions
if [ "${MINECRAFT_VERSION}" = "latest" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Resolving latest stable Minecraft version for Fabric..."
    GAME_VERSIONS=$(curl -sSL "https://meta.fabricmc.net/v2/versions/game")
    MINECRAFT_VERSION=$(echo "${GAME_VERSIONS}" | jq -r '[.[] | select(.stable == true)][0].version')
    echo -e "\e[1;32m[rhino-installer]\e[0m Target Minecraft version: ${MINECRAFT_VERSION}"
fi

# Query Loader Version
if [ "${LOADER_VERSION}" = "latest" ]; then
    LOADER_VERSIONS=$(curl -sSL "https://meta.fabricmc.net/v2/versions/loader")
    LOADER_VERSION=$(echo "${LOADER_VERSIONS}" | jq -r '[.[] | select(.stable == true)][0].version // .[0].version')
    echo -e "\e[1;32m[rhino-installer]\e[0m Resolved Fabric loader: ${LOADER_VERSION}"
fi

# Query Installer Version
if [ "${INSTALLER_VERSION}" = "latest" ]; then
    INSTALLER_VERSIONS=$(curl -sSL "https://meta.fabricmc.net/v2/versions/installer")
    INSTALLER_VERSION=$(echo "${INSTALLER_VERSIONS}" | jq -r '[.[] | select(.stable == true)][0].version // .[0].version')
    echo -e "\e[1;32m[rhino-installer]\e[0m Resolved Fabric installer: ${INSTALLER_VERSION}"
fi

LAUNCHER_URL="https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${LOADER_VERSION}/${INSTALLER_VERSION}/server/jar"
echo -e "\e[1;33m[rhino-installer]\e[0m Downloading Fabric launcher JAR -> ${SERVER_JARFILE}..."
if ! curl -fsSL -o "${SERVER_JARFILE}" "${LAUNCHER_URL}"; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Download failed (HTTP error). Check the Fabric Meta API versions."
    exit 1
fi
JAR_SIZE=$(stat -c%s "${SERVER_JARFILE}" 2>/dev/null || stat -f%z "${SERVER_JARFILE}")
if [ "${JAR_SIZE:-0}" -lt 102400 ]; then
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
motd=A Rhino Fabric Server
max-players=20
online-mode=true
enable-rcon=false
view-distance=10
gamemode=survival
difficulty=easy
EOF
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Fabric server installation completed successfully."
