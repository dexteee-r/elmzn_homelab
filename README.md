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
| [Installer Proxmox](docs/tutos/installer-proxmox.md) | Un hyperviseur Proxmox VE prêt à accueillir VM et LXC |
| [Serveur web](docs/tutos/serveur-web.md) | Un site servi en HTTPS derrière Nginx Proxy Manager |
| [VPN WireGuard (subnet-router)](docs/tutos/vpn-wireguard-subnet-router.md) | Accès à tout le LAN homelab depuis l'extérieur |
| [NAS ZimaOS](docs/tutos/nas-zimaos.md) | Un NAS domestique avec partages SMB/NFS |
| [Serveur Minecraft](docs/tutos/serveur-minecraft.md) | Un serveur Minecraft multi-profils en LXC |

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
- ✅ **Accès distant** (VPN WireGuard — subnet-router, LXC 103)
- ✅ **Reverse proxy SSL** (Nginx Proxy Manager)
- ✅ **Hébergement web** (lxc-web — portail homelab `home.elmzn.be` (LAN only) + ancien portfolio Next.js `portfolio.elmzn.be`)
- ✅ **Portfolio personnel** (`elmzn.be` — Next.js/Docker, LXC dédié sur pve-extranet, déploiement par tirage via timer systemd + CMS Sveltia)
- ✅ **Web app auto-hébergée** (`watchlist.elmzn.be` — *Series Tracker* : React/Vite + FastAPI + PostgreSQL, déploiement par tirage conditionné à une CI verte)
- ✅ **Gestionnaire de collection de cartes** (`mytcg.elmzn.be` — *MyTCG* : React + FastAPI + SQLite, stack native, auto-déploiement pull-based)
- ✅ **Page link-in-bio** (`links.elmzn.be` — *linktree-host* : Node.js/Express + SQLite, [repo dédié](https://github.com/dexteee-r/linktree-host), en prod public depuis vm-extranet)
- ⏸️ **Automatisation** (n8n — LXC dédié Docker, arrêté volontairement, inutilisé pour l'instant — configuration conservée pour reprise future)
- ⏸️ **LLM auto-hébergé** (Ollama + qwen2.5:7b — fait partie de la stack n8n, arrêté avec elle)
- ✅ **Serveur Minecraft** (LXC minecraft-cobblemon, 3 profils)
- ✅ **NAS domestique** (ZimaOS — SMB, NFS, rclone, ZeroTier)
- ✅ **Stockage fichiers avec interface web** (`files.elmzn.be` — FileBrowser Quantum, LAN uniquement)
- ✅ **Bibliothèque de connaissances hors ligne** (*Project NOMAD* — Wikipédia, livres, cartes, cours, LXC 202, LAN uniquement) + page de lecture de son dépôt
- ✅ **Monitoring infrastructure** (Checkmk — LXC 108, supervision Proxmox agentless + HTTP/certificats des sites publics ; notifications et agents à venir)
- 🔄 **Domotique** (Home Assistant — installé, config en cours)
- 🔄 **DNS ad-blocker** (Pi-hole — installé, config en cours)
- 🔄 **Mail server** (Poste.io — installé, config en cours)
- ✅ **Gestionnaire mots de passe** (Vaultwarden — `vault.elmzn.be`, LXC 100, inscriptions fermées + 2FA)

---

## 🗺️ Architecture

### **Vue d'Ensemble**
```
Internet (WAN)
    ↓
Box Internet (192.168.1.1)
├─ Port forwarding :
│  ├─ 80/443 → Machine #1 (vm-extranet)
│  └─ 51820/udp → Machine #1 (WireGuard — subnet-router, LXC 103)
│
└─ LAN (192.168.1.0/24)
   │
   ├─ Machine #1 : EXTRANET (DMZ) — Beelink S12, PVE 9.1
   │  ├─ Proxmox host        : 192.168.1.100
   │  ├─ VM-EXTRANET (101)   : 192.168.1.111
   │  │   └─ Services : NPM, UFW, fail2ban
   │  │       └─ linktree-host (Docker, port 3000 interne — `links.elmzn.be` en prod, public)
   │  ├─ LXC lxc-web (102)   : 192.168.1.112
   │  │   ├─ home.elmzn.be (portail homelab statique — accès LAN uniquement)
   │  │   └─ portfolio.elmzn.be (Next.js SSR — PM2 :3001)
   │  ├─ LXC portfolio (104) : 192.168.1.114 — 2 Go RAM, 2 cœurs, 16 Go, Debian 12
   │  │   └─ elmzn.be (portfolio personnel — Next.js/Docker, public, déploiement par tirage (timer systemd) + CMS Sveltia)
   │  ├─ LXC watchlist (105) : 192.168.1.115
   │  │   └─ watchlist.elmzn.be (Series Tracker — Docker : nginx+SPA / FastAPI / PostgreSQL)
   │  ├─ LXC n8n (106)       : 192.168.1.116 — 8 Go RAM, 4 cœurs, 32 Go — ⏸️ ARRÊTÉ (inutilisé, onboot désactivé)
   │  │   ├─ Automatisation self-hosted — Docker, port 5678
   │  │   │   n8n.elmzn.be (éditeur, LAN/VPN) + hooks.elmzn.be (webhooks, public)
   │  │   ├─ media.elmzn.be — fichiers statiques (port 8081, lecture seule)
   │  │   └─ Ollama (qwen2.5:7b) — LLM local CPU, réseau interne Compose, aucun port publié
   │  ├─ LXC mytcg (107)     : 192.168.1.117 — 4 Go RAM, 2 cœurs, 20 Go
   │  │   └─ mytcg.elmzn.be (MyTCG — stack native : Nginx + FastAPI/uvicorn + SQLite)
   │  ├─ LXC monitoring (108): 192.168.1.118 — 4 Go RAM, 2 cœurs, 20 Go
   │  │   └─ Checkmk (natif, OMD) — supervision Proxmox agentless, piggyback des 8 LXC/VM
   │  └─ LXC vaultwarden (100): 192.168.1.119
   │      └─ vault.elmzn.be (Vaultwarden — public, inscriptions fermées)
   │
   ├─ Machine #2 : INTRANET (Privé) — Custom PC i7-6700, PVE 9.1.1
   │  ├─ Proxmox host        : 192.168.1.200
   │  ├─ VM-INTRANET (101)   : 192.168.1.201
   │  │   └─ Services : NPM, Immich, node_exporter
   │  ├─ LXC minecraft-cobblemon (200) : 192.168.1.202
   │  │   └─ Serveurs : cobbleverse★ (Fabric), cobblemon-academy (Fabric), demon-slayer (Forge)
   │  ├─ LXC filestore (201) : 192.168.1.203
   │  │   └─ files.elmzn.be (FileBrowser Quantum — dataset ZFS data-pool/files, LAN uniquement)
   │  └─ LXC nomad (202)     : 192.168.1.204 — 3 Go RAM, 2 cœurs, 16 Go + dataset data-pool/nomad
   │      ├─ nomad.intranet.elmzn.be (Project NOMAD, Docker — Command Center :8080 ; Dozzle :9999 sans proxy)
   │      └─ nomad-docs.intranet.elmzn.be (page de lecture du dépôt, nginx + docsify :80)
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
| **PVE** | 9.1 (noyau 7.0.14-25) |

---

## 🐳 Services Déployés

### **Machine #2 : INTRANET (Production)**

| Service | URL / Port | Description |
|---------|-----------|-------------|
| **Immich** | https://immich.intranet.elmzn.be | Gestion photos famille (2 TB) |
| **Nginx Proxy Manager** | :81 | Reverse proxy local + SSL |
| **PostgreSQL** | :5432 (interne) | Base de données Immich (VectorChord, depuis Immich 3.x) |
| **Redis** | :6379 (interne) | Cache Immich (redis:6.2-alpine) |
| **Node Exporter** | :9100 | Métriques système |
| **files.elmzn.be** | 80 (LXC 201) | *FileBrowser Quantum* — stockage fichiers avec interface web, dataset ZFS `data-pool/files` (512 GB), LAN uniquement (Access List NPM) ✅ |
| **nomad.intranet.elmzn.be** | 8080 (LXC 202) | Serveur de connaissances hors ligne (Kiwix, Kolibri, cartes, notes…) — Docker via l'installeur officiel, contenu sur le dataset ZFS `data-pool/nomad` (quota 200 GB), LAN uniquement, isolé d'Immich ✅ |
| **nomad-docs.intranet.elmzn.be** | 80 (LXC 202) | Page de lecture du dépôt (nginx + docsify : menu, recherche, code source sous `/src/`), `git pull` mensuel + régénération par `project-nomad-pull.timer` ✅ |

### **Machine #1 : EXTRANET**

| Service | Port | Description |
|---------|------|-------------|
| **Nginx Proxy Manager** | 80, 81, 443 | Reverse proxy public + SSL |
| **UFW** | — | Firewall actif (SSH LAN only, HTTP/HTTPS open) |
| **fail2ban** | — | Protection bruteforce (SSH + Nginx) |
| **lxc-web — home.elmzn.be** | 80 | Portail homelab statique — LAN only (Access List NPM), déploiement par `git push` (bare repo + hook post-receive) |
| **lxc-web — portfolio.elmzn.be** | 3001 (PM2) | Ancien portfolio Next.js SSR (standalone) ✅ |
| **elmzn.be** | 3000 (LXC 104) | Portfolio personnel — Next.js/Docker (image `ghcr.io/dexteee-r/portfolio`), public, déploiement par tirage (timer systemd `elmzn-deploy`, toutes les 2 min, aucun runner), CMS Sveltia (OAuth GitHub), `www.elmzn.be` redirige en 301 ✅ |
| **watchlist.elmzn.be** | 80 (LXC 105) | *Series Tracker* — web app Docker (nginx+React / FastAPI / PostgreSQL), déploiement par tirage (`watchlist-autodeploy.timer`, toutes les 3 min, seulement si la CI est verte) ✅ |
| **n8n** — `n8n.elmzn.be` | 5678 (LXC 106) | Automatisation workflows — Docker, éditeur/API restreints LAN/VPN (Access List NPM) — ⏸️ **ARRÊTÉ** (inutilisé pour l'instant, `onboot` désactivé, configuration conservée) |
| **n8n** — `hooks.elmzn.be` | 5678 (LXC 106) | Webhooks n8n uniquement (`/webhook/*`) — public, pour intégrations externes — ⏸️ arrêté avec le reste du LXC |
| **n8n** — `media.elmzn.be` | 8081 (LXC 106) | Fichiers statiques temporaires — lecture seule, purge auto 48h — ⏸️ arrêté avec le reste du LXC |
| **Ollama** | 11434 (interne, LXC 106) | LLM local `qwen2.5:7b` — inférence CPU, joignable uniquement par n8n (réseau Compose), aucun port publié — ⏸️ arrêté avec le reste du LXC |
| **mytcg.elmzn.be** | 80 (LXC 107) | *MyTCG* — gestionnaire de collection de cartes, stack native (Nginx + FastAPI/uvicorn + SQLite), auto-déploiement pull-based toutes les 5 min ✅ — code dans `/opt/mytcg` (aligné sur les autres services, dépôt resynchronisé), cotes EN + JP rafraîchies automatiquement tous les 3 jours |
| **Checkmk** | :80 (LXC 108, IP directe) | Supervision infrastructure — natif (OMD), Special Agent Proxmox VE + 8 hôtes piggyback + HTTP/certificats des sous-domaines publics ✅ — LAN uniquement, pas exposé via NPM |
| **links.elmzn.be** | 3000 (interne, VM-EXTRANET) | *linktree-host* — page link-in-bio auto-hébergée (Node.js/Express + SQLite, stats par événement horodaté, backup CSV quotidien) — ✅ [repo dédié](https://github.com/dexteee-r/linktree-host), en prod, public (pas de LAN-only) |
| **vault.elmzn.be** | LXC 100 | *Vaultwarden* — gestionnaire de mots de passe, public, inscriptions fermées, 2FA, backup vzdump quotidien ✅ |
| **VPN WireGuard** | 51820/udp (LXC 103) | Subnet-router (wg-easy) — accès à tout le LAN depuis l'extérieur ✅ |
| **OpenVPN** | — | ⚠️ Abandonné au profit de WireGuard, jamais installé |
| **ddclient** | — | ✅ DDNS automatisé, actif sur l'hôte `pve-extranet` |

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
| `data-pool/photos` | ~2 TB | ~602 GB | `/mnt/data-pool/photos` (NFS → vmIntranet) |
| `data-pool/files` | 512 GB | ~397 GB | `/mnt/data-pool/files` (NFS → vmIntranet, + FileBrowser Quantum sur LXC 201) |
| `data-pool/backups` | 800 GB | ~640 GB | `/mnt/data-pool/backups` (NFS → vmIntranet) — dépôt Restic d'Immich |
| `data-pool/media` | 512 GB | 0 | `/mnt/data-pool/media` (NFS → vmIntranet) |
| `data-pool/nomad` | 200 GB | ~0 | `/mnt/data-pool/nomad` (monté dans LXC 202 sur `/opt/project-nomad`) — contenu Project NOMAD |

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

> ⚠️ Section générique conservée pour référence. Pour une reproduction fidèle et à jour de l'infrastructure réelle, préférer **[docs/tutos/](docs/tutos/README.md)**. Les fichiers `configs/machine1-extranet/` et `configs/machine2-intranet/` référencés ci-dessous sont des **archives pré-migration** (ancien matériel, mauvaises IP) — voir l'avertissement en tête de ces fichiers.

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
git clone https://github.com/dexteee-r/elmzn_homelab.git
cd elmzn_homelab

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
```

**Contenu `.env` minimal:**
```bash
DB_PASSWORD=ton_password_postgres_32_chars
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

### **Guides d'Installation (à jour)**

- 👉 [**docs/tutos/**](docs/tutos/) - Guides pas à pas reproductibles, alignés sur l'infra réelle : `installer-proxmox.md`, `serveur-web.md`, `vpn-wireguard-subnet-router.md`, `nas-zimaos.md`, `serveur-minecraft.md`
- 📝 [**ADR/**](docs/ADR/) - Architecture Decision Records (le *pourquoi* des choix)

### **Documentation Technique**

- 📄 [**web-server-doc-v2.pdf**](docs/web-server-doc-v2.pdf) - Doc source ayant servi à rédiger `docs/tutos/serveur-web.md`

### **Archives (obsolètes, gardées pour historique — ne pas suivre)**

- ⚠️ [**SETUP-MACHINE1.md**](docs/SETUP-MACHINE1.md) / [**SETUP-MACHINE2.md**](docs/SETUP-MACHINE2.md) - Plans **pré-migration** rédigés avant le passage à l'architecture actuelle (parlent encore de l'ancien Dell OptiPlex comme "Machine #1", d'OpenVPN, de Nextcloud...) — **jamais déployés tels quels**. Le vrai déroulé réel est dans [docs/MIGRATION-M1-vers-nouvelle-machine.md](docs/MIGRATION-M1-vers-nouvelle-machine.md) et dans `docs/tutos/installer-proxmox.md`.

### **Journal de Bord**

- 📓 [**docs/JOURNAL DE BORD/**](docs/JOURNAL%20DE%20BORD/) - Logs de session datés, immuables (ex. [Setup Homelab Machine #2](<docs/JOURNAL DE BORD/Setup Homelab Machine #2.md>), 02-04 déc 2025)

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

# Redémarrer service
docker compose restart immich_server

# Voir statut
docker compose ps
```

### **Gestion VMs & LXC Proxmox**
```bash
# SSH vers Proxmox Machine #2 (INTRANET)
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

# LXC filestore (201)
pct start 201
pct stop 201

# SSH vers Proxmox Machine #1 (EXTRANET)
ssh root@192.168.1.100   # pve-extranet

# LXC lxc-web (102) sur Machine #1
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

1. **Box Firewall** - Ports 80/443 + 51820/udp (WireGuard) UNIQUEMENT, tous vers Machine #1
2. **UFW** - SSH LAN only, HTTP/HTTPS ouvert, tout le reste bloqué (vm-extranet ✅)
3. **Fail2ban** - SSH ban 24h, Nginx auth/rate-limit ban 1h (vm-extranet ✅) ; fail2ban + SSH par clé uniquement sur les hôtes Proxmox, NFS restreint à vm-intranet (2026-10-04)
4. **NPM Access Lists** - `home.elmzn.be`, `files.elmzn.be`, éditeur n8n = LAN uniquement (403 pour le public)
5. **Application Auth** - Comptes + passwords forts

> ✅ VPN WireGuard (subnet-router, LXC 103 sur Machine #1) opérationnel — accès à tout le LAN depuis l'extérieur. OpenVPN a été abandonné et n'a jamais été installé.

**Principe:** Machine #2 JAMAIS exposée directement Internet.

---

## 💾 Backups

### **En place**

- **Machine #1 (Beelink) :** job vzdump hebdomadaire de tous les invités (dimanche 14:00, zstd, mode snapshot) + job quotidien pour Vaultwarden (03:30), sur le disque local
- **Machine #2 (srv2) :** dépôt Restic d'Immich (cron) dans `data-pool/backups` ; **aucun job vzdump** pour vm-intranet et filestore
- **MyTCG :** dump nocturne de la base SQLite (timer `mytcg-backup`)
- **Hors site / cloud :** aucun (choix assumé, pas de cloud)

> ⚠️ **Limite connue (2026-10-23) :** le dépôt Restic d'Immich est sur le même disque ZFS que les photos. Il protège d'une erreur ou d'un bug applicatif, pas d'une panne de ce disque. Une machine de sauvegarde dédiée (support séparé) est à prévoir ; voir « Prochaines Étapes ». Le LXC Minecraft n'est volontairement pas sauvegardé.

---

## 📊 Monitoring

**Supervision :** Checkmk (LXC 108, `monitoring`). Prometheus et Grafana ont été retirés de vm-intranet le 2026-10-23 (inutilisés).

---

## 📋 État du Projet

### ✅ Complété

- [x] Proxmox M2 installé (VE 9.1)
- [x] ZFS pool 4TB configuré avec quotas
- [x] NFS + Samba opérationnels
- [x] VM-INTRANET Debian 13 déployée
- [x] Stack Docker complète (Immich, NPM ; Grafana et Prometheus retirés le 2026-10-23)
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
- [x] Portail homelab renommé `home.elmzn.be`, `elmzn.be` libéré et réattribué au portfolio personnel — nouveau LXC dédié (104), Next.js/Docker, CI/CD via runner GitHub Actions self-hosted durci (déclenchement restreint au push sur `main` du dépôt d'origine, aucun token, aucun checkout) + CMS Sveltia (OAuth GitHub) (2026-09-30/10-01)
- [x] Déploiement auto du portail par `git push` (repo bare + hook post-receive sur lxc-web) (2026-07-02)
- [x] Pages d'erreur 403/404/5xx communes — snippet nginx sur lxc-web (tous les vhosts) + hook custom NPM (tous les proxy hosts) (2026-07-03)
- [x] n8n déployé — automatisation self-hosted (Docker, LXC 106 sur pve-extranet), accès LAN uniquement (2026-08-05)
- [x] n8n exposé publiquement — `n8n.elmzn.be` (éditeur, LAN/VPN) + `hooks.elmzn.be` (webhooks, public) + `media.elmzn.be` (fichiers statiques, lecture seule, purge 48h) (2026-08-05)
- [x] LLM local Ollama (`qwen2.5:7b`, inférence CPU) ajouté à la stack n8n — réseau interne uniquement, LXC 106 porté à 8 Go / 4 cœurs / 32 Go (2026-08-05)
- [x] `mytcg.elmzn.be` déployé — *MyTCG* (stack native Nginx + FastAPI + SQLite, LXC 107 sur pve-extranet), auto-déploiement pull-based conditionné à la CI + backup nocturne de la base (2026-08-07)
- [x] `files.elmzn.be` déployé — FileBrowser Quantum (natif, LXC 201 sur srv2), dataset ZFS `data-pool/files` réutilisé, migration de 418 Go / 13 862 fichiers terminée (2026-09-12/14)
- [x] `links.elmzn.be` (linktree-host) passé en production complète — DNS OVH + Proxy Host NPM public, page `/stats` refaite, backup CSV quotidien des statistiques (2026-09-19/21)
- [x] n8n arrêté volontairement (inutilisé pour l'instant) — `onboot` désactivé, configuration et données conservées pour reprise future (2026-08-25 / 2026-09-06)
- [x] Durcissement des hôtes Proxmox : fail2ban, SSH par clé, mises à jour + redémarrage (noyau 7.0), NFS restreint, Samba désactivé ; Immich 3.2.4 (2026-10-04)
- [x] Portail `home.elmzn.be` : refonte de l'interface + pastilles d'état en direct (2026-10-05)
- [x] Déploiement du portfolio : runner self-hosted remplacé par un timer systemd `elmzn-deploy` (2026-10-10)
- [x] Déploiement de `watchlist` : runner self-hosted remplacé par un timer systemd (tirage depuis le serveur, conditionné à une CI verte) (2026-10-23)
- [x] Vaultwarden en ligne sur `vault.elmzn.be` (inscriptions fermées, 2FA, backup vzdump quotidien) (2026-10-15)
- [x] Correctifs de sécurité d'octobre : PHP 8.4.27 (Checkmk), Node 22 (linktree-host), Node 24.22.1 (portfolio) (2026-10-22)
- [x] Accès des amis à une salle de jeu multijoueur du LAN via WireGuard, pare-feu par client, sans port ouvert (2026-10-23)
- [x] Checkmk : 8 hôtes piggyback + surveillance HTTP/certificats des sous-domaines publics (2026-10-23)
- [x] Stabilité du Beelink : backup hebdomadaire déplacé au dimanche 14:00, log thermique en place, LXC 102 réparé après un verrou vzdump (2026-10-23)
- [x] Audit de srv2 (2026-10-23) : SSH durci, NFS restreint, ZFS sain ; quota `backups` porté à 800 GB ; dumps `pre-upgrade` de vm-intranet et filestore (supprimés après la mise à jour réussie)
- [x] Project NOMAD déployé sur srv2 — LXC 202 dédié (isolé d'Immich, l'appli a accès au socket Docker), contenu sur `data-pool/nomad`, + page de lecture du dépôt mise à jour chaque mois (2026-10-26)
- [x] `zpool scrub` de `data-pool` : 0 octet réparé, 0 erreur (terminé le 2026-10-23 en 3 h 07)
- [x] srv2 mis à jour (2026-10-23) : 20 paquets dont correctifs de sécurité Debian, noyau 7.0.14-25, redémarrage fait ; invités, NFS et Immich vérifiés après coup

### 🔄 En Cours

- [ ] Monitoring Checkmk (LXC 108) — reste : mot de passe `cmkadmin`, notifications e-mail, agents/logs, supervision de vzdump
- [ ] Backups automatisés — srv2 n'a aucun job vzdump (vm-intranet, filestore) ; le Beelink est couvert par le job hebdomadaire
- [ ] Vaultwarden — reste : copie hors machine des dumps
- [ ] Home Assistant — configuration domotique
- [ ] Pi-hole — configuration DNS ad-blocker
- [ ] Poste.io — configuration mail server

### 📅 Prochaines Étapes

- [ ] Machine de sauvegarde dédiée (support séparé, idéalement en miroir, ≥ 4 TB) : copie des photos, des fichiers et des invités Proxmox ; ensuite snapshots ZFS sur `photos`
- [ ] Nextcloud déploiement

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

**Dernière mise à jour:** 26 octobre 2026 (resynchronisation du README avec l'infra réelle ; déploiement de Project NOMAD sur srv2)
**Version architecture:** 3.2 (3 machines EXTRANET/INTRANET/NAS ZimaOS)

---

<div align="center">
  <b>Made with ❤️ for learning and family</b>
</div>
