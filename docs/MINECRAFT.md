# Serveur Minecraft — LXC minecraft-cobblemon

## Résumé

| Élément | Valeur |
|---------|--------|
| **LXC ID** | 200 |
| **Hostname** | `minecraft-cobblemon` |
| **Proxmox host** | `srv2` (192.168.1.200) |
| **IP** | 192.168.1.202 |
| **RAM allouée** | 12 GB |
| **Disque** | 30 GB (local-lvm) |
| **Cores** | 4 |
| **Swap** | 2 GB |

---

## Profils (`mc-switch`)

Outil de gestion : `/bin/mc-switch`
Répertoire : `/home/minecraft/servers/`
Lien actif : `/home/minecraft/active-server` (symlink vers le profil actif)

| Profil | Modloader | Statut | Jar principal |
|--------|-----------|--------|---------------|
| `cobbleverse` | Fabric | ★ Actif | `fabric-server-launch.jar` |
| `cobblemon-academy` | Fabric | Disponible | `fabric-server-launch.jar` |
| `demon-slayer` | Forge | Disponible | `forge-installer.jar` |

---

## Service systemd

```bash
# Statut
systemctl status minecraft

# Redémarrer
systemctl restart minecraft

# Logs temps réel
journalctl -fu minecraft
```

**Démarrage automatique :** activé (`enabled`)
**JVM args (cobbleverse) :**
```
java -Xms10G -Xmx10G -XX:+UseG1GC -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions \
  -XX:+DisableExplicitGC -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 -jar fabric-server-launch.jar nogui
```

---

## Gestion via mc-switch

```bash
# Lister les profils
mc-switch list

# Statut du serveur actif
mc-switch status

# Changer de profil (arrête le serveur, change le symlink, relance)
mc-switch switch <nom-profil>
```

---

## Accès

```bash
# Depuis srv2 (Proxmox M2)
pct exec 200 -- bash

# SSH direct
ssh root@192.168.1.202

# Console Proxmox
pct console 200
```

---

## Backups

Répertoire backups : `/home/minecraft/backups/`

> ⚠️ À VÉRIFIER : politique de backup Minecraft non auditée. Vérifier si les mondes sont inclus dans le backup Restic M2 → M1.
