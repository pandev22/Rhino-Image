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

API_BASE="https://dl-api.spongepowered.org/v2/groups/org.spongepowered/artifacts/spongevanilla"

if [ "${SPONGE_VERSION}" = "latest" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Resolving latest stable SpongeVanilla release..."
    VERSION_TAG=$(curl -fsSL -H "Accept: application/json" "${API_BASE}/versions?limit=30" | jq -r '
        .artifacts | keys[] | select(test("snapshot") | not)
    ' | head -n 1 || true)

    if [ -z "${VERSION_TAG}" ] || [ "${VERSION_TAG}" = "null" ]; then
        VERSION_TAG="26.3-21.0.0-RC2721"
    fi
    echo -e "\e[1;32m[rhino-installer]\e[0m Target Sponge release: ${VERSION_TAG}"
else
    VERSION_TAG="${SPONGE_VERSION}"
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Fetching artifact details for ${VERSION_TAG}..."
ARTIFACT_DETAILS=$(curl -fsSL -H "Accept: application/json" "${API_BASE}/versions/${VERSION_TAG}")
DOWNLOAD_URL=$(echo "${ARTIFACT_DETAILS}" | jq -r '
    (.assets[] | select(.classifier == "universal") | .downloadUrl) //
    (.assets[] | select(.classifier == "" and .extension == "jar") | .downloadUrl) //
    empty
' | head -n 1)

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
    # Fallback to direct maven repo URL
    DOWNLOAD_URL="https://repo.spongepowered.org/repository/maven-releases/org/spongepowered/spongevanilla/${VERSION_TAG}/spongevanilla-${VERSION_TAG}-universal.jar"
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Downloading SpongeVanilla JAR -> ${SERVER_JARFILE}..."
if ! curl -fsSL -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"; then
    FALLBACK_URL="https://repo.spongepowered.org/repository/maven-releases/org/spongepowered/spongevanilla/${VERSION_TAG}/spongevanilla-${VERSION_TAG}.jar"
    if ! curl -fsSL -o "${SERVER_JARFILE}" "${FALLBACK_URL}"; then
        echo -e "\e[1;31m[rhino-installer]\e[0m Download failed. Check Sponge version tag (${VERSION_TAG})."
        exit 1
    fi
fi

JAR_SIZE=$(stat -c%s "${SERVER_JARFILE}" 2>/dev/null || stat -f%z "${SERVER_JARFILE}")
if [ "${JAR_SIZE:-0}" -lt 1048576 ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Downloaded file is too small (${JAR_SIZE} bytes) — not a valid JAR."
    rm -f "${SERVER_JARFILE}"
    exit 1
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
