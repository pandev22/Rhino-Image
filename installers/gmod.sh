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
# - Transient SteamCMD "Missing configuration" errors are retried after clearing
#   the app-info cache (known SteamCMD behaviour, especially with + commands).
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"
export HOME="${TARGET_DIR}"

APP_ID="4020"
VALIDATE="${VALIDATE:-1}"
ATTEMPTS="${STEAMCMD_ATTEMPTS:-3}"
case "${ATTEMPTS}" in
    ""|*[!0-9]*) ATTEMPTS=3 ;;
esac
[ "${ATTEMPTS}" -ge 1 ] || ATTEMPTS=1

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

# The server volume hides the .steam symlinks baked into the image. Recreate them in the
# volume: some SteamCMD operations look for the 32/64-bit client libraries there.
mkdir -p "${HOME}/.steam/sdk32" "${HOME}/.steam/sdk64" "${HOME}/Steam"
ln -sf /usr/local/steamcmd/linux32/steamclient.so "${HOME}/.steam/sdk32/steamclient.so" 2>/dev/null || true
ln -sf /usr/local/steamcmd/linux64/steamclient.so "${HOME}/.steam/sdk64/steamclient.so" 2>/dev/null || true

clear_steam_cache() {
    rm -rf \
        /usr/local/steamcmd/appcache \
        "${HOME}/Steam/appcache" \
        "${HOME}/.steam/steam/appcache" \
        2>/dev/null || true
}

WARM_LOG="/tmp/rhino-steamcmd-warm-$$.log"
LOG="/tmp/rhino-steamcmd-$$.log"
trap 'rm -f "${LOG}" "${WARM_LOG}"' EXIT

# SteamCMD's app-info cache is sometimes empty/stale on a fresh automated run. Warm it up
# first; a failure here is harmless and the install below still tries.
info "Refreshing SteamCMD app information..."
if ! "${STEAMCMD_BIN}" +login anonymous +app_info_update 1 +app_info_print "${APP_ID}" +quit >"${WARM_LOG}" 2>&1; then
    info "SteamCMD app-info refresh did not complete; continuing with the installer."
fi

set -- +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}"
if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    set -- "$@" validate
fi
set -- "$@" +quit

attempt=1
installed=0
while [ "${attempt}" -le "${ATTEMPTS}" ]; do
    info "Running SteamCMD for Garry's Mod (App ID ${APP_ID}), attempt ${attempt}/${ATTEMPTS}..."
    if "${STEAMCMD_BIN}" "$@" >"${LOG}" 2>&1; then
        if grep -Eq "Success! App '${APP_ID}' (fully installed|already up to date)" "${LOG}"; then
            installed=1
            break
        fi
    fi

    if grep -q "Missing configuration" "${LOG}" && [ "${attempt}" -lt "${ATTEMPTS}" ]; then
        info "SteamCMD could not load the app ${APP_ID} configuration; refreshing its cache and retrying..."
        tail -n 15 "${LOG}" || true
        clear_steam_cache
        sleep 3
        attempt=$((attempt + 1))
        continue
    fi

    cat "${LOG}"
    fail "SteamCMD failed for Garry's Mod (App ID ${APP_ID}) on attempt ${attempt}/${ATTEMPTS}"
done

[ "${installed}" -eq 1 ] || fail "SteamCMD did not report a successful installation for App ID ${APP_ID}"
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
