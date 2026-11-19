# Rhino Image — Now Templates (`rhino-now-v1`)

Ce dossier regroupe les fichiers modèles officiels complets au format d'export natif **`rhino-now-v1`** pour le panel Rhino.

Chaque fichier `.json` contient :
1. **Les métadonnées complètes du Now** (nom, auteur, description, images Docker GHCR, commande de démarrage et d'arrêt, fonctionnalités actives).
2. **Le script d'installation et de préparation autonome (`.sh`) embarqué** dans `install_script`, ainsi que le conteneur (`install_container`) et le point d'entrée (`install_entrypoint`).
3. **L'ensemble des variables d'environnement configurables** avec leurs règles de validation, leurs types de champs et leurs valeurs par défaut.

---

## 📦 Liste des Modèles Inclus (17)

### 🎮 Minecraft & Proxies Java / Bedrock
- [`paper.json`](./paper.json) : PaperMC (Minecraft Java haute performance)
- [`forge.json`](./forge.json) : Minecraft Forge moddé avec installeur headless automatique
- [`vanilla.json`](./vanilla.json) : Serveur Minecraft Vanilla officiel Mojang
- [`bungeecord.json`](./bungeecord.json) : Proxy multi-serveurs BungeeCord
- [`pocketminemp.json`](./pocketminemp.json) : PocketMine-MP pour Minecraft Bedrock (PHP 8.2+)
- [`velocity.json`](./velocity.json) : Proxy moderne Velocity ultra-rapide
- [`sponge.json`](./sponge.json) : SpongeVanilla pour Minecraft Java
- [`fabric.json`](./fabric.json) : Serveur Fabric Loader moderne & léger

### 🕹️ Jeux Vidéo & Serveurs Dédiés (SteamCMD / Runtimes)
- [`ark.json`](./ark.json) : ARK: Survival Evolved (SteamCMD AppID 376030)
- [`tf2.json`](./tf2.json) : Team Fortress 2 Dédié (SteamCMD AppID 232250)
- [`gmod.json`](./gmod.json) : Garry's Mod Dédié (SteamCMD AppID 4020)
- [`cs2.json`](./cs2.json) : Counter-Strike 2 Dédié (SteamCMD AppID 730)
- [`unturned.json`](./unturned.json) : Unturned Dédié (SteamCMD AppID 1110390)
- [`fivem.json`](./fivem.json) : FiveM Server FXServer (CitizenFX)

### ⚡ Runtimes & Applications Web / Bots
- [`nodejs.json`](./nodejs.json) : Node.js (v18, v20, v22, LTS)
- [`python.json`](./python.json) : Python (v3.10, v3.11, v3.12)
- [`bun.json`](./bun.json) : Bun runtime ultra-rapide

---

## 🚀 Importation dans Rhino-panel

Depuis l'interface d'administration du panel :
1. Rendez-vous dans **Administration > Nows**.
2. Cliquez sur **Importer un Now**.
3. Glissez-déposez l'un des fichiers `.json` de ce dossier.
4. Sélectionnez la **Catégorie** de destination (ex: *Jeux Vidéo*, *Travail*, *Bots & Services*).
5. Cliquez sur **Valider l'importation**. Le Now et toutes ses variables et scripts d'installation sont immédiatement prêts à l'emploi.
