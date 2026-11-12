# 📓 JOURNAL DE BORD - Setup Homelab Machine #2

**Date:** 02-04 décembre 2025  
**Projet:** Migration infrastructure media-server-home vers architecture 2 machines  
**Machine:** Dell Custom PC (Machine #2 - srv2)

---

## 🎯 OBJECTIF SESSION

Déployer Machine #2 comme serveur INTRANET dédié avec Proxmox VE 9.1, stockage ZFS 4TB, et stack Docker (Immich, Grafana, Prometheus, NPM).

---

## 📋 PHASE 1 - INSTALLATION PROXMOX M2

### **Hardware Machine #2 identifié:**
```
CPU: Intel i7-6700 (4C/8T @ 3.4-4.0 GHz)
RAM: 16 GB DDR4
Storage:
├─ SSD: 447 GB (Crucial MX500) - /dev/sdb
└─ HDD: 3.6 TB (Seagate IronWolf ST4000VNZ06) - /dev/sda
GPU: GTX 980 (pas utilisé cette session)
Alimentation: 850W
```

### **Installation Proxmox VE 9.1:**
- ISO: proxmox-ve_9.1-1.iso
- Target: /dev/sdb (SSD 447 GB)
- Partitionnement auto:
  - sdb1: 1007K (boot)
  - sdb2: 1G (EFI)
  - sdb3: 446.1G (LVM)
    - pve-swap: 8G
    - pve-root: 96G (/)
    - pve-data: 319.6G (VMs/containers)

### **Configuration réseau Proxmox M2:**
```
Hostname: srv2
IP: <IP_SRV2>/24
Gateway: <IP_BOX>
DNS: <IP_BOX>
Interface: vmbr0 (bridge sur nic0)
```

### **Post-installation:**
```bash
# Désactivé repo enterprise
nano /etc/apt/sources.list.d/pve-enterprise.list
# Commenté ligne

# Ajouté repo community
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-community.list

# Updates
apt update && apt upgrade -y

# Packages essentiels
apt install -y zfsutils-linux nfs-kernel-server samba smartmontools htop curl wget vim
```

**✅ Proxmox M2 opérationnel:** https://`<IP_SRV2>`:8006

---

## 📋 PHASE 2 - CONFIGURATION ZFS STOCKAGE 4TB

### **Création pool ZFS sur HDD IronWolf:**
```bash
# Pool ZFS avec compression LZ4
zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  data-pool /dev/sda
```

### **Datasets avec quotas:**
```bash
zfs create -o mountpoint=/mnt/data-pool/photos -o quota=2T data-pool/photos
zfs create -o mountpoint=/mnt/data-pool/files -o quota=512G data-pool/files
zfs create -o mountpoint=/mnt/data-pool/backups -o quota=512G data-pool/backups
zfs create -o mountpoint=/mnt/data-pool/media -o quota=512G data-pool/media
```

### **Répartition stockage:**
```
Total: 3.7 TB
├─ photos: 2.0 TB (Immich uploads)
├─ files: 512 GB (Nextcloud partage futur)
├─ backups: 512 GB (Snapshots + Restic)
├─ media: 512 GB (Vidéos futures)
└─ Libre: ~200 GB (buffer système)
```

### **Validation ZFS:**
```bash
zpool status
# Output: ONLINE, 0 errors

zfs list
# 4 datasets montés correctement
```

**✅ ZFS pool opérationnel avec 4 datasets**

---

## 📋 PHASE 3 - CONFIGURATION NFS EXPORTS

### **Fichier /etc/exports:**
```bash
/mnt/data-pool/photos <LAN>/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/data-pool/files <LAN>/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/data-pool/backups <LAN>/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/data-pool/media <LAN>/24(rw,sync,no_subtree_check,no_root_squash)
```

### **Activation service NFS:**
```bash
exportfs -ra
systemctl enable nfs-kernel-server --now
systemctl status nfs-kernel-server
# Active: active (running)

# Validation
showmount -e localhost
# 4 exports visibles
```

**✅ NFS server configuré et fonctionnel**

---

## 📋 PHASE 4 - CONFIGURATION SAMBA

### **Installation Samba:**
```bash
apt install -y samba samba-common-bin
```

### **Configuration /etc/samba/smb.conf:**
```ini
[global]
workgroup = WORKGROUP
server string = Proxmox M2 Storage
security = user

[photos]
path = /mnt/data-pool/photos
browseable = yes
writable = yes
guest ok = no
valid users = root

[files]
path = /mnt/data-pool/files
browseable = yes
writable = yes
guest ok = no
valid users = root

[backups]
path = /mnt/data-pool/backups
browseable = yes
writable = yes
guest ok = no
valid users = root

[media]
path = /mnt/data-pool/media
browseable = yes
writable = yes
guest ok = no
valid users = root
```

### **Configuration user Samba:**
```bash
smbpasswd -a root
# Password: admin (noté)

systemctl enable smbd --now
systemctl restart smbd
```

### **Validation:**
```bash
smbclient -L localhost -U root
# 4 shares visibles
```

**Accès Windows:** `\\<IP_SRV2>` (root / admin)

**✅ Samba configuré pour accès Windows/Mac**

---

## 📋 PHASE 5 - CRÉATION VM-INTRANET

### **Spécifications VM:**
```
VM ID: 101
Name: vm-intranet
Hostname: vmIntranet
OS: Debian 13.1.0 (debian-13.1.0-amd64-netinst.iso)
CPU: 3 cores (type: host)
RAM: 6144 MB (6 GB) avec ballooning
Disk: 40 GB (local-lvm, VirtIO SCSI)
Network: vmbr0 (VirtIO, firewall désactivé initialement)
Qemu Agent: Activé
```

### **Installation Debian 13:**
- Partitioning: Guided - use entire disk (all files in one partition)
- Software selection: SSH server + standard utilities UNIQUEMENT
- Users créés: root + admin (passwords forts)

### **Configuration réseau VM:**

**Fichier /etc/network/interfaces:**
```
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet static
    address <IP_VM_INTRANET>/24
    gateway <IP_BOX>
    dns-nameservers <IP_BOX> 8.8.8.8
```

### **Problème réseau initial:**
- Symptôme: Pas de route par défaut après config
- Solution: Désactivation firewall VM dans Proxmox (Hardware → Network → Edit)
- Résultat: Ping gateway et Internet OK

### **Installation packages VM:**
```bash
# Docker
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin

# Utilitaires
apt install -y nfs-common htop curl wget vim git qemu-guest-agent

# Qemu agent
systemctl enable qemu-guest-agent --now

# Docker permissions
usermod -aG docker admin
```

**✅ VM-INTRANET créée et configurée (`<IP_VM_INTRANET>`)**

---

## 📋 PHASE 6 - MONTAGE NFS DANS VM

### **Création points de montage:**
```bash
mkdir -p /mnt/{photos,files,backups,media}
```

### **Montage NFS depuis Proxmox M2:**
```bash
mount -t nfs <IP_SRV2>:/mnt/data-pool/photos /mnt/photos
mount -t nfs <IP_SRV2>:/mnt/data-pool/files /mnt/files
mount -t nfs <IP_SRV2>:/mnt/data-pool/backups /mnt/backups
mount -t nfs <IP_SRV2>:/mnt/data-pool/media /mnt/media
```

### **Configuration /etc/fstab (mounts permanents):**
```
<IP_SRV2>:/mnt/data-pool/photos  /mnt/photos  nfs defaults 0 0
<IP_SRV2>:/mnt/data-pool/files   /mnt/files   nfs defaults 0 0
<IP_SRV2>:/mnt/data-pool/backups /mnt/backups nfs defaults 0 0
<IP_SRV2>:/mnt/data-pool/media   /mnt/media   nfs defaults 0 0
```

### **Validation:**
```bash
df -h | grep nfs
# 4 mounts NFS affichés avec bonnes capacités (2TB, 512G, 512G, 512G)
```

**✅ NFS mounts fonctionnels dans VM**

---

## 📋 PHASE 7 - DÉPLOIEMENT DOCKER STACK

### **Structure créée:**
```
/srv/intranet/
├── .env
└── docker-compose.yml
```

### **Fichier .env:**
```bash
DB_PASSWORD=<généré avec openssl rand -base64 32>
GRAFANA_PASSWORD=<généré avec openssl rand -base64 32>
```

### **Stack Docker initiale (avant fix):**
Services tentés:
- immich-server (port 2283)
- postgres (PostgreSQL 16 avec pgvecto-rs)
- redis (cache)
- prometheus (port 9090)
- grafana (port 3000)
- node-exporter (port 9100)

### **Problème initial Immich:**
- **Symptôme:** Container crash loop "Restarting (0)"
- **Cause:** Service immich-machine-learning manquant
- **Logs:** "Machine learning server unhealthy"

### **Solution - Docker Compose OFFICIEL Immich:**

**Fichier docker-compose.yml FINAL:**
```yaml
name: immich

services:
  # NPM - Nginx Proxy Manager
  npm:
    container_name: npm
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
      - 81:81
    volumes:
      - ./npm-data:/data
      - ./letsencrypt:/etc/letsencrypt
    environment:
      - TZ=Europe/Brussels

  # Immich Server
  immich-server:
    container_name: immich_server
    image: ghcr.io/immich-app/immich-server:release
    volumes:
      - /mnt/photos:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    environment:
      DB_HOSTNAME: immich_postgres
      DB_USERNAME: postgres
      DB_PASSWORD: ${DB_PASSWORD}
      DB_DATABASE_NAME: immich
      REDIS_HOSTNAME: immich_redis
    ports:
      - 2283:2283
    depends_on:
      - redis
      - database
    restart: always

  # Immich Machine Learning
  immich-machine-learning:
    container_name: immich_machine_learning
    image: ghcr.io/immich-app/immich-machine-learning:release
    volumes:
      - model-cache:/cache
    restart: always

  # Redis
  redis:
    container_name: immich_redis
    image: redis:6.2-alpine
    restart: always

  # PostgreSQL Database
  database:
    container_name: immich_postgres
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: postgres
      POSTGRES_DB: immich
    volumes:
      - /srv/postgres-data:/var/lib/postgresql/data
    restart: always

  # Prometheus
  prometheus:
    container_name: prometheus
    image: prom/prometheus:latest
    ports:
      - 9090:9090
    volumes:
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
    restart: always

  # Grafana
  grafana:
    container_name: grafana
    image: grafana/grafana:latest
    ports:
      - 3000:3000
    volumes:
      - grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    restart: always

  # Node Exporter
  node-exporter:
    container_name: node_exporter
    image: prom/node-exporter:latest
    ports:
      - 9100:9100
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    restart: always

volumes:
  model-cache:
  prometheus-data:
  grafana-data:
```

### **Déploiement:**
```bash
cd /srv/intranet
docker compose up -d
sleep 30
docker compose ps
# Tous containers "Up" et "healthy"
```

**✅ Stack Docker complète déployée et fonctionnelle**

---

## 📋 PHASE 8 - CONFIGURATION NGINX PROXY MANAGER

### **Problème version NPM:**
- Tentative image `jc21/nginx-proxy-manager:2` (comme M1)
- Reste sur `latest` malgré changements
- **Solution:** Abandonné, `latest` fonctionne correctement

### **Accès NPM:**
- URL: `http://<IP_VM_INTRANET>:81`
- Login default: `admin@example.com` / `changeme`
- Changé email + password admin

### **Certificat SSL Let's Encrypt:**
- **Problème initial:** Sous-domaine `*.intranet.elmzn.be` pas accessible
- **Cause:** DNS OVH ne pointait pas vers bonne IP
- **Solution:** Créé zone DNS `intranet.elmzn.be` pointant vers IP publique
- **Certificat wildcard créé:** `*.intranet.elmzn.be`
- **Méthode:** DNS Challenge OVH avec credentials API

### **Proxy Hosts créés:**

#### **1. Immich (immich.intranet.elmzn.be)**
```
Domain: immich.intranet.elmzn.be
Forward Hostname: immich_server
Forward Port: 2283
SSL Certificate: *.intranet.elmzn.be (Let's Encrypt)
Force SSL: ✅
Websockets Support: ✅ (CRITIQUE - sans ça "Serveur hors ligne")
```

**Advanced config (WebSocket fix):**
```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_read_timeout 600s;
proxy_send_timeout 600s;
```

#### **2. NPM (npm.intranet.elmzn.be)**
```
Domain: npm.intranet.elmzn.be
Forward Hostname: npm
Forward Port: 81
SSL Certificate: *.intranet.elmzn.be
Force SSL: ✅
```

#### **3. Grafana (grafana.intranet.elmzn.be)**
```
Domain: grafana.intranet.elmzn.be
Forward Hostname: grafana
Forward Port: 3000
SSL Certificate: *.intranet.elmzn.be
Force SSL: ✅
```

#### **4. Prometheus (prometheus.intranet.elmzn.be)**
```
Domain: prometheus.intranet.elmzn.be
Forward Hostname: prometheus
Forward Port: 9090
SSL Certificate: *.intranet.elmzn.be
Force SSL: ✅
```

**✅ NPM configuré avec 4 proxy hosts SSL fonctionnels**

---

## 📋 PHASE 9 - CONFIGURATION IMMICH

### **Problème "Serveur hors ligne":**
- **Symptôme:** Immich affiche "Serveur hors ligne" via proxy, "Serveur en ligne" en direct IP
- **Cause:** WebSocket non supporté dans config NPM
- **Solution:** Activé "Websockets Support" dans Proxy Host Immich + custom config nginx

### **Création compte admin Immich:**
- Accès: `https://immich.intranet.elmzn.be`
- Compte admin créé avec password fort (noté)
- **Note:** Reset DB effectué 2x car passwords oubliés (`rm -rf /srv/postgres-data/*`)

### **Test upload photos:**
- Upload fonctionnel via web UI
- Photos stockées dans `/mnt/photos` (NFS mount depuis ZFS)
- Machine Learning opérationnel (reconnaissance faciale, smart search)

**✅ Immich pleinement fonctionnel avec uploads**

---

## 📋 PHASE 10 - VM DEBIAN TEST

### **Création VM supplémentaire:**
```
VM ID: 102 (supposé)
Name: vm-debian-test
OS: Debian 13.1.0
CPU: 2 cores
RAM: 2 GB
Disk: 20 GB
Network: vmbr0
IP: <IP_LXC_MINECRAFT>
Usage: Tests distributions Linux (on-demand, pas H24)
```

**✅ VM test créée pour lab futures distros**

---

## 🎯 RÉSULTAT FINAL

### **Architecture déployée:**

```
Machine M2 (srv2) - <IP_SRV2>:
├─ Proxmox VE 9.1 (host)
│  └─ Web UI: https://<IP_SRV2>:8006
├─ ZFS pool data-pool (3.6TB HDD IronWolf)
│  ├─ photos (2TB quota) → NFS + Samba
│  ├─ files (512GB quota) → NFS + Samba
│  ├─ backups (512GB quota) → NFS + Samba
│  └─ media (512GB quota) → NFS + Samba
├─ NFS server (exports vers <LAN>/24)
├─ Samba server (accès Windows: \\<IP_SRV2>)
├─ VM-INTRANET (101) - <IP_VM_INTRANET>:
│  ├─ Debian 13 (6GB RAM, 3 vCPU, 40GB disk)
│  ├─ NFS mounts: /mnt/{photos,files,backups,media}
│  └─ Docker stack:
│     ├─ Immich (https://immich.intranet.elmzn.be) ✅
│     ├─ NPM (https://npm.intranet.elmzn.be) ✅
│     ├─ Grafana (https://grafana.intranet.elmzn.be) ✅
│     ├─ Prometheus (https://prometheus.intranet.elmzn.be) ✅
│     ├─ PostgreSQL (immich_postgres) ✅
│     ├─ Redis (immich_redis) ✅
│     ├─ ML (immich_machine_learning) ✅
│     └─ Node Exporter (:9100) ✅
└─ VM-DEBIAN-TEST (102) - <IP_LXC_MINECRAFT> ✅

Machine M1 (OptiPlex) - <IP_PVE_EXTRANET>:
├─ Proxmox VE 8.4 (host)
├─ VM-EXTRANET (<IP_VM_EXTRANET>) - NPM public, OpenVPN
└─ VM-INTRANET (<IP_INTRANET_OBSOLETE>) - À SUPPRIMER (obsolète)
```

### **Services accessibles:**

**Depuis LAN:**
```
Immich:      https://immich.intranet.elmzn.be
NPM:         https://npm.intranet.elmzn.be
Grafana:     https://grafana.intranet.elmzn.be
Prometheus:  https://prometheus.intranet.elmzn.be
Proxmox M2:  https://<IP_SRV2>:8006
Proxmox M1:  https://<IP_PVE_EXTRANET>:8006
Samba M2:    \\<IP_SRV2> (root / admin)
```

**Accès direct IP (alternatif):**
```
Immich:      http://<IP_VM_INTRANET>:2283
NPM:         http://<IP_VM_INTRANET>:81
Grafana:     http://<IP_VM_INTRANET>:3000
Prometheus:  http://<IP_VM_INTRANET>:9090
```

---

## 📊 MÉTRIQUES CLÉS

### **Stockage:**
```
ZFS pool data-pool:
├─ Capacité totale: 3.7 TB
├─ Alloué (quotas): 3.5 TB
├─ Libre (buffer): ~200 GB
├─ Compression: LZ4 (~20% économie attendue)
└─ Santé: ONLINE, 0 errors
```

### **Ressources VM-INTRANET:**
```
RAM: 6 GB / 16 GB host (37.5%)
CPU: 3 cores / 8 threads host (37.5%)
Disk: 40 GB (local-lvm)
Network: Gigabit (vmbr0)
```

### **Containers Docker:**
```
Tous: Up et Healthy
Immich: v2.3.1
PostgreSQL: 14 (pgvecto-rs 0.2.0)
Redis: 6.2-alpine
Grafana: latest
Prometheus: latest
NPM: latest
```

---

## 🔧 PROBLÈMES RENCONTRÉS & SOLUTIONS

### **1. Immich crash loop au démarrage**
**Cause:** Service `immich-machine-learning` manquant  
**Solution:** Utilisé docker-compose.yml officiel Immich complet

### **2. Immich "Serveur hors ligne" via proxy**
**Cause:** WebSocket non supporté dans config NPM  
**Solution:** Activé "Websockets Support" + custom nginx headers

### **3. Réseau VM pas de route par défaut**
**Cause:** Firewall VM Proxmox bloquait  
**Solution:** Désactivé firewall VM (Hardware → Network → Edit)

### **4. NPM version latest au lieu de :2**
**Cause:** Image déjà pullée en cache  
**Solution:** Abandonné, latest fonctionne correctement

### **5. DNS intranet.elmzn.be pas accessible**
**Cause:** Zone DNS OVH pas créée  
**Solution:** Créé enregistrement DNS pointant vers IP publique

### **6. Passwords Immich oubliés (2x)**
**Solution:** Reset DB avec `rm -rf /srv/postgres-data/*` puis `docker compose up -d`

---

## 📝 CREDENTIALS NOTÉS

### **Proxmox M2 (`<IP_SRV2>`:8006):**
```
User: root
Password: [défini lors installation]
```

### **VM-INTRANET (`<IP_VM_INTRANET>`):**
```
Root: [password fort]
Admin: [password fort]
```

### **Samba (\\`<IP_SRV2>`):**
```
User: root
Password: admin
```

### **Docker .env (/srv/intranet/.env):**
```
DB_PASSWORD: [généré openssl rand -base64 32]
GRAFANA_PASSWORD: [généré openssl rand -base64 32]
```

### **Immich:**
```
URL: https://immich.intranet.elmzn.be
Admin: [compte créé]
Password: [noté dans gestionnaire mots de passe]
```

### **NPM:**
```
URL: https://npm.intranet.elmzn.be
Email: [changé depuis admin@example.com]
Password: [changé depuis changeme]
```

### **Grafana:**
```
URL: https://grafana.intranet.elmzn.be
User: admin
Password: [depuis .env GRAFANA_PASSWORD]
```

---

## 🎯 PROCHAINES ÉTAPES

### **Court terme (à faire):**

1. **Nettoyage M1 (OptiPlex):**
   - [ ] SSH vers Proxmox M1 (`<IP_PVE_EXTRANET>`)
   - [ ] Stop VM-INTRANET (ID 101): `qm stop 101`
   - [ ] Supprimer VM-INTRANET: `qm destroy 101`
   - [ ] Vérifier services obsolètes host
   - [ ] Nettoyer containers Docker inutiles

2. **Configuration NPM M1 (EXTRANET):**
   - [ ] Créer proxy hosts publics vers M2
   - [ ] `media.elmzn.be` → `<IP_VM_INTRANET>:2283` (Immich)
   - [ ] `photos.elmzn.be` → Idem
   - [ ] `grafana.elmzn.be` → `<IP_VM_INTRANET>:3000` (Access List LAN+VPN)
   - [ ] Certificats SSL Let's Encrypt

3. **Port forwarding Box Internet:**
   - [ ] 80/tcp → `<IP_VM_EXTRANET>`:80
   - [ ] 443/tcp → `<IP_VM_EXTRANET>`:443
   - [ ] 1194/udp → `<IP_VM_EXTRANET>`:1194 (OpenVPN existant)

4. **Tests accès externe:**
   - [ ] `https://media.elmzn.be` depuis Internet
   - [ ] `https://grafana.elmzn.be` depuis VPN uniquement
   - [ ] Vérifier certificats SSL valides

### **Moyen terme (1-2 semaines):**

5. **Services additionnels prioritaires:**
   - [ ] Vaultwarden (gestionnaire mots de passe)
   - [ ] Uptime Kuma (monitoring uptime services)
   - [ ] Nextcloud (cloud personnel /mnt/files)
   - [ ] Pi-hole / AdGuard Home (DNS ad-blocker)

6. **Backups automatisés:**
   - [ ] Script Restic M2 → M1
   - [ ] Snapshots ZFS automatiques (cron daily)
   - [ ] Test restore complet
   - [ ] Backup offsite (Backblaze B2 / Wasabi)

7. **Sécurité:**
   - [ ] UFW firewall M2 (deny all, allow M1 + LAN)
   - [ ] Fail2ban M2 (NPM, SSH)
   - [ ] 2FA Immich (optionnel)
   - [ ] 2FA Grafana (optionnel)
   - [ ] Authentik SSO (moyen terme)

### **Long terme (1-2 mois):**

8. **Optimisations:**
   - [ ] GPU GTX 980 passthrough pour transcodage
   - [ ] Upgrade RAM M2 (16 GB → 32 GB) si besoin
   - [ ] Migration Jellyfin depuis M1 vers M2
   - [ ] Tests VMs Ubuntu, Zorin (lab)

9. **Documentation:**
   - [ ] README.md projet GitHub
   - [ ] ADRs (Architecture Decision Records)
   - [ ] SETUP.md guide installation
   - [ ] CHEATSHEET.md commandes utiles
   - [ ] Screenshots portfolio

---

## 📚 COMMANDES CLÉS UTILISÉES

### **ZFS:**
```bash
zpool create -f -o ashift=12 -O compression=lz4 -O atime=off data-pool /dev/sda
zfs create -o mountpoint=/mnt/data-pool/photos -o quota=2T data-pool/photos
zpool status
zfs list
zfs get quota data-pool/photos
```

### **NFS:**
```bash
nano /etc/exports
exportfs -ra
systemctl restart nfs-kernel-server
showmount -e localhost
mount -t nfs <IP_SRV2>:/mnt/data-pool/photos /mnt/photos
```

### **Samba:**
```bash
nano /etc/samba/smb.conf
smbpasswd -a root
systemctl restart smbd
smbclient -L localhost -U root
```

### **Docker:**
```bash
curl -fsSL https://get.docker.com | sh
docker compose up -d
docker compose ps
docker compose down
docker logs immich_server
docker exec -it immich_server bash
```

### **Proxmox:**
```bash
qm list
qm start 101
qm stop 101
qm status 101
pvesh get /nodes/srv2/qemu/101/status/current
```

---

## 💡 DÉCISIONS TECHNIQUES IMPORTANTES

### **1. Pourquoi ZFS sur HDD (pas SSD) ?**
- SSD: OS + VMs (performances)
- HDD: Données + snapshots (capacité)
- ZFS idéal pour intégrité données long terme

### **2. Pourquoi NFS + Samba (pas juste un) ?**
- **NFS:** Performance Docker (natif Linux, pas overhead)
- **Samba:** Compatibilité Windows (explorateur fichiers)
- Même stockage ZFS, protocoles différents selon usage

### **3. Pourquoi VM QEMU (pas LXC container) ?**
- Docker dans LXC = nested virtualization complexe
- QEMU = isolation complète, plus stable pour production
- Bind mounts Proxmox marchent QUE avec LXC, pas QEMU → d'où NFS

### **4. Pourquoi docker-compose.yml officiel Immich ?**
- Tentatives manuelles = crash (service ML manquant)
- Officiel = testé, maintenu, documentation
- Évite réinventer roue

### **5. Pourquoi WebSocket critique pour Immich ?**
- Immich utilise WebSocket pour updates temps réel
- Sans WebSocket: API fonctionne mais UI dit "hors ligne"
- NPM doit explicitement supporter WebSocket (pas auto)

### **6. Pourquoi pas migration M1 → M2 finalement ?**
- M2 bien configuré maintenant
- M1 garde rôle EXTRANET (NPM public, OpenVPN)
- Séparation claire DMZ (M1) vs INTRANET (M2)
- Architecture 2 machines = sécurité defense-in-depth

---

## 📈 LEÇONS APPRISES

### **Technique:**
1. **Toujours utiliser docker-compose.yml officiels** quand disponibles
2. **WebSocket support crucial** pour apps temps réel (Immich, Home Assistant)
3. **NFS requis pour QEMU VMs** (bind mounts = LXC only)
4. **ZFS quotas** = meilleur contrôle qu'espaces disque séparés
5. **Firewall VM Proxmox** peut bloquer réseau silencieusement

### **Workflow:**
1. **Lire docs officielles AVANT** de créer configs custom
2. **Tester avec curl/logs** avant accuser problème réseau
3. **docker logs container** = debug #1 pour containers
4. **Snapshots ZFS** avant changements majeurs
5. **Noter passwords IMMÉDIATEMENT** (ou gestionnaire mots de passe)

### **Architecture:**
1. **Séparer concerns** (stockage ≠ compute ≠ proxy)
2. **NFS = bon compromis** partage stockage multi-VMs
3. **NPM = simplification** reverse proxy vs Traefik/Caddy
4. **Let's Encrypt DNS Challenge** = wildcard SSL facile

---

## 🔗 RESSOURCES UTILISÉES

### **Documentation:**
- Proxmox VE: https://pve.proxmox.com/wiki/
- ZFS: https://openzfs.github.io/openzfs-docs/
- Immich: https://immich.app/docs/
- Docker: https://docs.docker.com/
- Nginx Proxy Manager: https://nginxproxymanager.com/

### **Docker Compose officiel:**
- Immich: https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

### **Communauté:**
- r/selfhosted
- r/Proxmox
- r/homelab
- Discord Immich

---

## ✅ VALIDATION FINALE

**Tous ces tests passés:**
- ✅ Proxmox M2 accessible web UI
- ✅ ZFS pool healthy, 0 errors
- ✅ NFS exports visibles depuis VM
- ✅ Samba accessible depuis Windows
- ✅ VM-INTRANET ping Internet
- ✅ Docker stack tous containers Up
- ✅ Immich upload photos fonctionne
- ✅ NPM proxy hosts HTTPS valides
- ✅ Grafana dashboards accessibles
- ✅ Prometheus scraping metrics

**Infrastructure STABLE et PRODUCTION-READY pour usage LAN**

---

## 📅 TIMELINE SESSION

**02/12/2025:** Installation Proxmox M2, configuration ZFS, NFS, Samba (3-4h)  
**03/12/2025:** Création VM-INTRANET, Docker stack, troubleshooting Immich (3-4h)  
**04/12/2025:** Configuration NPM, SSL, proxy hosts, WebSocket fix (2-3h)  

**Total temps:** ~8-11h (sur 3 jours, sessions de 2-4h)

---

## 🎉 SUCCÈS

**Machine #2 est maintenant:**
- ✅ Serveur INTRANET production 24/7
- ✅ Stockage centralisé ZFS 4TB
- ✅ Partage NFS + Samba fonctionnel
- ✅ Stack Docker complète (Immich, monitoring)
- ✅ Reverse proxy SSL avec Let's Encrypt
- ✅ Prêt pour services additionnels (Nextcloud, Vaultwarden, etc.)

**Prochaine session: Configuration NPM M1 + accès Internet public**

---

**FIN DU JOURNAL DE BORD**