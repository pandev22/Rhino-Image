#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - ARK: Survival Evolved Dedicated Server
# Downloads/updates ARK server files via Valve SteamCMD (App ID 376030)
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="376030"
STEAM_USER="${STEAM_USER:-anonymous}"
STEAM_PASS="${STEAM_PASS:-}"
VALIDATE="${VALIDATE:-1}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up ARK: Survival Evolved in ${TARGET_DIR}..."

STEAMCMD_BIN=$(command -v steamcmd || echo "/usr/games/steamcmd" || echo "/steamcmd/steamcmd.sh")
if [ ! -x "${STEAMCMD_BIN}" ] && [ -f "/steamcmd/steamcmd.sh" ]; then
    STEAMCMD_BIN="/steamcmd/steamcmd.sh"
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Running SteamCMD for App ID ${APP_ID}..."
STEAM_ARGS=(+force_install_dir "${TARGET_DIR}")

if [ -n "${STEAM_PASS}" ]; then
    STEAM_ARGS+=(+login "${STEAM_USER}" "${STEAM_PASS}")
else
    STEAM_ARGS+=(+login anonymous)
fi

if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    STEAM_ARGS+=(+app_update "${APP_ID}" validate)
else
    STEAM_ARGS+=(+app_update "${APP_ID}")
fi

STEAM_ARGS+=(+quit)

"${STEAMCMD_BIN}" "${STEAM_ARGS[@]}"

# Fix binary permissions
EXECUTABLE="ShooterGame/Binaries/Linux/ShooterGameServer"
if [ -f "${EXECUTABLE}" ]; then
    chmod +x "${EXECUTABLE}"
    echo -e "\e[1;32m[rhino-installer]\e[0m Verified executable permissions on ${EXECUTABLE}."
fi

# Create default directories if missing
mkdir -p ShooterGame/Saved/Config/LinuxServer ShooterGame/Saved/SavedArks

# Baseline GameUserSettings.ini if missing
INI_FILE="ShooterGame/Saved/Config/LinuxServer/GameUserSettings.ini"
if [ ! -f "${INI_FILE}" ]; then
    cat <<EOF > "${INI_FILE}"
[ServerSettings]
ServerPassword=
ServerAdminPassword=RhinoAdminPassword123!
RCONEnabled=True
RCONPort=${RCON_PORT:-27020}
TheMaxStructuresInRange=10500
OxygenSwimSpeedStatMultiplier=1.000000
StructurePreventResourceRadiusMultiplier=1.000000
TribeNameChangeCooldown=15.000000
ServerCrosshair=True
ShowMapPlayerLocation=True
AllowThirdPersonPlayer=True
ServerHardcore=False
GlobalVoiceChat=False
ProximityChat=False
NoTributeDownloads=False
AllowCaveBuildingPvE=False
AlwaysNotifyPlayerLeft=False
DontAlwaysNotifyPlayerJoined=False
ServerPVE=False
ServerNetClamp=0
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Created baseline GameUserSettings.ini."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m ARK: Survival Evolved server installation completed successfully."
