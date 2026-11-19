#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - PaperMC (Minecraft High-Performance Server)
# Automatically downloads latest or specified Paper build from official PaperMC API
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

MINECRAFT_VERSION="${MINECRAFT_VERSION:-latest}"
BUILD_NUMBER="${BUILD_NUMBER:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-server.jar}"
AUTO_EULA="${AUTO_EULA:-true}"

echo -e "\e[1;33m[rhino-installer]\e[0m Starting PaperMC setup in ${TARGET_DIR}..."

# Resolve Minecraft version if 'latest'
if [ "${MINECRAFT_VERSION}" = "latest" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Resolving latest Minecraft version from PaperMC API..."
    PROJECT_DATA=$(curl -sSL -H "Accept: application/json" https://api.papermc.io/v2/projects/paper)
    MINECRAFT_VERSION=$(echo "${PROJECT_DATA}" | jq -r '.versions[-1]')
    echo -e "\e[1;32m[rhino-installer]\e[0m Detected latest Minecraft version: ${MINECRAFT_VERSION}"
fi

# Resolve Build Number if 'latest'
if [ "${BUILD_NUMBER}" = "latest" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Fetching latest build for Paper ${MINECRAFT_VERSION}..."
    VERSION_DATA=$(curl -sSL -H "Accept: application/json" "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}")
    BUILD_NUMBER=$(echo "${VERSION_DATA}" | jq -r '.builds[-1]')
    if [ "${BUILD_NUMBER}" = "null" ] || [ -z "${BUILD_NUMBER}" ]; then
        echo -e "\e[1;31m[rhino-installer]\e[0m Failed to find valid builds for Minecraft ${MINECRAFT_VERSION}."
        exit 1
    fi
    echo -e "\e[1;32m[rhino-installer]\e[0m Latest build resolved: #${BUILD_NUMBER}"
fi

DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${BUILD_NUMBER}/downloads/paper-${MINECRAFT_VERSION}-${BUILD_NUMBER}.jar"
echo -e "\e[1;33m[rhino-installer]\e[0m Downloading Paper jar from ${DOWNLOAD_URL} -> ${SERVER_JARFILE}..."
curl -sSL -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"

# Automatically accept Mojang EULA if requested
if [ "${AUTO_EULA}" = "true" ] || [ "${AUTO_EULA}" = "1" ]; then
    echo "eula=true" > eula.txt
    echo -e "\e[1;32m[rhino-installer]\e[0m EULA accepted (eula.txt created)."
fi

# Baseline server.properties if not present
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
