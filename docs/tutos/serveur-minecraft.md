# 🧩 Serveur Minecraft multi-profils (mc-switch) — Mise en place pas à pas

> **Ce que tu obtiens :** un serveur Minecraft dans un LXC dédié, capable de **basculer entre plusieurs modpacks** (Fabric/Forge) avec une seule commande `mc-switch`.

| | |
|---|---|
| 🎯 Résultat | Un serveur Minecraft jouable, 3 profils interchangeables, démarrage automatique |
| ⏱️ Durée | ⚠️ À VÉRIFIER |
| 📊 Niveau | Intermédiaire |
| 🧩 Pré-requis | Hôte Proxmox avec **~12 GB RAM libre** · un template LXC Debian |
| 🔗 Décisions liées | [ADR-011 — LXC Minecraft + mc-switch](../ADR/011-minecraft-lxc-mc-switch.md) · [ADR-002 — Docker vs LXC](../ADR/002-docker-vs-lxc.md) |

## 🗺️ Ce qu'on construit

Un **LXC** sur l'hôte `srv2` fait tourner Java + le serveur Minecraft. Un script maison **`mc-switch`** gère plusieurs **profils** (un modpack = un dossier) et bascule le serveur actif via un **symlink**, le tout lancé par un **service systemd**.

```
srv2 (192.168.1.200)
└─ LXC 200 « minecraft-cobblemon » (192.168.1.202)
   ├─ /home/minecraft/servers/<profil>/   ← un dossier par modpack
   ├─ /home/minecraft/active-server       ← symlink vers le profil actif
   ├─ /bin/mc-switch                       ← bascule de profil
   └─ systemd: minecraft.service           ← démarrage auto
```

**Profils en place :**

| Profil | Modloader | Statut | Jar principal |
|--------|-----------|--------|---------------|
| `cobbleverse` | Fabric | ★ Actif | `fabric-server-launch.jar` |
| `cobblemon-academy` | Fabric | Disponible | `fabric-server-launch.jar` |
| `demon-slayer` | Forge | Disponible | `forge-installer.jar` |

## 🚶 Étapes

### Étape 1 — Créer le LXC
*Pourquoi :* isoler le serveur de jeu dans son propre conteneur, avec assez de RAM/CPU.

Crée un LXC avec cette config (la méthode `pct create` détaillée est dans le [tuto WireGuard, Étape 1](vpn-wireguard-subnet-router.md#-étape-1--créer-le-lxc-wireguard)) :

| Paramètre | Valeur |
|-----------|--------|
| VMID | `200` |
| Hostname | `minecraft-cobblemon` |
| Hôte Proxmox | `srv2` (192.168.1.200) |
| IP | `192.168.1.202/24`, gw `192.168.1.1` |
| RAM / Swap | 12 GB / 2 GB |
| Cores | 4 |
| Disque | 30 GB (local-lvm) |

⚠️ À VÉRIFIER : nom exact du template Debian utilisé, et privilégié vs non-privilégié.

✅ **Vérifie que :** `pct status 200` renvoie `running` et que le conteneur a accès à Internet.

### Étape 2 — Java + arborescence des profils
*Pourquoi :* le serveur tourne sur la JVM ; `mc-switch` s'appuie sur une arborescence fixe.

Dans le conteneur (`pct exec 200 -- bash`) :
- Installer un JDK compatible avec tes modpacks. ⚠️ À VÉRIFIER : version exacte de Java.
- Créer l'arborescence :
  ```bash
  mkdir -p /home/minecraft/servers /home/minecraft/backups
  # un dossier par profil, ex. :
  # /home/minecraft/servers/cobbleverse/
  # /home/minecraft/servers/cobblemon-academy/
  # /home/minecraft/servers/demon-slayer/
  ```
- Y déposer le serveur de chaque modpack (Fabric : `fabric-server-launch.jar` ; Forge : `forge-installer.jar`). ⚠️ À VÉRIFIER : sources/versions des modpacks.

> Le script **`mc-switch`** (`/bin/mc-switch`) est **maison** : son fonctionnement est décrit dans [ADR-011](../ADR/011-minecraft-lxc-mc-switch.md). ⚠️ Le contenu du script n'est pas versionné dans ce repo → à ajouter dans `scripts/` pour une repro complète.

✅ **Vérifie que :** `mc-switch list` affiche bien tes profils.

### Étape 3 — Service systemd
*Pourquoi :* démarrage automatique + gestion propre (start/stop/logs).

Le service `minecraft.service` lance le profil actif avec ces arguments JVM (profil `cobbleverse`) :

```bash
java -Xms10G -Xmx10G -XX:+UseG1GC -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions \
  -XX:+DisableExplicitGC -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 -jar fabric-server-launch.jar nogui
```

⚠️ À VÉRIFIER : contenu exact de l'unité `minecraft.service` (chemin, user, WorkingDirectory) → à versionner dans `scripts/`.

✅ **Vérifie que :** `systemctl is-enabled minecraft` renvoie `enabled` (démarrage auto).

## 🧰 Exploitation au quotidien

```bash
# Profils & serveur actif
mc-switch list
mc-switch status
mc-switch switch <nom-profil>     # arrête, change le symlink, relance

# Service
systemctl status minecraft
systemctl restart minecraft
journalctl -fu minecraft          # logs temps réel

# Accès au conteneur
pct exec 200 -- bash              # depuis srv2
ssh root@192.168.1.202            # SSH direct
```

## ✅ Test final

Depuis un client Minecraft, connecte-toi au serveur : `192.168.1.202:25565` (⚠️ À VÉRIFIER : port si modifié). Le monde du profil actif doit charger.

## 🆘 Dépannage

| Symptôme | Cause probable | Fix |
|----------|----------------|-----|
| Le serveur ne démarre pas | Mauvais profil actif / jar manquant | `mc-switch status`, vérifier le symlink `active-server` |
| `OutOfMemoryError` | Heap trop petit vs modpack | Ajuster `-Xmx` dans l'unité systemd |
| Mondes non sauvegardés | ⚠️ Politique de backup non auditée | Inclure `/home/minecraft/servers/` dans le backup Restic M2 → M1 |

## ➡️ Et après

- **Versionner** le script `mc-switch` et l'unité `minecraft.service` dans `scripts/` pour une repro complète.
- **Backups** : intégrer les mondes au backup Restic (voir [ADR-005 — Backup strategy](../ADR/005-backup-strategy.md)).
- **Accès distant** : le serveur est déjà joignable via le [VPN WireGuard](vpn-wireguard-subnet-router.md).
