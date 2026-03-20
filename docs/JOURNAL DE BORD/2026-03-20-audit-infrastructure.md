# Journal de bord — Audit infrastructure — 2026-03-20

## Objectif

Vérification complète de l'état réel des deux machines physiques
et mise à jour de la documentation du repo `elmzn_homelab`.

---

## Machines auditées

| Machine | Hostname | IP Proxmox | PVE | Kernel |
|---------|----------|-----------|-----|--------|
| M1 (Dell OptiPlex 7040) | `pve` | 192.168.1.100 | 8.4.14 | 6.8.12-16-pve |
| M2 (Custom PC i7-6700) | `srv2` | 192.168.1.200 | 9.1.1 | 6.17.2-2-pve |

---

## Inventaire VMs & LXC

### Machine #1 (pve)

| ID | Type | Nom | IP | RAM | CPU | Disque |
|----|------|-----|----|-----|-----|--------|
| 101 | VM | vm-extranet | 192.168.1.111 | 4 GB | 2 | 20 GB |
| 102 | LXC | lxc-web | 192.168.1.112 | 512 MB | 2 | 8 GB |

ZFS M1 :
- `tank-hdd` : 464 GB (backups / logs / media / photos — 569 MB utilisé)
- `tank-ssd` : 14.5 GB (appdata / postgres — 1 GB utilisé)

### Machine #2 (srv2)

| ID | Type | Nom | IP | RAM | CPU | Disque |
|----|------|-----|----|-----|-----|--------|
| 101 | VM | vm-intranet | 192.168.1.201 | 6 GB | 3 | 40 GB |
| 200 | LXC | minecraft-cobblemon | 192.168.1.202* | 12 GB | 4 | 30 GB |

*IP changée de 192.168.1.102 → 192.168.1.202 lors de cette session.

ZFS M2 :
- `data-pool` : 3.62 TB (photos 9.57 GB utilisé, fichiers/backups/media vides)

---

## Services Docker

### vm-intranet (192.168.1.201)

| Conteneur | Image | Ports |
|-----------|-------|-------|
| npm | nginx-proxy-manager:2 | 80, 81, 443 |
| immich_server | immich-server:release | 2283 |
| immich_redis | redis:6.2-alpine | — |
| immich_postgres | pgvecto-rs:pg14-v0.2.0 | — |
| immich_machine_learning | immich-machine-learning:release | — |
| prometheus | prometheus:latest | 9090 |
| grafana | grafana:latest | 3000 |
| node_exporter | node-exporter:latest | 9100 |

### vm-extranet (192.168.1.111)

| Conteneur | Image | Ports |
|-----------|-------|-------|
| npm | nginx-proxy-manager:latest | 80, 81, 443 |

---

## Alertes identifiées

| Alerte | Priorité | Action |
|--------|----------|--------|
| OpenVPN inactif sur vm-extranet | HAUTE | Vérifier config + relancer |
| ddclient inactif sur vm-extranet | HAUTE | Risque perte accès externe si IP WAN change |
| UFW absent sur VMs | MOYENNE | Décider si nécessaire ou remplacé par Proxmox FW |
| Nextcloud non déployé | BASSE | Mentionné dans doc comme futur |
| Backup Minecraft non vérifié | MOYENNE | Intégrer mondes Minecraft dans Restic |
| npm:latest sur M1 | BASSE | Épingler la version (`:2`) comme sur M2 |

---

## Changements apportés au repo

- `README.md` : IPs corrigées, M1 host IP ajouté, LXC documentés, ZFS M1 ajouté, services corrigés, alertes UFW/OpenVPN
- `CHANGELOG.md` : entrée `[Unreleased]` ajoutée avec tous les écarts
- `docs/MINECRAFT.md` : créé — documentation LXC minecraft-cobblemon
- `docs/ADR/011-minecraft-lxc-mc-switch.md` : créé — décision architecture Minecraft

---

## Prochaines actions recommandées

1. **Relancer OpenVPN** sur vm-extranet et investiguer pourquoi il est inactif
2. **Relancer ddclient** et vérifier la config DDNS elmzn.be
3. **Changer l'IP du LXC Minecraft** : 192.168.1.102 → 192.168.1.202 (commandes préparées)
4. **Vérifier backup Minecraft** : inclure `/home/minecraft/servers/` dans Restic
5. **Évaluer UFW** : nécessaire ou Proxmox FW suffit ?
