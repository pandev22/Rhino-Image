#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - SpongeVanilla Server
# Downloads SpongeVanilla from official SpongePowered API
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

SPONGE_VERSION="${SPONGE_VERSION:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-server.jar}"
AUTO_EULA="${AUTO_EULA:-true}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up SpongeVanilla in ${TARGET_DIR}..."

API_URL="https://dl-api.spongepowered.org/v2/groups/org.spongepowered/artifacts/spongevanilla"
echo -e "\e[1;33m[rhino-installer]\e[0m Querying SpongePowered download API..."
ARTIFACTS_JSON=$(curl -sSL -H "Accept: application/json" "${API_URL}")

if [ "${SPONGE_VERSION}" = "latest" ]; then
    VERSION_TAG=$(echo "${ARTIFACTS_JSON}" | jq -r '.assets[-1].version // empty')
    if [ -z "${VERSION_TAG}" ]; then
        VERSION_TAG="1.20.2-11.0.0-RC1377"
    fi
    echo -e "\e[1;32m[rhino-installer]\e[0m Target Sponge release: ${VERSION_TAG}"
else
    VERSION_TAG="${SPONGE_VERSION}"
fi

DOWNLOAD_URL="https://repo.spongepowered.org/repository/maven-releases/org/spongepowered/spongevanilla/${VERSION_TAG}/spongevanilla-${VERSION_TAG}-universal.jar"
echo -e "\e[1;33m[rhino-installer]\e[0m Downloading SpongeVanilla universal JAR -> ${SERVER_JARFILE}..."
if ! curl -fsSL -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"; then
    FALLBACK_URL="https://repo.spongepowered.org/repository/maven-releases/org/spongepowered/spongevanilla/${VERSION_TAG}/spongevanilla-${VERSION_TAG}.jar"
    curl -sSL -o "${SERVER_JARFILE}" "${FALLBACK_URL}"
fi

# Auto EULA
if [ "${AUTO_EULA}" = "true" ] || [ "${AUTO_EULA}" = "1" ]; then
    echo "eula=true" > eula.txt
    echo -e "\e[1;32m[rhino-installer]\e[0m EULA accepted (eula.txt created)."
fi

# server.properties baseline
if [ ! -f "server.properties" ]; then
    cat <<EOF > server.properties
server-port=${SERVER_PORT:-25565}
motd=A Rhino SpongeVanilla Server
max-players=20
online-mode=true
enable-rcon=false
EOF
fi

echo -e "\e[1;32m[rhino-installer]\e[0m SpongeVanilla server installation completed successfully."
