#!/usr/bin/env python3
import json
import os
from pathlib import Path
from datetime import datetime, timezone

BASE_DIR = Path(__file__).resolve().parent
INSTALLERS_DIR = BASE_DIR.parent / "installers"
TEMPLATES_DIR = BASE_DIR

def read_installer(filename):
    path = INSTALLERS_DIR / filename
    if path.exists():
        # Always embed LF line endings: a CRLF install script breaks the shell
        # (`cd /home/container\r`) and was a real production failure.
        text = path.read_text(encoding="utf-8")
        return text.replace("\r\n", "\n").replace("\r", "\n")
    return ""

TEMPLATES = [
    {
        "id": "paper",
        "name": "Paper",
        "author": "Rhino Team",
        "description": "High-performance Minecraft server with PaperMC API, anti-xray and optimal performance.",
        "default_image": "ghcr.io/pandev22/rhino-java:21",
        "docker_images": {
            "Java 21 (Default)": "ghcr.io/pandev22/rhino-java:21",
            "Java 17 LTS": "ghcr.io/pandev22/rhino-java:17",
            "Java 8 Legacy": "ghcr.io/pandev22/rhino-java:8",
            "Java 25 Early Access": "ghcr.io/pandev22/rhino-java:25"
        },
        "startup_command": "java {{RHINO_JAVA_FLAGS}} -jar {{SERVER_JARFILE}} nogui",
        "stop_command": "stop",
        "features": ["eula_modal", "java_version_selector", "auto_update", "config_parser"],
        "installer_file": "paper.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Server JAR Name",
                "description": "The executable server JAR filename",
                "env_variable": "SERVER_JARFILE",
                "default_value": "server.jar",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Minecraft Version",
                "description": "Target Minecraft version (e.g. 1.21.4, 1.20.4 or 'latest')",
                "env_variable": "MINECRAFT_VERSION",
                "default_value": "latest",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 2
            },
            {
                "name": "Build Number",
                "description": "Specific Paper build number or 'latest'",
                "env_variable": "BUILD_NUMBER",
                "default_value": "latest",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 3
            },
            {
                "name": "Server Port",
                "description": "Primary TCP server port for client connections",
                "env_variable": "SERVER_PORT",
                "default_value": "25565",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 4
            }
        ]
    },
    {
        "id": "forge",
        "name": "Forge",
        "author": "Rhino Team",
        "description": "Minecraft Forge modded server supporting mods and custom modpacks.",
        "default_image": "ghcr.io/pandev22/rhino-java:21",
        "docker_images": {
            "Java 21 (Default)": "ghcr.io/pandev22/rhino-java:21",
            "Java 17 LTS": "ghcr.io/pandev22/rhino-java:17",
            "Java 8 Legacy": "ghcr.io/pandev22/rhino-java:8"
        },
        "startup_command": "java {{RHINO_JAVA_FLAGS}} -jar {{SERVER_JARFILE}} nogui",
        "stop_command": "stop",
        "features": ["eula_modal", "java_version_selector"],
        "installer_file": "forge.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Minecraft Version",
                "description": "Target Minecraft version for Forge",
                "env_variable": "MC_VERSION",
                "default_value": "1.20.4",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Forge Version",
                "description": "Forge build release or 'latest'",
                "env_variable": "FORGE_VERSION",
                "default_value": "latest",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 2
            },
            {
                "name": "Server JAR Name",
                "description": "Launch jarfile name",
                "env_variable": "SERVER_JARFILE",
                "default_value": "server.jar",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 3
            }
        ]
    },
    {
        "id": "vanilla",
        "name": "Vanilla",
        "author": "Rhino Team",
        "description": "Official unmodded Minecraft server directly from Mojang Studios.",
        "default_image": "ghcr.io/pandev22/rhino-java:21",
        "docker_images": {
            "Java 21 (Default)": "ghcr.io/pandev22/rhino-java:21",
            "Java 17 LTS": "ghcr.io/pandev22/rhino-java:17",
            "Java 8 Legacy": "ghcr.io/pandev22/rhino-java:8"
        },
        "startup_command": "java {{RHINO_JAVA_FLAGS}} -jar {{SERVER_JARFILE}} nogui",
        "stop_command": "stop",
        "features": ["eula_modal", "java_version_selector"],
        "installer_file": "vanilla.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Vanilla Version",
                "description": "Target Minecraft vanilla release version or 'latest'",
                "env_variable": "VANILLA_VERSION",
                "default_value": "latest",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Server JAR Name",
                "description": "Downloaded vanilla server JAR",
                "env_variable": "SERVER_JARFILE",
                "default_value": "server.jar",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 2
            }
        ]
    },
    {
        "id": "bungeecord",
        "name": "BungeeCord",
        "author": "Rhino Team",
        "description": "Classic multi-server proxy linking multiple Minecraft instances together.",
        "default_image": "ghcr.io/pandev22/rhino-java:21",
        "docker_images": {
            "Java 21 (Default)": "ghcr.io/pandev22/rhino-java:21",
            "Java 17 LTS": "ghcr.io/pandev22/rhino-java:17",
            "Java 8 Legacy": "ghcr.io/pandev22/rhino-java:8"
        },
        "startup_command": "java {{RHINO_JAVA_FLAGS}} -jar {{SERVER_JARFILE}}",
        "stop_command": "end",
        "features": ["java_version_selector"],
        "installer_file": "bungeecord.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Server JAR Name",
                "description": "BungeeCord jarfile name",
                "env_variable": "SERVER_JARFILE",
                "default_value": "BungeeCord.jar",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Proxy Port",
                "description": "Port on which BungeeCord listens",
                "env_variable": "SERVER_PORT",
                "default_value": "25577",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 2
            }
        ]
    },
    {
        "id": "pocketminemp",
        "name": "PocketMine-MP",
        "author": "Rhino Team",
        "description": "Custom server software for Minecraft Bedrock Edition written in PHP.",
        "default_image": "ghcr.io/pandev22/rhino-generic:latest",
        "docker_images": {
            "Generic (Default)": "ghcr.io/pandev22/rhino-generic:latest"
        },
        "startup_command": "./bin/php7/bin/php -dopcache.enable_cli=1 -dopcache.jit=1205 -dopcache.jit_buffer_size=128M -dzend.assertions=-1 PocketMine-MP.phar --no-wizard",
        "stop_command": "stop",
        "features": ["auto_update"],
        "installer_file": "pocketminemp.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Bedrock Port",
                "description": "Default UDP port for Bedrock clients",
                "env_variable": "SERVER_PORT",
                "default_value": "19132",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 1
            }
        ]
    },
    {
        "id": "velocity",
        "name": "Velocity",
        "author": "Rhino Team",
        "description": "Next-generation modern Minecraft proxy by PaperMC with unrivaled throughput.",
        "default_image": "ghcr.io/pandev22/rhino-java:21",
        "docker_images": {
            "Java 21 (Default)": "ghcr.io/pandev22/rhino-java:21",
            "Java 17 LTS": "ghcr.io/pandev22/rhino-java:17"
        },
        "startup_command": "java {{RHINO_JAVA_FLAGS}} -jar {{SERVER_JARFILE}}",
        "stop_command": "end",
        "features": ["java_version_selector"],
        "installer_file": "velocity.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Server JAR Name",
                "description": "Velocity JAR name",
                "env_variable": "SERVER_JARFILE",
                "default_value": "velocity.jar",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Proxy Port",
                "description": "Bind port for proxy listeners",
                "env_variable": "SERVER_PORT",
                "default_value": "25577",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 2
            }
        ]
    },
    {
        "id": "sponge",
        "name": "Sponge",
        "author": "Rhino Team",
        "description": "SpongeVanilla server platform enabling rich Java plugins and modular hooks.",
        "default_image": "ghcr.io/pandev22/rhino-java:21",
        "docker_images": {
            "Java 21 (Default)": "ghcr.io/pandev22/rhino-java:21",
            "Java 17 LTS": "ghcr.io/pandev22/rhino-java:17"
        },
        "startup_command": "java {{RHINO_JAVA_FLAGS}} -jar {{SERVER_JARFILE}} nogui",
        "stop_command": "stop",
        "features": ["eula_modal", "java_version_selector"],
        "installer_file": "sponge.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Server JAR Name",
                "description": "Sponge executable JAR",
                "env_variable": "SERVER_JARFILE",
                "default_value": "server.jar",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            }
        ]
    },
    {
        "id": "fabric",
        "name": "Fabric",
        "author": "Rhino Team",
        "description": "Lightweight, modular modding toolchain for Minecraft releases and snapshots.",
        "default_image": "ghcr.io/pandev22/rhino-java:21",
        "docker_images": {
            "Java 21 (Default)": "ghcr.io/pandev22/rhino-java:21",
            "Java 17 LTS": "ghcr.io/pandev22/rhino-java:17"
        },
        "startup_command": "java {{RHINO_JAVA_FLAGS}} -jar {{SERVER_JARFILE}} nogui",
        "stop_command": "stop",
        "features": ["eula_modal", "java_version_selector"],
        "installer_file": "fabric.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Server JAR Name",
                "description": "Launch jarfile name",
                "env_variable": "SERVER_JARFILE",
                "default_value": "server.jar",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            }
        ]
    },
    {
        "id": "ark",
        "name": "ARK: Survival Evolved",
        "author": "Rhino Team",
        "description": "ARK: Survival Evolved multiplayer server running on native Linux SteamCMD.",
        "default_image": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "docker_images": {
            "SteamCMD (Default)": "ghcr.io/pandev22/rhino-steamcmd:latest"
        },
        "startup_command": "./ShooterGame/Binaries/Linux/ShooterGameServer TheIsland?listen?Port={{SERVER_PORT}}?SessionName=\"{{SERVER_NAME}}\"?ServerPassword=\"{{SERVER_PASSWORD}}\"?ServerAdminPassword=\"{{ADMIN_PASSWORD}}\" -server -log -NoHangDetection -usecache -structurememopts -servergamelog",
        "stop_command": "doexit",
        "features": ["auto_update"],
        "installer_file": "ark.sh",
        "install_container": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Session Name",
                "description": "Server public session name",
                "env_variable": "SERVER_NAME",
                "default_value": "Rhino Ark Server",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Server Password",
                "description": "Password required for clients to join",
                "env_variable": "SERVER_PASSWORD",
                "default_value": "",
                "rules": "string",
                "field_type": "password",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 2
            },
            {
                "name": "Admin Password",
                "description": "Server admin console password",
                "env_variable": "ADMIN_PASSWORD",
                "default_value": "RhinoAdminPass123!",
                "rules": "required|string",
                "field_type": "password",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 3
            },
            {
                "name": "Server Port",
                "description": "Game communication UDP port",
                "env_variable": "SERVER_PORT",
                "default_value": "7777",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 4
            }
        ]
    },
    {
        "id": "tf2",
        "name": "Team Fortress 2",
        "author": "Rhino Team",
        "description": "Valve Team Fortress 2 Source Dedicated Server (SRCDS).",
        "default_image": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "docker_images": {
            "SteamCMD (Default)": "ghcr.io/pandev22/rhino-steamcmd:latest"
        },
        "startup_command": "./srcds_run -game tf -console -norestart -nobreakpad -tickrate 66 -ip 0.0.0.0 -port {{SERVER_PORT}} +map {{START_MAP}} +maxplayers {{MAX_PLAYERS}}",
        "stop_command": "quit",
        "features": ["auto_update"],
        "installer_file": "tf2.sh",
        "install_container": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Starting Map",
                "description": "Default server map",
                "env_variable": "START_MAP",
                "default_value": "ctf_2fort",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Max Players",
                "description": "Maximum player slots",
                "env_variable": "MAX_PLAYERS",
                "default_value": "24",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 2
            },
            {
                "name": "Server Port",
                "description": "UDP port",
                "env_variable": "SERVER_PORT",
                "default_value": "27015",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 3
            }
        ]
    },
    {
        "id": "gmod",
        "name": "Garry's Mod",
        "author": "Rhino Team",
        "description": "Sandbox physics multiplayer game server powered by SRCDS.",
        "default_image": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "docker_images": {
            "SteamCMD (Default)": "ghcr.io/pandev22/rhino-steamcmd:latest"
        },
        "startup_command": "./srcds_run -game garrysmod -console -norestart -nobreakpad -disableluarefresh -tickrate 33 -ip 0.0.0.0 -port {{SERVER_PORT}} +gamemode {{GAMEMODE}} +map {{START_MAP}} +maxplayers {{MAX_PLAYERS}}",
        "stop_command": "quit",
        "features": ["auto_update"],
        "installer_file": "gmod.sh",
        "install_container": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Gamemode",
                "description": "Garry's Mod gamemode",
                "env_variable": "GAMEMODE",
                "default_value": "sandbox",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Starting Map",
                "description": "Initial map",
                "env_variable": "START_MAP",
                "default_value": "gm_construct",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 2
            },
            {
                "name": "Max Players",
                "description": "Player slot capacity",
                "env_variable": "MAX_PLAYERS",
                "default_value": "20",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 3
            },
            {
                "name": "Server Port",
                "description": "Primary UDP port",
                "env_variable": "SERVER_PORT",
                "default_value": "27015",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 4
            }
        ]
    },
    {
        "id": "cs2",
        "name": "Counter-Strike 2",
        "author": "Rhino Team",
        "description": "Valve next-gen Source 2 Counter-Strike competitive server.",
        "default_image": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "docker_images": {
            "SteamCMD (Default)": "ghcr.io/pandev22/rhino-steamcmd:latest"
        },
        "startup_command": "./game/cs2.sh -dedicated -console -usercon -nobreakpad -ip 0.0.0.0 -port {{SERVER_PORT}} +map {{START_MAP}} +maxplayers {{MAX_PLAYERS}}",
        "stop_command": "quit",
        "features": ["auto_update"],
        "installer_file": "cs2.sh",
        "install_container": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Starting Map",
                "description": "Default map name",
                "env_variable": "START_MAP",
                "default_value": "de_dust2",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Max Players",
                "description": "Player slot limit",
                "env_variable": "MAX_PLAYERS",
                "default_value": "10",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 2
            },
            {
                "name": "Server Port",
                "description": "UDP server port",
                "env_variable": "SERVER_PORT",
                "default_value": "27015",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 3
            }
        ]
    },
    {
        "id": "unturned",
        "name": "Unturned",
        "author": "Rhino Team",
        "description": "Zombie survival sandbox game server by Smartly Dressed Games.",
        "default_image": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "docker_images": {
            "SteamCMD (Default)": "ghcr.io/pandev22/rhino-steamcmd:latest"
        },
        "startup_command": "./Unturned_Headless.x86_64 -batchmode -nographics +secureserver/Default",
        "stop_command": "shutdown",
        "features": ["auto_update"],
        "installer_file": "unturned.sh",
        "install_container": "ghcr.io/pandev22/rhino-steamcmd:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Server Port",
                "description": "Game communication port",
                "env_variable": "SERVER_PORT",
                "default_value": "27015",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 1
            },
            {
                "name": "Max Players",
                "description": "Player slot count",
                "env_variable": "MAX_PLAYERS",
                "default_value": "24",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 2
            }
        ]
    },
    {
        "id": "fivem",
        "name": "FiveM",
        "author": "Rhino Team",
        "description": "CitizenFX multiplayer modification server for Grand Theft Auto V.",
        "default_image": "ghcr.io/pandev22/rhino-generic:latest",
        "docker_images": {
            "Generic (Default)": "ghcr.io/pandev22/rhino-generic:latest"
        },
        "startup_command": "./alpine/opt/cfx-server/ld-musl-x86_64.so.1 --library-path \"alpine/opt/cfx-server/usr/lib/v8/:alpine/opt/cfx-server/lib/:alpine/opt/cfx-server/usr/lib/\" -- alpine/opt/cfx-server/FXServer +set citizen_dir alpine/opt/cfx-server/citizen/ +set endpoint_add_tcp \"0.0.0.0:{{SERVER_PORT}}\" +set endpoint_add_udp \"0.0.0.0:{{SERVER_PORT}}\" +set onesync on +set sv_endpointprivacy true +set sv_licenseKey \"{{FIVEM_LICENSE}}\" +exec server.cfg",
        "stop_command": "quit",
        "features": ["config_parser"],
        "installer_file": "fivem.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Cfx License Key",
                "description": "CitizenFX Keymaster server registration key",
                "env_variable": "FIVEM_LICENSE",
                "default_value": "",
                "rules": "required|string",
                "field_type": "password",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Server Port",
                "description": "FiveM TCP/UDP listening port",
                "env_variable": "SERVER_PORT",
                "default_value": "30120",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 2
            }
        ]
    },
    {
        "id": "nodejs",
        "name": "Node.js",
        "author": "Rhino Team",
        "description": "High-efficiency Node.js LTS runtime for Discord bots, APIs and web workers.",
        "default_image": "ghcr.io/pandev22/rhino-generic:latest",
        "docker_images": {
            "Generic (Default)": "ghcr.io/pandev22/rhino-generic:latest"
        },
        "startup_command": "node --max-old-space-size={{RHINO_HEAP_MB}} --max-semi-space-size=16 {{MAIN_FILE}}",
        "stop_command": "^C",
        "features": ["auto_update"],
        "installer_file": "nodejs.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Main File",
                "description": "Entry javascript file",
                "env_variable": "MAIN_FILE",
                "default_value": "index.js",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Server Port",
                "description": "HTTP application listen port",
                "env_variable": "SERVER_PORT",
                "default_value": "3000",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 2
            }
        ]
    },
    {
        "id": "python",
        "name": "Python",
        "author": "Rhino Team",
        "description": "Python 3.12 environment with automated virtualenv and pip requirements management.",
        "default_image": "ghcr.io/pandev22/rhino-generic:latest",
        "docker_images": {
            "Generic (Default)": "ghcr.io/pandev22/rhino-generic:latest"
        },
        "startup_command": ".venv/bin/python3 -X utf8 {{MAIN_FILE}}",
        "stop_command": "^C",
        "features": ["auto_update"],
        "installer_file": "python.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Main File",
                "description": "Entry Python script",
                "env_variable": "MAIN_FILE",
                "default_value": "main.py",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Server Port",
                "description": "HTTP application listen port",
                "env_variable": "SERVER_PORT",
                "default_value": "8000",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 2
            }
        ]
    },
    {
        "id": "bun",
        "name": "Bun",
        "author": "Rhino Team",
        "description": "Ultra-fast all-in-one JavaScript & TypeScript server engine powered by Bun.",
        "default_image": "ghcr.io/pandev22/rhino-generic:latest",
        "docker_images": {
            "Generic (Default)": "ghcr.io/pandev22/rhino-generic:latest"
        },
        "startup_command": "bun --smol run {{MAIN_FILE}}",
        "stop_command": "^C",
        "features": ["auto_update"],
        "installer_file": "bun.sh",
        "install_container": "ghcr.io/pandev22/rhino-generic:latest",
        "install_entrypoint": "bash",
        "variables": [
            {
                "name": "Main File",
                "description": "TypeScript or JavaScript entry file",
                "env_variable": "MAIN_FILE",
                "default_value": "index.ts",
                "rules": "required|string",
                "field_type": "text",
                "user_viewable": True,
                "user_editable": True,
                "sort_order": 1
            },
            {
                "name": "Server Port",
                "description": "HTTP application listen port",
                "env_variable": "SERVER_PORT",
                "default_value": "3000",
                "rules": "required|numeric",
                "field_type": "number",
                "user_viewable": True,
                "user_editable": False,
                "sort_order": 2
            }
        ]
    }
]

