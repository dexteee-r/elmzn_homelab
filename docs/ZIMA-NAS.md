# ZimaOS NAS — Machine #3

> NAS domestique basé sur ZimaOS (fork CasaOS), déployé avril 2026.

---

## Matériel

| Composant | Détail |
|-----------|--------|
| OS | ZimaOS (CasaOS-based) |
| Boot/OS | nvme0n1 238.5 GB |
| /DATA | nvme0n1p8 226.3 GB (ext4) |
| Stockage média | sda 465.8 GB (btrfs) → `/DATA/.media/HDD-500GB` |

---

## Services Docker Actifs

| Conteneur | Image | Statut |
|-----------|-------|--------|
| `qbittorrent` | ghcr.io/hotio/qbittorrent:release-5.0.4 | Running |
| `homeassistant` | homeassistant/home-assistant:2025.11 | Running — config en cours |
| `pihole` | pihole/pihole:2025.11.1 | Running — config en cours |
| `big-bear-poste-io` | analogic/poste.io:2.5.11 | Running — config en cours |

---

## Services Système Actifs

| Service | Description |
|---------|-------------|
| `smb` / `nmb` / `winbind` | Samba — partage réseau Windows/Mac |
| `nfs-mountd` / `nfs-idmapd` | NFS — export vers vm-intranet |
| `zerotier-one` | VPN mesh accès distant |
| `rclone` | Sync/backup cloud |
| `icewhale-files` | Gestionnaire de fichiers ZimaOS |
| `zimaos-local-storage` | Gestion stockage ZimaOS |
| `sshd` | Accès SSH (admin@ZimaOS) |

---

## Partage Réseau

- **Samba :** `\\<IP-ZimaOS>` depuis Windows/Mac
- **NFS :** monté sur vm-intranet depuis srv2 ZFS (les volumes NFS sont sur srv2, pas ZimaOS)
- **ZeroTier :** accès distant LAN virtuel

---

## Todo / En cours

- [ ] Configurer Pi-hole (DNS + DHCP LAN)
- [ ] Configurer Home Assistant (domotique)
- [ ] Configurer Poste.io (mail server `elmzn.be`)
- [ ] Vérifier exports NFS ZimaOS
- [ ] Configurer rclone destination cloud (Backblaze B2 ?)
