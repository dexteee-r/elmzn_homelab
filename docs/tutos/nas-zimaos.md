# 🧩 NAS ZimaOS (Machine #3) — Mise en place pas à pas

> **Ce que tu obtiens :** un NAS domestique sous **ZimaOS** (fork CasaOS) : partages **SMB/NFS** + applications conteneurisées (qBittorrent, Pi-hole…) installées depuis l'app store.

| | |
|---|---|
| 🎯 Résultat | Un NAS avec partages réseau + apps, géré via l'interface web ZimaOS |
| ⏱️ Durée | ⚠️ À VÉRIFIER |
| 📊 Niveau | Débutant / Intermédiaire |
| 🧩 Pré-requis | Une machine dédiée (NVMe pour l'OS + 1 disque data) · une image ZimaOS |
| 🔗 Décisions liées | [ADR-007 — Stratégie de stockage](../ADR/007-strategie-stockage.md) · [ADR-014 — Architecture 2 machines](../ADR/014-architecture-2-machines.md) |

## 🗺️ Ce qu'on construit

ZimaOS est une **appliance** (basée CasaOS) : la plupart des actions passent par son **interface web** et son **app store**, pas par la ligne de commande.

```
Machine #3 — ZimaOS
├─ OS    : nvme0n1 238.5 GB → /DATA (nvme0n1p8, 226.3 GB, ext4)
├─ Média : sda 465.8 GB (btrfs) → /DATA/.media/HDD-500GB
├─ Partages : Samba (SMB) + NFS + ZeroTier
└─ Apps (Docker) : qBittorrent, Home Assistant, Pi-hole, Poste.io
```

## 🚶 Étapes

### Étape 1 — Installer ZimaOS
*Pourquoi :* l'OS appliance qui fournit l'interface web, l'app store et la gestion stockage.

- Flasher l'image **ZimaOS** sur le NVMe de la machine, puis booter dessus. ⚠️ À VÉRIFIER : version exacte de l'image ZimaOS.
- Récupérer l'IP de la machine et ouvrir l'interface web. ⚠️ À VÉRIFIER : IP LAN du NAS.

✅ **Vérifie que :** l'interface web ZimaOS répond et que tu peux te connecter.

### Étape 2 — Préparer le stockage
*Pourquoi :* séparer l'OS (NVMe) du stockage média (HDD).

- Le disque média `sda` (465.8 GB, **btrfs**) est monté sous `/DATA/.media/HDD-500GB`.
- Vérifier/initialiser ce volume via la section **Stockage** de ZimaOS. ⚠️ À VÉRIFIER : étapes GUI exactes selon ta version.

✅ **Vérifie que :** le volume média apparaît monté dans ZimaOS.

### Étape 3 — Installer les applications (app store)
*Pourquoi :* déployer les services conteneurisés sans écrire de `docker-compose` à la main.

Depuis l'**app store** ZimaOS, installer (versions réelles en place) :

| Application | Image | Rôle |
|-------------|-------|------|
| qBittorrent | `ghcr.io/hotio/qbittorrent:release-5.0.4` | Téléchargements |
| Home Assistant | `homeassistant/home-assistant:2025.11` | Domotique 🔄 |
| Pi-hole | `pihole/pihole:2025.11.1` | DNS ad-blocker 🔄 |
| Poste.io | `analogic/poste.io:2.5.11` | Serveur mail `elmzn.be` 🔄 |

> 🔄 = installé, **configuration en cours** (voir « Et après »).

✅ **Vérifie que :** les conteneurs apparaissent `Running` dans ZimaOS.

### Étape 4 — Partages réseau (SMB / NFS / ZeroTier)
*Pourquoi :* exposer le stockage aux autres machines et l'accès distant.

Services système actifs sur ZimaOS :

| Service | Rôle |
|---------|------|
| `smb` / `nmb` / `winbind` | Samba — partage Windows/Mac |
| `nfs-mountd` / `nfs-idmapd` | NFS |
| `zerotier-one` | VPN mesh (accès distant) |
| `rclone` | Sync/backup cloud |

> ℹ️ **Nuance NFS :** les volumes NFS du homelab sont exportés depuis **srv2** (ZFS), pas depuis ZimaOS. ZimaOS expose surtout du **Samba**.

✅ **Vérifie que :** `\\<IP-ZimaOS>` est accessible depuis un PC Windows/Mac (⚠️ À VÉRIFIER : IP).

## 🧰 Exploitation / accès

```bash
# SSH (admin)
ssh admin@<IP-ZimaOS>           # ⚠️ À VÉRIFIER : IP

# Partage Samba depuis Windows/Mac
\\<IP-ZimaOS>
```

## ✅ Test final

Depuis un PC du LAN : monter le partage Samba `\\<IP-ZimaOS>` et y écrire un fichier test → il doit apparaître sur le volume média ZimaOS.

## 🆘 Dépannage

| Symptôme | Cause probable | Fix |
|----------|----------------|-----|
| Partage Samba injoignable | Service `smb` arrêté / IP erronée | Vérifier l'IP, l'état du service dans ZimaOS |
| App `Running` mais inaccessible | Port non publié / config incomplète | Vérifier le mapping de ports dans l'app store |

## ➡️ Et après (config en cours)

- [ ] Configurer **Pi-hole** (DNS + DHCP LAN)
- [ ] Configurer **Home Assistant** (domotique)
- [ ] Configurer **Poste.io** (serveur mail `elmzn.be`)
- [ ] Vérifier les exports **NFS** ZimaOS
- [ ] Configurer **rclone** vers le cloud (Backblaze B2 ?)
- Accès distant déjà possible via le [VPN WireGuard](vpn-wireguard-subnet-router.md).
