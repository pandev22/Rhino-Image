#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Minecraft Forge Server
# Downloads Forge installer, installs server files, and prepares runtime
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

MC_VERSION="${MC_VERSION:-1.20.4}"
FORGE_VERSION="${FORGE_VERSION:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-server.jar}"
AUTO_EULA="${AUTO_EULA:-true}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Minecraft Forge (${MC_VERSION}) in ${TARGET_DIR}..."

# Resolve Forge Version if 'latest' or 'recommended'
if [ "${FORGE_VERSION}" = "latest" ] || [ "${FORGE_VERSION}" = "recommended" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Querying Forge promotions for MC ${MC_VERSION}..."
    PROMOTIONS=$(curl -sSL "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json")
    PROMO_KEY="${MC_VERSION}-recommended"
    RESOLVED_FORGE=$(echo "${PROMOTIONS}" | jq -r ".promos[\"${PROMO_KEY}\"] // empty")
    if [ -z "${RESOLVED_FORGE}" ]; then
        PROMO_KEY="${MC_VERSION}-latest"
        RESOLVED_FORGE=$(echo "${PROMOTIONS}" | jq -r ".promos[\"${PROMO_KEY}\"] // empty")
    fi
    if [ -n "${RESOLVED_FORGE}" ]; then
        FORGE_VERSION="${RESOLVED_FORGE}"
        echo -e "\e[1;32m[rhino-installer]\e[0m Resolved Forge version: ${FORGE_VERSION}"
    else
        echo -e "\e[1;33m[rhino-installer]\e[0m Falling back to default Forge release for ${MC_VERSION}."
        FORGE_VERSION="49.0.38"
    fi
fi

FULL_VERSION="${MC_VERSION}-${FORGE_VERSION}"
INSTALLER_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${FULL_VERSION}/forge-${FULL_VERSION}-installer.jar"
INSTALLER_FILE="/tmp/forge-${FULL_VERSION}-installer.jar"

echo -e "\e[1;33m[rhino-installer]\e[0m Downloading Forge installer: ${INSTALLER_URL}..."
if ! curl -fsSL -o "${INSTALLER_FILE}" "${INSTALLER_URL}"; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Download failed (HTTP error). Check the Forge version (${FULL_VERSION}) on https://files.minecraftforge.net."
    exit 1
fi
INSTALLER_SIZE=$(stat -c%s "${INSTALLER_FILE}" 2>/dev/null || stat -f%z "${INSTALLER_FILE}")
if [ "${INSTALLER_SIZE:-0}" -lt 102400 ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Downloaded file is too small (${INSTALLER_SIZE} bytes) — likely an error response, not a valid installer."
    rm -f "${INSTALLER_FILE}"
    exit 1
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Running Forge headless server installation..."
java -jar "${INSTALLER_FILE}" --installServer "${TARGET_DIR}"
rm -f "${INSTALLER_FILE}" "${INSTALLER_FILE}.log"

# Forge modern generates run.sh / user_jvm_args.txt
if [ -f "run.sh" ]; then
    chmod +x run.sh
fi

# Link or prepare entry JAR if legacy
if [ -f "forge-${FULL_VERSION}.jar" ]; then
    ln -sf "forge-${FULL_VERSION}.jar" "${SERVER_JARFILE}"
elif [ -f "libraries/net/minecraftforge/forge/${FULL_VERSION}/unix_args.txt" ]; then
    echo -e "\e[1;32m[rhino-installer]\e[0m Modern Forge installed with args in libraries/."
fi

# Auto EULA
if [ "${AUTO_EULA}" = "true" ] || [ "${AUTO_EULA}" = "1" ]; then
    echo "eula=true" > eula.txt
    echo -e "\e[1;32m[rhino-installer]\e[0m EULA accepted (eula.txt created)."
fi

# Default server.properties
if [ ! -f "server.properties" ]; then
    cat <<EOF > server.properties
server-port=${SERVER_PORT:-25565}
motd=A Rhino Forge Server
max-players=${MAX_PLAYERS:-20}
online-mode=true
enable-rcon=false
EOF
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Forge server installation completed successfully."
