# 🦏 Rhino Images (`rhino-images`)

[![Build, Scan, Sign and Release](https://github.com/pandev22/Rhino-Image/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/pandev22/Rhino-Image/actions/workflows/build-and-release.yml)
[![Weekly Security Rebuild](https://github.com/pandev22/Rhino-Image/actions/workflows/weekly-security-rebuild.yml/badge.svg)](https://github.com/pandev22/Rhino-Image/actions/workflows/weekly-security-rebuild.yml)
[![Security: Trivy](https://img.shields.io/badge/Security-Trivy%20Scanned-blue.svg)](https://aquasecurity.github.io/trivy/)
[![Signature: Cosign](https://img.shields.io/badge/Signature-Cosign%20OIDC-green.svg)](https://sigstore.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

Dépôt officiel des images de conteneurs durcies, ultra-optimisées et multi-architectures destinées à **[Rhino Panel](https://rhino.overnode.fr)** et son agent démon en Rust **[Rhino Action](https://github.com/pandev22/Rhino-Action)** (le remplaçant moderne, performant et ultra-sécurisé de Pterodactyl & Wings).

---

## 📑 Sommaire

1. [Vision & Philosophie DevSecOps](#-vision--philosophie-devsecops)
2. [Catalogue des Images & Tags GHCR](#-catalogue-des-images--tags-ghcr)
3. [Le Lanceur Universel PID 1 en Rust (`rhino-entrypoint`)](#-le-lanceur-universel-pid-1-en-rust-rhino-entrypoint)
4. [Spécifications de Sécurité (Blindage OCI)](#-spécifications-de-sécurité-blindage-oci)
5. [Guide d'Intégration avec Rhino Action](#-guide-dintégration-avec-rhino-action)
6. [Exemples de Démarrage Rapide (Docker CLI & Compose)](#-exemples-de-démarrage-rapide-docker-cli--compose)
7. [Suite de Vérification Locale (`verify-images.sh`)](#-suite-de-vérification-locale-verify-imagessh)
8. [Pipeline CI/CD & Signature Cryptographique](#-pipeline-cicd--signature-cryptographique)

---

## 🛡️ Vision & Philosophie DevSecOps

Les conteneurs de serveurs de jeux traditionnels (ex: Pterodactyl yolkes) souffrent historiquement de failles structurelles :
- **Lanceurs Bash vulnérables** : scripts `entrypoint.sh` exécutant des `eval` avec interpolation de variables non assainies, ouvrant la porte à des injections de commandes.
- **Mauvaise gestion des signaux POSIX** : les arrêts `SIGTERM` ne sont pas toujours relayés aux processus enfants du jeu, provoquant des arrêts brutaux par `SIGKILL` après 10s et des corruptions de mondes (ex: Minecraft chunk corruption, bases SQLite corrompues).
- **Processus zombies** : absence de collecteur init (`waitpid`), provoquant une saturation de la table des processus (PID exhaustion) sur les machines hébergeant plus de 500 serveurs.
- **Surface d'attaque excessive** : shells interactifs (`/bin/sh`, `/bin/bash`), utilitaires de compilation ou de réseau inutiles facilitant l'exploitation de RCE (ex: Log4Shell CVE-2021-44228).

**Rhino Images** apporte une rupture technologique complète :
- **PID 1 Natif en Rust Statique (`rhino-entrypoint`)** : binaire compilé avec `musl`, pesant moins de 400 Ko, zéro allocation inutile, récolte automatique des zombies et propagation instantanée des signaux.
- **Rootfs Lecture Seule (`--read-only`)** : aucun binaire système ne peut être altéré à l'exécution.
- **Moindre Privilège Strict** : utilisateur non-root `rhino` (`1000:1000`), abandon total des capacités Linux (`--cap-drop=ALL`), et interdiction d'élévation (`no-new-privileges:true`).
- **Scan Trivy & Signature Cosign** : chaque image publiée sur GitHub Container Registry (GHCR) est analysée contre les CVE et signée cryptographiquement via Sigstore/OIDC.

---

## 📦 Catalogue des Images & Tags GHCR

Toutes les images sont publiées sur **GitHub Container Registry** sous l'espace `ghcr.io/pandev22/rhino-*`.

| Image | Tag GHCR | Architectures | Base OS | Runtimes inclus | Cas d'usage principaux |
|---|---|---|---|---|---|
| **Java 21 LTS** *(Défaut)* | `ghcr.io/pandev22/rhino-java:21`<br>`ghcr.io/pandev22/rhino-java:latest` | `linux/amd64`<br>`linux/arm64` | Distroless (Debian 13, sans shell) | Eclipse Temurin JRE 21 LTS (allégé) | Minecraft 1.20.5+, Paper, Purpur, Velocity, Folia |
| **Java 17 LTS** | `ghcr.io/pandev22/rhino-java:17` | `linux/amd64`<br>`linux/arm64` | Distroless (Debian 13, sans shell) | Eclipse Temurin JRE 17 LTS (allégé) | Minecraft 1.18 - 1.20.4, Forge, Fabric, plugins legacy |
| **Java 8 Legacy** | `ghcr.io/pandev22/rhino-java:8` | `linux/amd64`<br>`linux/arm64` | Distroless (Debian 13, sans shell) | Eclipse Temurin JRE 8 (allégé) | Minecraft 1.8 - 1.16.5, serveurs BungeeCord legacy |
| **Java 25 (Next-Gen)** | `ghcr.io/pandev22/rhino-java:25` | `linux/amd64`<br>`linux/arm64` | Distroless (Debian 13, sans shell) | Eclipse Temurin JRE 25 (allégé) | Tests anticipés de runtimes, optimisations ZGC |
| **SteamCMD** | `ghcr.io/pandev22/rhino-steamcmd:latest` | `linux/amd64`<br>`linux/arm64` | Debian 13 (Trixie Slim) | SteamCMD natif Valve, glibc multi-arch i386, UTF-8 | Rust, ARK, CS2, Valheim, Palworld Linux |
| **Wine Windows** | `ghcr.io/pandev22/rhino-wine:latest` | `linux/amd64` | Debian 13 (Trixie Slim) | Wine WoW64 (32/64-bit), Xvfb headless display, cabextract | Serveurs de jeux Windows natifs (Assetto Corsa, DayZ, Space Engineers) |
| **Generic Polyvalent** | `ghcr.io/pandev22/rhino-generic:latest` | `linux/amd64`<br>`linux/arm64` | Alpine Linux 3.21 | Bun 1.4+, Node.js LTS, Python 3.12, Astral uv, Git, jq | Bots Discord, serveurs API, scripts, webhooks, Node/Python servers |

### ⚡ Optimisations de taille et de démarrage

- **Java** : base *distroless* + JRE Temurin allégé (sans man pages, sources, X11). Java 21 : ~63 Mo compressés / 270 Mo décompressés (≈ 450 Mo avant) ; Java 8 : ~52 Mo compressés.
- **SteamCMD / Wine** : pas de documentation ni de locales (`dpkg path-exclude`), amorçage SteamCMD dans la même couche, plus de préfixe Wine inutile (le volume `/home/container` le masquait).
- **Entrypoint** : compilé nativement pour chaque architecture cible (arm64 inclus), sondage PID 1 à 250 ms au repos (moins de réveils avec des centaines d'instances).
- **Mémoire calculée par l'image** : à partir de `SERVER_MEMORY` (Mo), l'entrypoint exporte
  - `RHINO_HEAP_MB` = limite − max(256 Mo, 12 %) : le noyau ne tue plus le serveur quand `-Xmx` = limite du conteneur ;
  - `RHINO_JAVA_FLAGS` : jeu de flags JVM complet (`-Xms/-Xmx`, G1 « Aikar » adapté à la taille du tas, `ExitOnOutOfMemoryError`, déduplication de chaînes…). Dans un Now : `java {{RHINO_JAVA_FLAGS}} -jar {{SERVER_JARFILE}} nogui`. Les flags évoluent avec l'image, sans modifier les Nows.
  - Variables utilisateur : `JAVA_PRESET` (`aikar` défaut · `proxy` · `zgc` Java 21+ · `minimal`) et `JAVA_EXTRA_FLAGS` (options `-…` additionnelles).
- Les modèles `templates/*.json` embarquent des commandes de démarrage optimisées par jeu (srcds `-norestart -nobreakpad`, FiveM `onesync`, Node `--max-old-space-size`, Bun `--smol`, PocketMine JIT…).
- Les images Java n'ont plus de shell : `RHINO_USE_SHELL=1` et les commandes avec `|`, `;`, `&` n'y fonctionnent pas (utiliser l'image generic).


---

## ⚙️ Le Lanceur Universel PID 1 en Rust (`rhino-entrypoint`)

Situé dans `entrypoint/`, `rhino-entrypoint` est le cœur de chaque conteneur Rhino.

```
                      +---------------------------------------+
                      |      Rhino Action (Host Daemon)       |
                      +---------------------------------------+
                                          |
                      docker stop (SIGTERM) / console input (stdin)
                                          v
                      +---------------------------------------+
                      |  rhino-entrypoint (PID 1 - musl Rust)  |
                      +---------------------------------------+
                          |                  |            |
                 [Collecte Zombies]   [Relais Signaux]  [Variables]
                  waitpid(-1, WNOHANG)  kill(-pid, SIG)  {{PORT}} -> $PORT
                          |                  |            |
                          +------------------+------------+
                                             v
                      +---------------------------------------+
                      |   Processus Serveur de Jeu (Group PID) |
                      |   (ex: java -jar server.jar)          |
                      +---------------------------------------+
```

### Fonctionnalités Clés :
1. **Gestionnaire Init (PID 1)** :
   - Écoute et intercepte `SIGTERM`, `SIGINT`, `SIGHUP`, `SIGQUIT`, `SIGUSR1`, `SIGUSR2`.
   - Transmet immédiatement chaque signal à l'ensemble du groupe de processus enfants (`kill(-child_pid, sig)`).
   - Laisse un délai de grâce configurable (`RHINO_STOP_TIMEOUT`, défaut 30s) pour permettre au serveur de sauvegarder ses fichiers avant d'envoyer un `SIGKILL` si nécessaire.
2. **Collecteur de Zombies (Zombie Reaping)** :
   - Boucle d'attente non-bloquante `waitpid(-1, &mut status, WNOHANG)` évitant toute fuite dans la table de processus de l'hôte.
3. **Interpolation Sans Shell (Anti-Injection)** :
   - Remplace de manière sécurisée en mémoire vive les variables `{{VAR}}`, `${VAR}` et `$VAR` depuis l'environnement.
   - Ne fait aucun appel à `/bin/sh -c` ou `eval` : les arguments sont découpés avec gestion stricte des guillemets et exécutés via l'appel système direct `execve`.
4. **Support Headless Display Intégré (Xvfb)** :
   - Pour les conteneurs Windows (`rhino-wine`), lorsque `RHINO_START_XVFB=1` est actif, le lanceur démarre automatiquement le serveur d'affichage X11 virtuel `Xvfb` sur `:99` et s'assure de son extinction propre à la fermeture.
5. **Nom de processus lisible sur l'hôte** :
   - Si `RHINO_PROCESS_TITLE` est défini (Rhino Action l'injecte : `Rhino Instance <nom du serveur>`), la ligne de commande de PID 1 est réécrite (technique *setproctitle*, environnement préservé) et `prctl(PR_SET_NAME)` est appliqué : chaque serveur apparaît sous ce nom dans `htop` / `ps` sur la machine hôte.
6. **Console interactive (TTY)** :
   - Avec un pseudo-terminal (`tty: true`, cas de Rhino Action), le groupe de processus du jeu devient le groupe **au premier plan** du terminal (`tcsetpgrp`). Sans cela, la première commande envoyée sur stdin déclenchait `SIGTTIN` et stoppait le serveur (état `T`).
7. **Propagation Stricte des Codes de Sortie** :
   - Le conteneur se termine avec le code exact du processus de jeu (ex: `0` pour un arrêt propre, `42`, ou `128 + signal` en cas de signal critique).

---

## 🔒 Spécifications de Sécurité (Blindage OCI)

Chaque image respecte les règles strictes de sécurité DevSecOps :

### 1. Utilisateur Non-Root Imposé
- Tous les conteneurs s'exécutent avec le compte `rhino` :
  - **UID** : `1000`
  - **GID** : `1000`
  - **Home / Workdir** : `/home/container`
- Si la variable `RHINO_REQUIRE_NON_ROOT=1` est définie et que le conteneur démarre par erreur en tant que root (`UID 0`), le conteneur refuse immédiatement de s'exécuter.

### 2. Système de Fichiers en Lecture Seule (`--read-only`)
Les conteneurs sont conçus pour fonctionner avec un système de fichiers racine en lecture seule. Seuls les répertoires nécessaires sont montés en écriture :
- `/tmp` : monté en `tmpfs` avec les options `rw,noexec,nosuid`.
- `/home/container` : volume persistant du serveur de jeu.

### 3. Suppression des Capacités Linux (`--cap-drop=ALL`)
Aucune capacité Linux spécifique n'est requise pour exécuter les serveurs de jeux. Les conteneurs tournent avec `--cap-drop=ALL` et `--security-opt=no-new-privileges:true`.

### 4. Suppression des Bits SUID / SGID
Lors du build Docker, un nettoyage complet élimine les bits SUID et SGID (`chmod a-s`) sur l'ensemble de l'arborescence, éliminant tout risque d'élévation locale de privilèges.

---

## 🔌 Guide d'Intégration avec Rhino Action

Le démon d'hôte **Rhino Action** (écrit en Rust avec `bollard`) pilote directement ces conteneurs OCI.

### Configuration du Conteneur dans Rhino Action

Lors de la création du conteneur via l'API Docker / Bollard, appliquez la configuration suivante :

```rust
// Extrait de configuration conteneur pour Rhino Action (Bollard)
let host_config = HostConfig {
    // Isolation & Moindre privilège
    readonly_rootfs: Some(true),
    cap_drop: Some(vec!["ALL".to_string()]),
    security_opt: Some(vec!["no-new-privileges:true".to_string()]),
    
    // Montages
    tmpfs: Some(HashMap::from([
        ("/tmp".to_string(), "rw,noexec,nosuid,size=256m".to_string()),
    ])),
    binds: Some(vec![
        format!("{}:/home/container:rw", server_data_dir.display()),
    ]),
    
    // Ressources cgroups v2
    memory: Some(server_ram_bytes),
    memory_swap: Some(server_ram_bytes), // Pas de swap pour garantir la stabilité des ticks
    nano_cpus: Some((server_cores * 1_000_000_000.0) as i64),
    
    ..Default::default()
};

let container_config = Config {
    image: Some("ghcr.io/pandev22/rhino-java:21".to_string()),
    user: Some("1000:1000".to_string()),
    working_dir: Some("/home/container".to_string()),
    env: Some(vec![
        format!("STARTUP=java -Xms128M -Xmx{}M -jar {{SERVER_JARFILE}} --port {{SERVER_PORT}}", allocated_ram_mb),
        format!("SERVER_JARFILE={}", jar_name),
        format!("SERVER_PORT={}", primary_port),
        "HOME=/home/container".to_string(),
        "USER=rhino".to_string(),
    ]),
    attach_stdin: Some(true),
    attach_stdout: Some(true),
    attach_stderr: Some(true),
    open_stdin: Some(true),
    tty: Some(true),
    ..Default::default()
};
```

---

## 🚀 Exemples de Démarrage Rapide (Docker CLI & Compose)

### 1. Serveur Minecraft Paper (Java 21)

```bash
docker run -d \
  --name minecraft-srv \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=256m \
  -v /srv/rhino-action/servers/mc1:/home/container:rw \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  -p 25565:25565 \
  -e SERVER_PORT=25565 \
  -e SERVER_MEMORY=4096 \
  -e STARTUP="java -Xms1024M -Xmx{{SERVER_MEMORY}}M -jar paper.jar --port {{SERVER_PORT}} nogui" \
  ghcr.io/pandev22/rhino-java:21
```

### 2. Bot Discord / Application Node & Python (Generic)

```bash
docker run -d \
  --name discord-bot \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid \
  -v /srv/rhino-action/servers/bot1:/home/container:rw \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  -e STARTUP="bun run index.ts" \
  ghcr.io/pandev22/rhino-generic:latest
```

### 3. Fichier Docker Compose

```yaml
services:
  palworld-server:
    image: ghcr.io/pandev22/rhino-steamcmd:latest
    container_name: palworld-01
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=512m
    volumes:
      - /srv/rhino/palworld:/home/container:rw
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    ports:
      - "8211:8211/udp"
    environment:
      - SERVER_PORT=8211
      - PLAYERS=32
      - STARTUP=./PalServer.sh -port={{SERVER_PORT}} -players={{PLAYERS}}
    restart: unless-stopped
```

---

## 🧪 Suite de Vérification Locale (`verify-images.sh`)

Le script `scripts/verify-images.sh` permet de valider automatiquement sur votre environnement local l'ensemble des critères DevSecOps :

```bash
# Rendre le script exécutable et lancer la suite de tests
./scripts/verify-images.sh
```

### Tests automatisés inclus :
- [x] Compilation et passage de l'ensemble des tests unitaires Rust du lanceur (`cargo test`).
- [x] Vérification clippy sans aucun warning (`cargo clippy --all-targets -- -D warnings`).
- [x] Build multi-stage OCI de test.
- [x] Vérification de l'utilisateur non-root (`UID=1000`, `GID=1000`).
- [x] Test de protection en écriture sur la racine (`--read-only` rootfs).
- [x] Vérification de l'abandon complet des privilèges (`--cap-drop=ALL` & `no-new-privileges`).
- [x] Validation de l'interpolation sans shell des variables (`{{VAR}}` et `${VAR}`).
- [x] Propagation conforme du code de retour du processus enfant (ex: code `42`).
- [x] Capture et transmission du signal d'arrêt propre `SIGTERM`.

---

## 🚢 Pipeline CI/CD & Signature Cryptographique

Le dépôt inclut deux workflows GitHub Actions haute sécurité :

1. **`.github/workflows/build-and-release.yml`** :
   - Déclenché à chaque push sur `main` ou tag `v*.*.*`.
   - Construit les images multi-architectures (`linux/amd64`, `linux/arm64`) via QEMU et Docker Buildx.
   - Analyse chaque conteneur avec **Aqua Security Trivy** et publie le rapport SARIF dans l'onglet **GitHub Code Scanning**.
   - Signe cryptographiquement chaque image et chaque tag sur GHCR via **Cosign** (Sigstore OIDC Keyless).

2. **`.github/workflows/weekly-security-rebuild.yml`** :
   - Déclenché automatiquement chaque dimanche à 04:00 UTC (ou manuellement).
   - Reconstruit l'intégralité des images avec l'option `--no-cache` et `pull: true` pour intégrer immédiatement les correctifs de sécurité des distributions parentes (Debian, Alpine, Temurin).
   - Re-scanne et republie les images à jour avec horodatage pour une traçabilité DevSecOps absolue.

---

## 👥 Auteurs & Licence

- **Équipe Rhino Panel & Rhino Action**
- Licence : **MIT**
- Documentation officielle Rhino : [https://rhino.overnode.fr](https://rhino.overnode.fr)
