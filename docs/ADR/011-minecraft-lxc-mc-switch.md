# ADR 011 — LXC Minecraft avec mc-switch

**Date :** 2026-03-20 (documenté à l'audit)
**Statut :** EN PRODUCTION

---

## Contexte

Besoin d'héberger plusieurs profils Minecraft (modpacks différents) sur la Machine #2
sans multiplier les VMs ou les services systemd. Un seul service doit pouvoir
basculer entre les profils facilement.

## Décision

Utiliser un **LXC Proxmox dédié** (`minecraft-cobblemon`, ID 200) sur M2 avec
l'outil **`mc-switch`** pour gérer plusieurs profils via un symlink unique
(`active-server` → profil choisi).

## Architecture retenue

```
LXC 200 (192.168.1.202)
└─ /home/minecraft/
   ├─ active-server  →  servers/cobbleverse  (symlink)
   └─ servers/
      ├─ cobbleverse/          (Fabric — Cobblemon mod)
      ├─ cobblemon-academy/    (Fabric)
      └─ demon-slayer/         (Forge)

/bin/mc-switch  →  gestion des profils
minecraft.service  →  démarre active-server/start.sh
```

## Avantages

- Un seul service systemd pour N profils
- Changement de profil sans éditer les configs systemd
- Isolation complète dans un LXC (pas d'impact sur vm-intranet)
- 12 GB RAM alloués — suffisant pour un heap Java de 10 GB

## Ressources allouées

| Ressource | Valeur |
|-----------|--------|
| Cores | 4 |
| RAM | 12 GB |
| Swap | 2 GB |
| Disque | 30 GB |
| IP | 192.168.1.202 |

## Conséquences

- Le LXC doit rester allumé 24/7 pour que le serveur soit accessible
- Un seul profil actif à la fois (contrainte de `mc-switch`)
- Les mondes des 3 profils cohabitent sur le même disque 30 GB
- ⚠️ Backup des mondes Minecraft à intégrer dans la stratégie Restic M2 → M1
