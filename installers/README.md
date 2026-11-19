# 🦏 Rhino Panel - Server Installation & Preparation Scripts (`installers/`)

This directory houses the official installation and preparation scripts (`.sh`) for game servers, voice servers, proxies, and application runtimes managed by **Rhino Panel** and **Rhino Action**.

All scripts are idempotent, secure (`set -euo pipefail`), respect least-privilege standards, and download the exact binaries, libraries, and configurations required to make each server **100% ready to run**.

---

## 📑 Included Installer Scripts

### 🎮 Minecraft & Java Ecosystem

| Script | Server Type | Default Image | Key Features |
|---|---|---|---|
| [`paper.sh`](paper.sh) | **PaperMC** | `ghcr.io/pandev22/rhino-java:21` | Official PaperMC v2 API, auto-build resolution, EULA auto-acceptance, baseline `server.properties`. |
| [`forge.sh`](forge.sh) | **Minecraft Forge** | `ghcr.io/pandev22/rhino-java:21` | Maven installer download, headless `--installServer`, `run.sh` / JVM args preparation, EULA. |
| [`vanilla.sh`](vanilla.sh) | **Minecraft Vanilla** | `ghcr.io/pandev22/rhino-java:21` | Mojang version manifest v2 query, official server JAR download, EULA auto-acceptance. |
| [`bungeecord.sh`](bungeecord.sh) | **BungeeCord Proxy** | `ghcr.io/pandev22/rhino-java:21` | SpigotMC CI build artifact, baseline `config.yml` with port binding. |
| [`pocketminemp.sh`](pocketminemp.sh) | **PocketMine-MP** | `ghcr.io/pandev22/rhino-generic:latest` | Bedrock server `PocketMine-MP.phar`, precompiled Linux PHP 8.2+ binaries. |
| [`velocity.sh`](velocity.sh) | **Velocity Proxy** | `ghcr.io/pandev22/rhino-java:21` | Next-gen PaperMC proxy, `velocity.toml` configuration with forwarding secrets. |
| [`sponge.sh`](sponge.sh) | **SpongeVanilla** | `ghcr.io/pandev22/rhino-java:21` | SpongePowered API download, universal JAR preparation, EULA. |
| [`fabric.sh`](fabric.sh) | **Fabric Server** | `ghcr.io/pandev22/rhino-java:21` | Fabric Meta API, game/loader/installer version auto-detection, server launcher. |

---

### 🕹️ Valve SteamCMD & Dedicated Games

| Script | Server / Game | Default Image | Steam App ID / Source | Key Setup |
|---|---|---|---|---|
| [`ark.sh`](ark.sh) | **ARK: Survival Evolved** | `ghcr.io/pandev22/rhino-steamcmd:latest` | `376030` | `ShooterGameServer` binary permissions, `GameUserSettings.ini` baseline. |
| [`tf2.sh`](tf2.sh) | **Team Fortress 2** | `ghcr.io/pandev22/rhino-steamcmd:latest` | `232250` | `srcds_run` setup, baseline `tf/cfg/server.cfg` with tickrate & rcon. |
| [`gmod.sh`](gmod.sh) | **Garry's Mod** | `ghcr.io/pandev22/rhino-steamcmd:latest` | `4020` | `srcds` setup, sandbox limits baseline in `garrysmod/cfg/server.cfg`. |
| [`cs2.sh`](cs2.sh) | **Counter-Strike 2** | `ghcr.io/pandev22/rhino-steamcmd:latest` | `730` | `game/cs2.sh` execution permissions, `game/csgo/cfg/server.cfg`. |
| [`unturned.sh`](unturned.sh) | **Unturned** | `ghcr.io/pandev22/rhino-steamcmd:latest` | `1110390` | `Unturned_Headless.x86_64` permissions, `Commands.dat` configuration. |
| [`fivem.sh`](fivem.sh) | **FiveM Server** | `ghcr.io/pandev22/rhino-generic:latest` | CitizenFX Artifacts | `fx.tar.xz` unpack, `cfx-server-data` default resources, baseline `server.cfg`. |

---

### ⚡ Application Runtimes & Bots

| Script | Runtime | Default Image | Key Setup |
|---|---|---|---|
| [`nodejs.sh`](nodejs.sh) | **Node.js LTS** | `ghcr.io/pandev22/rhino-generic:latest` | Baseline `package.json`, HTTP server starter `index.js`, `npm install --omit=dev`. |
| [`python.sh`](python.sh) | **Python 3.12+** | `ghcr.io/pandev22/rhino-generic:latest` | Isolated `.venv` virtualenv creation, starter `main.py`, `pip install -r requirements.txt`. |
| [`bun.sh`](bun.sh) | **Bun 1.2+** | `ghcr.io/pandev22/rhino-generic:latest` | High-performance `Bun.serve` in `index.ts`, `package.json`, `bun install`. |

---

## 🚀 Execution Model

Each script can be run inside an unprivileged Rhino container (such as `ghcr.io/pandev22/rhino-generic:latest` or `ghcr.io/pandev22/rhino-steamcmd:latest`):

```bash
# Example manual test for Paper:
docker run --rm -v $(pwd)/test-server:/home/container -e MINECRAFT_VERSION=1.21.4 ghcr.io/pandev22/rhino-generic:latest bash /installers/paper.sh
```
