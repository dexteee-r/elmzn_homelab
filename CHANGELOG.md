# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.0.0] - 2026-04-22

### Ajout Machine #3 ZimaOS NAS + LXC Vaultwarden

#### Added
- **Machine #3 ZimaOS** déployée sur LAN (192.168.1.0/24)
  - Stockage : nvme 238.5 GB (OS + /DATA 226 GB) + HDD 465.8 GB (btrfs, /DATA/.media)
  - Services actifs : NFS, Samba, ZeroTier, rclone, qBittorrent
  - Services installés (config en cours) : Home Assistant, Pi-hole, Poste.io
- **LXC 100 `vaultwarden`** créé sur pve-extranet — configuration en cours
- Architecture diagramme mis à jour : 3 machines

#### Changed
- README version 3.0 — 3 machines EXTRANET/INTRANET/NAS
- Section "Stockage ZFS Machine #1" retirée (Beelink S12 = local-lvm uniquement, pas de ZFS)

---

## [Unreleased] - 2026-03-20

### Audit Infrastructure Complet

Vérification de l'état réel de toutes les machines vs documentation.

### Corrections

#### IPs & Réseaux
- M1 Proxmox host confirmé : `192.168.1.100` (hostname `pve`, PVE 8.4.14)
- M2 Proxmox host confirmé : `192.168.1.200` (hostname `srv2`, PVE 9.1.1)
- VM-INTRANET IP réelle : `192.168.1.201` (doc indiquait `192.168.1.101`)
- LXC Minecraft changement d'IP : `192.168.1.102` → `192.168.1.202` (cohérence INTRANET 20x)

#### Services non documentés découverts
- **LXC lxc-web (102)** sur M1 à `192.168.1.112` (non documenté)
- **LXC minecraft-cobblemon (200)** sur M2 : 3 profils via `mc-switch`
  - `cobbleverse` (Fabric, actif — heap 10 GB)
  - `cobblemon-academy` (Fabric)
  - `demon-slayer` (Forge)
- **ZFS M1** : 2 pools — `tank-hdd` (464 GB) + `tank-ssd` (14.5 GB)

#### Alertes ⚠️
- OpenVPN : **inactif** sur vm-extranet
- ddclient : **inactif** sur vm-extranet
- UFW : **absent** sur vm-extranet et vm-intranet
- Nextcloud : **non déployé** (mentionné dans doc comme prévu)

---

## [2.0.0] - 2025-11-28

### 🎯 **MAJOR RELEASE: Architecture 2 Machines**

Complete infrastructure redesign with physical separation EXTRANET/INTRANET.

### Added

