#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Garry's Mod Dedicated Server (SRCDS)
# Downloads/updates Garry's Mod server files via Valve SteamCMD (App ID 4020)
#
# Security / reliability rules:
# - Uses the real SteamCMD wrapper path (never a symlink whose directory changes
#   the location of the linux32 binary).
# - POSIX `set -eu` (works even when the install entrypoint runs the script with sh).
# - SteamCMD is only considered successful when it reports a successful app update.
# - The expected server binary is verified, so a failed install cannot be marked OK.
# - No default RCON password is written: RCON is disabled until the owner sets one.
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="4020"
VALIDATE="${VALIDATE:-1}"

info() { printf '\033[1;33m[rhino-installer]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[rhino-installer]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[rhino-installer]\033[0m %s\n' "$*" >&2; exit 1; }

info "Setting up Garry's Mod in ${TARGET_DIR}..."

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

set -- +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}"
if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    set -- "$@" validate
fi
set -- "$@" +quit

info "Running SteamCMD for Garry's Mod (App ID ${APP_ID})..."
if ! "${STEAMCMD_BIN}" "$@" >"${LOG}" 2>&1; then
    cat "${LOG}"
    fail "SteamCMD failed for Garry's Mod (App ID ${APP_ID})"
fi
cat "${LOG}"
grep -Eq "Success! App '${APP_ID}' (fully installed|already up to date)" "${LOG}" \
    || fail "SteamCMD did not report a successful installation for App ID ${APP_ID}"

[ -f "srcds_run" ] || fail "srcds_run is missing after the Garry's Mod installation"
chmod +x srcds_run
[ -f "srcds_linux" ] && chmod +x srcds_linux || true
ok "Garry's Mod server files installed and srcds_run verified."

mkdir -p garrysmod/cfg
CFG_FILE="garrysmod/cfg/server.cfg"
if [ ! -f "${CFG_FILE}" ]; then
    cat <<EOF > "${CFG_FILE}"
hostname "A Rhino Garry's Mod Server"
rcon_password ""
sv_password ""
sv_lan 0
sv_region 255
sbox_maxprops 150
sbox_maxragdolls 10
sbox_maxvehicles 6
sbox_maxballoons 10
sbox_maxeffects 50
sbox_maxdynamite 10
sbox_maxlamps 10
sbox_maxthrusters 30
sbox_maxwheels 20
sbox_maxhoverballs 20
sbox_maxbuttons 20
sbox_maxemitters 20
sbox_godmode 0
sbox_noclip 1
EOF
    ok "Generated baseline garrysmod/cfg/server.cfg (RCON disabled)."
fi

ok "Garry's Mod server installation completed successfully."
