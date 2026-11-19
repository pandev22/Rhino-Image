#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - ARK: Survival Evolved Dedicated Server
# Downloads/updates ARK server files via Valve SteamCMD (App ID 376030)
#
# Security / reliability rules:
# - Uses the real SteamCMD wrapper path, POSIX `set -eu`.
# - SteamCMD success is verified before the install is reported as complete.
# - The server executable is verified, so a failed download cannot be hidden.
# - No default admin/RCON password is written; RCON is disabled until configured.
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="376030"
STEAM_USER="${STEAM_USER:-anonymous}"
STEAM_PASS="${STEAM_PASS:-}"
VALIDATE="${VALIDATE:-1}"

info() { printf '\033[1;33m[rhino-installer]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[rhino-installer]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[rhino-installer]\033[0m %s\n' "$*" >&2; exit 1; }

info "Setting up ARK: Survival Evolved in ${TARGET_DIR}..."

STEAMCMD_BIN=""
for candidate in /usr/local/steamcmd/steamcmd.sh /usr/local/bin/steamcmd /usr/games/steamcmd /steamcmd/steamcmd.sh; do
    if [ -x "${candidate}" ]; then
        STEAMCMD_BIN="${candidate}"
        break
    fi
done
[ -n "${STEAMCMD_BIN}" ] || fail "SteamCMD not found (expected /usr/local/steamcmd/steamcmd.sh)"
info "Using SteamCMD: ${STEAMCMD_BIN}"

LOG="/tmp/rhino-steamcmd-$$.log"
trap 'rm -f "${LOG}"' EXIT

set -- +force_install_dir "${TARGET_DIR}"
if [ -n "${STEAM_PASS}" ]; then
    set -- "$@" +login "${STEAM_USER}" "${STEAM_PASS}"
else
    set -- "$@" +login anonymous
fi
set -- "$@" +app_update "${APP_ID}"
if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    set -- "$@" validate
fi
set -- "$@" +quit

info "Running SteamCMD for ARK (App ID ${APP_ID})..."
if ! "${STEAMCMD_BIN}" "$@" >"${LOG}" 2>&1; then
    cat "${LOG}"
    fail "SteamCMD failed for ARK (App ID ${APP_ID})"
fi
cat "${LOG}"
grep -Eq "Success! App '${APP_ID}' (fully installed|already up to date)" "${LOG}" \
    || fail "SteamCMD did not report a successful installation for App ID ${APP_ID}"

EXECUTABLE="ShooterGame/Binaries/Linux/ShooterGameServer"
[ -f "${EXECUTABLE}" ] || fail "${EXECUTABLE} is missing after the ARK installation"
chmod +x "${EXECUTABLE}"
ok "ARK server files installed and ${EXECUTABLE} verified."

mkdir -p ShooterGame/Saved/Config/LinuxServer ShooterGame/Saved/SavedArks
INI_FILE="ShooterGame/Saved/Config/LinuxServer/GameUserSettings.ini"
if [ ! -f "${INI_FILE}" ]; then
    cat <<EOF > "${INI_FILE}"
[ServerSettings]
ServerPassword=
ServerAdminPassword=
RCONEnabled=False
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
    ok "Created baseline GameUserSettings.ini (RCON disabled, no default password)."
fi

ok "ARK: Survival Evolved server installation completed successfully."