#### Architecture
- **Machine #1 (EXTRANET):** Dell OptiPlex 7040 as DMZ node
  - Nginx Proxy Manager (reverse proxy + Let's Encrypt)
  - OpenVPN Access Server (remote access)
  - ddclient (dynamic DNS for elmzn.be)
  - Fail2ban (bruteforce protection)
  - Uptime Kuma (uptime monitoring)
  
- **Machine #2 (INTRANET):** Custom PC as storage + compute node
  - Immich (4TB photo storage)
  - Nextcloud (file sharing + sync)
  - PostgreSQL 16 (database)
  - Redis 7 (cache)
  - Prometheus + Grafana (monitoring)
  - VM-DEV-LINUX (Ubuntu/Debian lab)
  - VM-DEV-WINDOWS (Windows 10/11 lab)

#### Documentation
- `docs/ADR/011-architecture-2-machines.md` - Architecture decision record
- `docs/ADR/012-separation-extranet-intranet.md` - Security separation rationale
- `README.md` - Complete rewrite for dual-machine setup
- `docs/SETUP-MACHINE1.md` - Machine #1 installation guide
- `docs/SETUP-MACHINE2.md` - Machine #2 installation guide
- `docs/MIGRATION-GUIDE.md` - Migration from 1 to 2 machines

#### Configuration
- `configs/machine1-extranet/docker-compose.yml` - EXTRANET services stack
- `configs/machine2-intranet/docker-compose.yml` - INTRANET services stack
- `.env.example` - Environment variables template

#### Scripts
- `scripts/backup-m2-to-m1.sh` - Automated Restic backup (M2 → M1)
- `scripts/setup-machine1.sh` - Machine #1 automated setup
- `scripts/setup-machine2.sh` - Machine #2 automated setup

#### Security
- Defense in Depth: 6-layer security model
  1. ISP router firewall
  2. Proxmox datacenter firewall
  3. UFW on Machine #1 (public ports only)
  4. UFW on Machine #2 (LAN + M1 only)
  5. Fail2ban (auto-ban bruteforce)
  6. Application-level authentication

### Changed

#### Breaking Changes
- **IP Addressing:**
  - Machine #1 (EXTRANET): `192.168.1.111` (was `192.168.1.100`)
  - Machine #2 (INTRANET): `192.168.1.101` (new)
  - Proxmox host no longer exposed on `.100`

- **Service Architecture:**
  - Services now split across 2 physical machines
  - Machine #2 NEVER exposed directly to Internet
  - All external access via reverse proxy (M1) or VPN

- **Storage:**
  - Media/photos now on Machine #2 (4TB HDD ZFS)
  - Backups now M2 → M1 (was local only)

#### Performance
- CPU allocation optimized:
  - Machine #1: i5-6500 (4T) dedicated reverse proxy
  - Machine #2: i7-6700 (8T) for apps + VMs
- RAM allocation:
  - Machine #1: 6 GB for EXTRANET VM
  - Machine #2: 16 GB (6 GB INTRANET + 8 GB VMs lab)

### Removed

- Single-machine architecture (deprecated)
- Traefik reverse proxy (replaced by Nginx Proxy Manager)
- Jellyfin streaming (postponed to future release)
- Local media on Machine #1 (migrated to Machine #2)

### Fixed

- Security: Eliminated direct Internet exposure of application services
- Performance: Reduced CPU contention (separated workloads)
- Scalability: Infrastructure ready for future expansion

### Security

- **CVE Mitigations:**
  - No services directly exposed to Internet (except reverse proxy)
  - Fail2ban active on all public ports
  - VPN required for admin access (Proxmox, Grafana)
  
- **Hardening:**
  - UFW restrictive rules on both machines
  - SSH key-only authentication (passwords disabled)
  - Automated security updates enabled
  - Regular backup testing (quarterly)

---

## [1.2.0] - 2025-11-03

### Added
- Grafana monitoring dashboards
- Prometheus metrics collection
- Node exporter on both VMs
- Restic backups with retention policy

### Fixed
- Immich connectivity issues (UFW blocking PostgreSQL)
- Prometheus storage permissions
- Grafana admin password configuration

### Changed
- Upgraded to Proxmox VE 8.4
- Migrated VMs to Debian 13 (Trixie)

---

## [1.1.0] - 2025-10-15

### Added
- OpenVPN Access Server for remote access
- Dynamic DNS with ddclient (OVH)
- SSL certificates via Let's Encrypt
- Nginx Proxy Manager dashboards

### Changed
- Reverse proxy: Traefik → Nginx Proxy Manager
- Simplified certificate management

---

## [1.0.0] - 2025-10-01

### Added

#### Infrastructure
- Proxmox VE 8.2 on Dell OptiPlex 7040
- ZFS storage (tank-ssd 15GB + tank-hdd 450GB)
- VM-EXTRANET (Debian 13): Nginx NPM, OpenVPN
- VM-INTRANET (Debian 13): Jellyfin, Immich, PostgreSQL

#### Services
- Jellyfin media server (QuickSync transcoding)
- Immich photo management
- PostgreSQL 16 database
- Redis cache

#### Documentation
- Initial README
- Architecture decision records (ADR 001-010)
- Setup guides
- Operations cheatsheet

#### Configuration
- Docker Compose stacks
- UFW firewall rules
- ZFS snapshots automation

---

## [Unreleased] - Future Roadmap

### Planned for v2.1.0
- [ ] Cloudflare Tunnel integration (alternative to OpenVPN)
- [ ] Automated testing pipeline (smoke tests)
- [ ] Enhanced monitoring (Loki + Tempo)
- [ ] Backup offsite (Backblaze B2)

### Planned for v2.2.0
- [ ] Jellyfin streaming re-enabled (GPU transcoding GTX 980)
- [ ] Vaultwarden password manager
- [ ] Homepage dashboard (unified UI)
- [ ] Mobile app notifications (ntfy.sh)

### Planned for v3.0.0 (Long-term)
- [ ] 3-node Proxmox cluster (HA)
- [ ] Kubernetes (k3s) migration
- [ ] CI/CD pipeline (GitLab Runner)
- [ ] Object storage (MinIO)

---

## Version Naming Convention

- **Major (X.0.0):** Breaking changes, architecture redesign
- **Minor (x.X.0):** New features, service additions
- **Patch (x.x.X):** Bug fixes, minor improvements

---

## Links

- [GitHub Repository](https://github.com/TON_USER/media-server-home)
- [Documentation](docs/)
- [ADRs](docs/ADR/)
- [Issues](https://github.com/TON_USER/media-server-home/issues)

---

**Legend:**
- 🎯 Major feature
- ⚡ Performance improvement
- 🐛 Bug fix
- 🔒 Security enhancement
- 📝 Documentation
- ⚠️ Deprecation warning
- 💥 Breaking change
