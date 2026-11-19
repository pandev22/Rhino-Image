#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Counter-Strike 2 Dedicated Server
# Downloads/updates CS2 server files via Valve SteamCMD (App ID 730)
#
# Security / reliability rules:
# - Uses the real SteamCMD wrapper path, POSIX `set -eu`.
# - SteamCMD success and the CS2 launcher are verified before reporting success.
# - No default RCON password is written: RCON is disabled until the owner sets one.
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="730"
VALIDATE="${VALIDATE:-1}"

info() { printf '\033[1;33m[rhino-installer]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[rhino-installer]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[rhino-installer]\033[0m %s\n' "$*" >&2; exit 1; }

info "Setting up Counter-Strike 2 in ${TARGET_DIR}..."

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

info "Running SteamCMD for Counter-Strike 2 (App ID ${APP_ID})..."
if ! "${STEAMCMD_BIN}" "$@" >"${LOG}" 2>&1; then
    cat "${LOG}"
    fail "SteamCMD failed for Counter-Strike 2 (App ID ${APP_ID})"
fi
cat "${LOG}"
grep -Eq "Success! App '${APP_ID}' (fully installed|already up to date)" "${LOG}" \
    || fail "SteamCMD did not report a successful installation for App ID ${APP_ID}"

if [ -f "game/cs2.sh" ]; then
    chmod +x game/cs2.sh
fi
if [ -f "game/bin/linuxsteamrt64/cs2" ]; then
    chmod +x game/bin/linuxsteamrt64/cs2
fi
if [ ! -f "game/cs2.sh" ] && [ ! -f "game/bin/linuxsteamrt64/cs2" ]; then
    fail "CS2 launcher is missing after the installation"
fi
ok "CS2 server files installed and launcher verified."

mkdir -p game/csgo/cfg
CFG_FILE="game/csgo/cfg/server.cfg"
if [ ! -f "${CFG_FILE}" ]; then
    cat <<EOF > "${CFG_FILE}"
hostname "A Rhino Counter-Strike 2 Server"
rcon_password ""
sv_cheats 0
sv_lan 0
mp_roundtime 2
mp_maxrounds 24
mp_autoteambalance 1
mp_limitteams 1
bot_quota 0
EOF
    ok "Generated baseline game/csgo/cfg/server.cfg (RCON disabled)."
fi

ok "Counter-Strike 2 server installation completed successfully."
