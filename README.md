# 🏠 Media Server Home - Infrastructure Homelab

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE_9.1-orange)](https://www.proxmox.com/)
[![Debian](https://img.shields.io/badge/Debian-13_Trixie-red)](https://www.debian.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)

> **Infrastructure de production 24/7** pour auto-hébergement de services familiaux et laboratoire d'apprentissage système/réseau.

---

## 🚀 Commence ici

Tu veux **reproduire** ce homelab ? Suis les **tutos pas à pas** :

> 👉 **[docs/tutos/](docs/tutos/README.md)** — guides reproductibles (le *comment*)

| Tuto | Ce que tu obtiens |
|------|-------------------|
| [VPN WireGuard (subnet-router)](docs/tutos/vpn-wireguard-subnet-router.md) | Accès à tout le LAN homelab depuis l'extérieur |

Le **pourquoi** des choix d'architecture → [docs/ADR/](docs/ADR/). Ce README = la **vue d'ensemble**.

---

## 📊 Vue d'Ensemble

**Type :** Homelab 3 machines (EXTRANET / INTRANET / NAS ZimaOS)  
**Objectif :** Stockage photos/fichiers famille + VMs laboratoire + apprentissage DevOps  
**Stack :** Proxmox VE + Debian + Docker Compose + ZFS + ZimaOS  
**Sécurité :** Architecture DMZ multi-couches

### 🎯 Cas d'Usage Principaux

- ✅ **Stockage photos famille** (Immich) - 2 TB disponible
- ✅ **Partage fichiers** (Nextcloud - non déployé, prévu)
- ✅ **VMs laboratoire** (Debian test) - apprentissage
- ✅ **Monitoring** (Prometheus + Grafana)
- ⚠️ **Accès distant** (OpenVPN - inactif)
- ✅ **Reverse proxy SSL** (Nginx Proxy Manager)
- ✅ **Hébergement web** (lxc-web — portail homelab `elmzn.be` (LAN only) + portfolio Next.js `portfolio.elmzn.be`)
- ✅ **Web app auto-hébergée** (`watchlist.elmzn.be` — *Series Tracker* : React/Vite + FastAPI + PostgreSQL, auto-déployée via runner GitHub Actions)
- ✅ **Serveur Minecraft** (LXC minecraft-cobblemon, 3 profils)
- ✅ **NAS domestique** (ZimaOS — SMB, NFS, rclone, ZeroTier)
- 🔄 **Domotique** (Home Assistant — installé, config en cours)
- 🔄 **DNS ad-blocker** (Pi-hole — installé, config en cours)
- 🔄 **Mail server** (Poste.io — installé, config en cours)
- 🔄 **Gestionnaire mots de passe** (Vaultwarden — LXC créé, config en cours)

---

## 🗺️ Architecture

### **Vue d'Ensemble**
```
Internet (WAN)
    ↓
Box Internet (192.168.1.1)
├─ Port forwarding :
│  ├─ 80/443 → Machine #1 (vm-extranet)
│  └─ 1194/udp → Machine #1 (OpenVPN — inactif)
│
└─ LAN (192.168.1.0/24)
   │
   ├─ Machine #1 : EXTRANET (DMZ) — Beelink S12, PVE 9.1
   │  ├─ Proxmox host        : 192.168.1.100
   │  ├─ VM-EXTRANET (101)   : 192.168.1.111
   │  │   └─ Services : NPM, UFW, fail2ban
   │  ├─ LXC lxc-web (102)   : 192.168.1.112
   │  │   ├─ elmzn.be (portail homelab statique — accès LAN uniquement)
   │  │   └─ portfolio.elmzn.be (Next.js SSR — PM2 :3001)
   │  ├─ LXC watchlist (105) : 192.168.1.115
   │  │   └─ watchlist.elmzn.be (Series Tracker — Docker : nginx+SPA / FastAPI / PostgreSQL)
   │  └─ LXC vaultwarden (100): en cours de config
   │
   ├─ Machine #2 : INTRANET (Privé) — Custom PC i7-6700, PVE 9.1.1
   │  ├─ Proxmox host        : 192.168.1.200
   │  ├─ VM-INTRANET (101)   : 192.168.1.201
   │  │   └─ Services : NPM, Immich, Grafana, Prometheus, node_exporter
   │  └─ LXC minecraft-cobblemon (200) : 192.168.1.202
   │      └─ Serveurs : cobbleverse★ (Fabric), cobblemon-academy (Fabric), demon-slayer (Forge)
   │
   └─ Machine #3 : NAS — ZimaOS (ZIMA-CUBE ou similaire)
      └─ Services : NFS, Samba, ZeroTier, rclone, qBittorrent
          + En config : Home Assistant, Pi-hole, Poste.io
```

**Principe :** Machine #2 **JAMAIS** exposée directement à Internet.

---

## 🖥️ Matériel

### **Machine #1 : EXTRANET (Beelink S12)**

| Composant | Specs |
|-----------|-------|
| **CPU** | Intel N95 (Alder Lake, 12e gen) |
| **RAM** | 16 GB DDR4 |
| **SSD** | 512 GB (Proxmox + VMs) |
| **Réseau** | 2.5 Gigabit Ethernet |
| **PVE** | 9.1 |

### **Machine #2 : INTRANET (Custom Build)**

| Composant | Specs |
|-----------|-------|
| **CPU** | Intel Core i7-6700 (4C/**8T** @ 3.4-4.0 GHz) |
| **RAM** | 16 GB DDR4-2133 (15 GB vus par PVE) |
| **SSD** | Crucial MX500 447 GB (Proxmox + VMs) |
| **HDD** | Seagate IronWolf 4 TB NAS (stockage ZFS) |
| **GPU** | NVIDIA GeForce GTX 980 (4 GB GDDR5) |
| **Réseau** | Gigabit Ethernet |
| **Alim** | 850W |
| **PVE** | 9.1.1 (kernel 6.17.2-2-pve) |

---

## 🐳 Services Déployés

### **Machine #2 : INTRANET (Production)**

| Service | URL / Port | Description |
|---------|-----------|-------------|
| **Immich** | https://immich.intranet.elmzn.be | Gestion photos famille (2 TB) |
| **Nginx Proxy Manager** | :81 | Reverse proxy local + SSL |
| **Grafana** | :3000 | Dashboards monitoring |
| **Prometheus** | :9090 | Collecte métriques |
| **PostgreSQL** | :5432 (interne) | Base de données Immich (pgvecto-rs:pg14) |
| **Redis** | :6379 (interne) | Cache Immich (redis:6.2-alpine) |
| **Node Exporter** | :9100 | Métriques système |

### **Machine #1 : EXTRANET**

| Service | Port | Description |
|---------|------|-------------|
| **Nginx Proxy Manager** | 80, 81, 443 | Reverse proxy public + SSL |
| **UFW** | — | Firewall actif (SSH LAN only, HTTP/HTTPS open) |
| **fail2ban** | — | Protection bruteforce (SSH + Nginx) |
| **lxc-web — elmzn.be** | 80 | Portail homelab statique — LAN only (Access List NPM), déploiement par `git push` (bare repo + hook post-receive) |
| **lxc-web — portfolio.elmzn.be** | 3001 (PM2) | Portfolio Next.js SSR (standalone) ✅ |
| **watchlist.elmzn.be** | 80 (LXC 105) | *Series Tracker* — web app Docker (nginx+React / FastAPI / PostgreSQL), auto-deploy GitHub Actions ✅ |
| **Vaultwarden** | — | 🔄 LXC créé, configuration en cours |
| **OpenVPN** | — | ⚠️ Inactif |
| **ddclient** | — | ⚠️ Inactif |

### **Machine #3 : NAS ZimaOS**

| Service | Port | Description |
|---------|------|-------------|
| **NFS** | 2049 | Export volumes vers vm-intranet |
| **Samba** | 445 | Partage réseau Windows/Mac |
| **ZeroTier** | — | VPN mesh pour accès distant |
| **rclone** | — | Sync/backup cloud |
| **qBittorrent** | — | Téléchargements (ghcr.io/hotio) |
| **Home Assistant** | — | 🔄 Installé, config en cours |
| **Pi-hole** | — | 🔄 Installé, config en cours |
| **Poste.io** | — | 🔄 Mail server, config en cours |

### **LXC Minecraft (Machine #2)**

| Service | IP | Description |
|---------|-----|-------------|
| **minecraft-cobblemon** | 192.168.1.202:25565 | Serveur Minecraft (Fabric/Forge) |

Profils gérés par `mc-switch` :

| Profil | Modloader | Statut |
|--------|-----------|--------|
| `cobbleverse` | Fabric | ★ Actif |
| `cobblemon-academy` | Fabric | Disponible |
| `demon-slayer` | Forge | Disponible |

### **Stockage ZFS — Machine #2 (4 TB HDD)**

| Dataset | Quota | Utilisé | Mountpoint |
|---------|-------|---------|------------|
| `data-pool/photos` | ~2 TB | 9.6 GB | `/mnt/data-pool/photos` (NFS → vmIntranet) |
| `data-pool/files` | 512 GB | 0 | `/mnt/data-pool/files` (NFS → vmIntranet) |
| `data-pool/backups` | 512 GB | 0 | `/mnt/data-pool/backups` (NFS → vmIntranet) |
| `data-pool/media` | 512 GB | 0 | `/mnt/data-pool/media` (NFS → vmIntranet) |

### **Stockage ZimaOS (Machine #3)**

| Disque | Taille | FS | Rôle |
|--------|--------|----|------|
| nvme0n1 | 238.5 GB | ext4 | OS ZimaOS + /DATA (226 GB) |
| sda (HDD) | 465.8 GB | btrfs | `/DATA/.media/HDD-500GB` |

**Partage réseau depuis ZimaOS :**
- **NFS / Samba :** Accessible depuis LAN (192.168.1.0/24)
- **ZeroTier :** Accès distant VPN mesh

---

## 🚀 Quick Start

### **Prérequis**

- Proxmox VE 9.1 installé sur Machine #2
- Docker + Docker Compose installés
- Domaine public avec DNS dynamique (ex: `elmzn.be` via OVH)
- Accès SSH aux machines

### **Installation Machine #2 (INTRANET)**

#### **1. Préparer l'environnement**
```bash
# SSH vers VM-INTRANET
ssh admin@192.168.1.201

# Créer structure
sudo mkdir -p /srv/intranet
cd /srv/intranet
```

#### **2. Télécharger configuration**
```bash
# Cloner le repo
git clone https://github.com/TON_USER/media-server-home.git
cd media-server-home

# Copier docker-compose.yml
cp configs/machine2-intranet/docker-compose.yml /srv/intranet/
cp configs/machine2-intranet/.env.example /srv/intranet/.env
```

#### **3. Configurer variables d'environnement**
```bash
# Éditer .env
nano /srv/intranet/.env

# Générer passwords forts
openssl rand -base64 32  # Pour DB_PASSWORD
openssl rand -base64 32  # Pour GRAFANA_PASSWORD
```

**Contenu `.env` minimal:**
```bash
DB_PASSWORD=ton_password_postgres_32_chars
GRAFANA_PASSWORD=ton_password_grafana_32_chars
```

#### **4. Monter NFS depuis Proxmox host**
```bash
# Créer points de montage
sudo mkdir -p /mnt/{photos,files,backups,media}

# Ajouter à /etc/fstab
sudo nano /etc/fstab

# Ajouter ces lignes:
192.168.1.200:/mnt/data-pool/photos  /mnt/photos  nfs defaults 0 0
192.168.1.200:/mnt/data-pool/files   /mnt/files   nfs defaults 0 0
192.168.1.200:/mnt/data-pool/backups /mnt/backups nfs defaults 0 0
192.168.1.200:/mnt/data-pool/media   /mnt/media   nfs defaults 0 0

# Monter tous
sudo mount -a

# Vérifier
df -h | grep nfs
```

#### **5. Lancer la stack Docker**
```bash
cd /srv/intranet
docker compose up -d

# Attendre 30 secondes
sleep 30

# Vérifier statut
docker compose ps
```

**Tous les containers doivent être `Up` et `healthy`.**

#### **6. Accéder aux services**

**Première connexion NPM:**
```
URL: http://192.168.1.201:81
Email: admin@example.com
Password: changeme

⚠️ CHANGER IMMÉDIATEMENT email + password
```

**Configurer certificat SSL:**
1. NPM → **SSL Certificates**
2. **Add SSL Certificate** → **Let's Encrypt**
3. **Domain Names:** `*.intranet.elmzn.be`
4. **Use DNS Challenge:** ✅ OVH
5. **Credentials:** (API keys OVH)
6. **Save**

**Créer Proxy Hosts:**
1. NPM → **Hosts** → **Add Proxy Host**
2. **Domain:** `immich.intranet.elmzn.be`
3. **Forward Hostname:** `immich_server`
4. **Forward Port:** `2283`
5. **SSL Certificate:** `*.intranet.elmzn.be`
6. **Force SSL:** ✅
7. **Websockets Support:** ✅ (CRITIQUE)
8. **Save**

Répéter pour:
- `npm.intranet.elmzn.be` → `npm:81`
- `grafana.intranet.elmzn.be` → `grafana:3000`
- `prometheus.intranet.elmzn.be` → `prometheus:9090`

#### **7. Configurer Immich**
```
URL: https://immich.intranet.elmzn.be
```

1. **Getting Started** → Créer compte admin
2. **Username:** ton_username
3. **Password:** (fort + noter dans gestionnaire mots de passe)
4. **Confirm Password**
5. **Sign Up**

**Upload photos:**
1. **Upload** (bouton `+`)
2. Sélectionner photos
3. Photos stockées dans `/mnt/photos` (ZFS)

---

## 📖 Documentation Complète

### **Guides d'Installation**

- 🚀 [**SETUP-MACHINE1.md**](docs/SETUP-MACHINE1.md) - Configuration EXTRANET (à venir)
- 🚀 [**SETUP-MACHINE2.md**](docs/SETUP-MACHINE2.md) - Configuration INTRANET détaillée
- 🚀 [**INSTALL-M2-COMPLETE.md**](docs/INSTALL-M2-COMPLETE.md) - Setup complet M2

### **Documentation Technique**

- 📁 [**ARCHITECTURE.md**](docs/ARCHITECTURE.md) - Architecture détaillée
- 🔒 [**SECURITY.md**](docs/SECURITY.md) - Politique sécurité
- 📊 [**OPERATIONS.md**](docs/OPERATIONS.md) - Runbooks maintenance
- 📝 [**ADR/**](docs/ADR/) - Architecture Decision Records

### **Journal de Bord**

- 📓 [**Setup Homelab Machine #2**](docs/JOURNAL%20DE%20BORD/Setup-Homelab-Machine-#2.md) - Historique setup détaillé (02-04 déc 2025)

---

## 🔧 Opérations Courantes

### **Gestion Services Docker**
```bash
# Démarrer stack
cd /srv/intranet
docker compose up -d

# Arrêter stack
docker compose down

# Voir logs
docker compose logs -f immich_server
docker compose logs -f grafana

# Redémarrer service
docker compose restart immich_server

# Voir statut
docker compose ps
```

### **Gestion VMs & LXC Proxmox**
```bash
# SSH vers Proxmox M2
ssh root@192.168.1.200   # srv2

# Lister VMs et LXC
qm list && pct list

# VM-INTRANET (101)
qm start 101
qm stop 101
qm status 101

# LXC minecraft-cobblemon (200)
pct start 200
pct stop 200
pct exec 200 -- mc-switch list

# SSH vers Proxmox M1
ssh root@192.168.1.100   # pve

# LXC lxc-web (102) sur M1
pct start 102
pct stop 102
```

### **Gestion ZFS**
```bash
# Statut pool
zpool status data-pool

# Liste datasets
zfs list

# Quotas
zfs get quota data-pool/photos

# Créer snapshot manuel
zfs snapshot data-pool/photos@backup-$(date +%Y%m%d)

# Lister snapshots
zfs list -t snapshot
```

### **Backups**
```bash
# Backup manuel M2 → M1
./scripts/backup-m2-to-m1.sh

# Restaurer (exemple)
restic restore latest --target /restore --tag photos
```

---

## 🔒 Sécurité

### **Architecture Defense in Depth**

1. **Box Firewall** - Ports 80/443 UNIQUEMENT vers Machine #1
2. **UFW** - SSH LAN only, HTTP/HTTPS ouvert, tout le reste bloqué (vm-extranet ✅)
3. **Fail2ban** - SSH ban 24h, Nginx auth/rate-limit ban 1h (vm-extranet ✅)
4. **NPM Access Lists** - Grafana/Prometheus = LAN uniquement ; `elmzn.be` = LAN uniquement (403 pour le public)
5. **Application Auth** - Comptes + passwords forts

> ⚠️ OpenVPN inactif sur M1 — accès VPN non opérationnel

**Principe:** Machine #2 JAMAIS exposée directement Internet.

---

## 💾 Backups

### **Stratégie**

- **Quotidien:** Configs Docker, DB PostgreSQL
- **Hebdomadaire:** Photos Immich (incrémental)
- **Mensuel:** Fichiers complets
- **Rétention:** 7 daily, 4 weekly, 6 monthly

### **Destinations**

- **Local:** Machine #1 (500 GB HDD)
- **Offsite:** À implémenter (Backblaze B2)

---

## 📊 Monitoring

**Accès Grafana:** `https://grafana.intranet.elmzn.be`

**Dashboards:**
- Node Exporter Full (CPU, RAM, Disk, Network)
- Docker Monitoring (Containers)
- Custom (Services uptime)

---

## 📋 État du Projet

### ✅ Complété

- [x] Proxmox M2 installé (VE 9.1)
- [x] ZFS pool 4TB configuré avec quotas
- [x] NFS + Samba opérationnels
- [x] VM-INTRANET Debian 13 déployée
- [x] Stack Docker complète (Immich, NPM, Grafana, Prometheus)
- [x] Certificats SSL Let's Encrypt
- [x] Proxy hosts NPM configurés
- [x] Immich fonctionnel avec uploads
- [x] Migration Machine #1 Dell OptiPlex 7040 → Beelink S12 (2026-03-21)
- [x] UFW + Fail2ban opérationnels sur vm-extranet (2026-03-22)
- [x] Machine #3 ZimaOS déployée — NAS + NFS/Samba/ZeroTier opérationnels (2026-04-22)
- [x] LXC Vaultwarden (100) créé sur pve-extranet (2026-04-22)
- [x] Node.js 20 LTS + PM2 installés sur lxc-web (2026-04-28)
- [x] `portfolio.elmzn.be` déployé en production — Next.js SSR standalone (2026-04-28)
- [x] `watchlist.elmzn.be` déployé — web app *Series Tracker* (Docker, LXC 105 sur pve-extranet) + CI/CD auto-deploy via runner GitHub Actions self-hosted (2026-06-28)
- [x] `elmzn.be` passé en accès LAN uniquement (Access List NPM) et reconverti en **portail homelab** — liens vers tous les services (2026-07-02)
- [x] Déploiement auto du portail par `git push` (repo bare + hook post-receive sur lxc-web) (2026-07-02)
- [x] Pages d'erreur 403/404/5xx communes — snippet nginx sur lxc-web (tous les vhosts) + hook custom NPM (tous les proxy hosts) (2026-07-03)

### 🔄 En Cours

- [ ] Backups automatisés (Restic)
- [ ] Vaultwarden — configuration et mise en production
- [ ] Home Assistant — configuration domotique
- [ ] Pi-hole — configuration DNS ad-blocker
- [ ] Poste.io — configuration mail server

### 📅 Prochaines Étapes

- [ ] Nextcloud déploiement
- [ ] OpenVPN / accès distant
- [ ] Uptime Kuma (monitoring uptime)
- [ ] ddclient DDNS automatisé

---

## 🤝 Contribution

Projet **éducatif** et **personnel**. Suggestions bienvenues via Issues !

---

## 📞 Ressources

### **Documentation Officielle**

- [Proxmox VE](https://pve.proxmox.com/wiki/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Immich](https://immich.app/docs/)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
- [ZFS Documentation](https://openzfs.github.io/openzfs-docs/)

### **Communauté**

- [r/selfhosted](https://reddit.com/r/selfhosted)
- [r/Proxmox](https://reddit.com/r/Proxmox)
- [r/homelab](https://reddit.com/r/homelab)

---

## 📜 License

Projet sous licence **MIT** - voir [LICENSE](LICENSE).

---

## 🙏 Remerciements

- Communauté r/selfhosted pour inspiration
- Projet Immich pour excellent logiciel photos
- Proxmox team pour hyperviseur open-source

---

**Dernière mise à jour:** 3 juillet 2026 (elmzn.be → portail homelab LAN-only, déploiement git push, pages d'erreur communes)
**Version architecture:** 3.1 (3 machines EXTRANET/INTRANET/NAS ZimaOS)

---

<div align="center">
  <b>Made with ❤️ for learning and family</b>
</div>
```

---

## 2️⃣ LICENSE (MIT)

Crée fichier `LICENSE` à la racine:
```
MIT License

Copyright (c) 2025 @dexteee-r

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