JAVA_VARS = lambda preset, base: [
    {
        "name": "JVM Preset",
        "description": "JVM flag set tuned by the image: aikar (game servers, default), proxy (Velocity/BungeeCord), zgc (Java 21+, lowest pauses), minimal (heap only)",
        "env_variable": "JAVA_PRESET",
        "default_value": preset,
        "rules": "required|string|in:aikar,proxy,zgc,minimal",
        "field_type": "text",
        "user_viewable": True,
        "user_editable": True,
        "sort_order": base
    },
    {
        "name": "Extra JVM Flags",
        "description": "Optional additional JVM options (each must start with '-'), appended after the preset",
        "env_variable": "JAVA_EXTRA_FLAGS",
        "default_value": "",
        "rules": "nullable|string|max:200",
        "field_type": "text",
        "user_viewable": True,
        "user_editable": True,
        "sort_order": base + 1
    },
]

def main():
    now_ts = datetime.now(timezone.utc).isoformat()
    generated_count = 0
    for t in TEMPLATES:
        slug = t["id"]
        install_script_content = read_installer(t["installer_file"])
        if "{{RHINO_JAVA_FLAGS}}" in t["startup_command"]:
            preset = "proxy" if t["id"] in ("bungeecord", "velocity") else "aikar"
            t["variables"] = t["variables"] + JAVA_VARS(preset, len(t["variables"]) + 1)
        
        export_obj = {
            "format": "rhino-now-v1",
            "exported_at": now_ts,
            "now": {
                "name": t["name"],
                "author": t["author"],
                "description": t["description"],
                "default_image": t["default_image"],
                "docker_images": t["docker_images"],
                "startup_command": t["startup_command"],
                "stop_command": t["stop_command"],
                "features": t["features"],
                "install_script": install_script_content,
                "install_container": t["install_container"],
                "install_entrypoint": t["install_entrypoint"]
            },
            "variables": t["variables"]
        }
        
        out_path = TEMPLATES_DIR / f"{slug}.json"
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(export_obj, f, indent=2, ensure_ascii=False)
            f.write("\n")
            
        print(f"Generated {out_path.name}")
        generated_count += 1
        
    print(f"\nAll {generated_count} Rhino Now template JSON files generated successfully in {TEMPLATES_DIR}.")

if __name__ == "__main__":
    main()
