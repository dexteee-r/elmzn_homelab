# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.7.0] - 2026-09-22

### Mise a jour de suivi — monitoring, filestore, linktree en prod, n8n a l'arret

#### Added
- LXC 108 `monitoring` (192.168.1.118, pve-extranet) : Checkmk 2.5.0p12 Community (natif, OMD). Special Agent Proxmox VE configure et fonctionnel sur l'hote `pve-extranet` — supervision de l'hote + piggyback pour les 8 LXC/VM. En cours : creation manuelle des hotes piggyback dans l'UI (pas d'auto-discovery de ces hotes dans cette version de Checkmk).
- LXC 201 `filestore` (192.168.1.203, srv2) : FileBrowser Quantum (natif, systemd), interface web de stockage sur le dataset ZFS deja existant `data-pool/files` (512 Go). Public LAN-only sur `https://files.elmzn.be`. Migration du dossier de montage personnel (418 Go / 13 862 fichiers) terminee.

#### Changed
- `links.elmzn.be` (linktree-host) passe en production complete : DNS OVH + Proxy Host NPM (public, sans Access List). Lien Twitch ajoute, page `/stats` entierement refaite (metriques par evenement horodate plutot que compteurs cumules), backup CSV quotidien des statistiques, liens reordonnes par priorite metier.
- n8n (LXC 106) arrete volontairement (inutilise pour l'instant) — `onboot` desactive pour qu'il ne redemarre plus automatiquement avec le Beelink. Le conteneur, ses workflows et ses credentials restent en place pour une reprise future.

#### Notes
- Ce depot de documentation avait pris du retard sur plusieurs services reels deployes ou arretes entre le 12 et le 21 septembre — mise a jour de rattrapage pour que README et CHANGELOG refletent l'etat actuel de l'infrastructure.
- Le diagramme d'architecture et les tables de services du README ont ete corriges sur un point herite : le port forwarding WAN listait encore OpenVPN (abandonne depuis longtemps au profit de WireGuard) au lieu du vrai port 51820/udp.

## [3.6.0] - 2026-09-19

### Nouveau repo `linktree-host` — page link-in-bio (préparation)

#### Added
- Repo dédié créé : `github.com/dexteee-r/linktree-host` (public) — Node.js/Express + SQLite, page de liens auto-hébergée pour `links.elmzn.be`, prévue sur `vm-extranet` aux côtés de NPM (conteneur Docker, aucun port exposé sur le LAN, réseau Docker partagé avec NPM).

#### Notes
- Suit le pattern déjà établi pour watchlist/n8n/MyTCG : le code applicatif vit dans son propre repo, ce dépôt ne garde que le CHANGELOG + le README.
- Corrections apportées avant publication du repo : image Docker passée d'Alpine à `node:20-slim` (le module natif `better-sqlite3` a des binaires précompilés surtout pour glibc, Alpine/musl risquait de forcer une compilation à la volée sans toolchain dans l'image) ; déploiement par défaut basculé sur `root@192.168.1.111` plutôt qu'un compte `webadmin` non confirmé sur cette VM (seul `webadmin@lxc-web/.112` est vérifié) ; `NPM_NETWORK_NAME` rendu obligatoire dans le `docker-compose.yml` pour éviter un déploiement silencieux sur le mauvais réseau Docker (l'ancien fallback `vm-extranet_default` n'était qu'une supposition, jamais vérifiée).
- Déploiement effectif sur `vm-extranet` **fait** le même jour : réseau Docker NPM réel identifié en live (`extranet_default` — ni l'hypothèse du code ni l'ancien fichier de doc n'étaient corrects), conteneur `linktree-host` construit et démarré, healthy. Deux bugs corrigés en cours de route : le volume `data/` était créé root:root par Docker (SQLite ne pouvait pas ouvrir son fichier tant que le conteneur tourne en non-root) → fixé en réutilisant l'utilisateur `node` intégré à l'image `node:20-slim` (UID/GID 1000) plutôt que d'en créer un nouveau (qui entrait en conflit de GID) ; `deploy.sh` dépendait de `rsync`, absent de Git Bash sous Windows → remplacé par un transfert `tar` sur `ssh`.
- Reste à faire (hors de portée sans les identifiants du compte utilisateur) : enregistrement DNS `links.elmzn.be` chez OVH (CNAME vers le DDNS, comme pour MyTCG) + création du Proxy Host NPM — **volontairement public, sans Access List LAN-only**, contrairement à `elmzn.be`/n8n/files, puisque c'est un lien de bio destiné aux réseaux sociaux.

## [3.5.2] - 2026-09-11

### MyTCG — cotes japonaises + resynchronisation du dépôt sur `/opt`

#### Added
- Rafraîchissement automatique des cotes de cartes **japonaises** (`mytcg-prices-jp.timer`, source yuyu-tei.jp), tous les 3 jours — même mécanisme que les cotes anglaises existantes (`mytcg-prices.timer`).

#### Changed
- Le dépôt applicatif `MyTGC` (units systemd, `deploy.sh`/`autodeploy.sh`, conf Nginx, README) référence désormais `/opt/mytcg` au lieu de `/srv/mytcg` — la dérive laissée ouverte par la migration du `[3.5.1]` (seule la machine avait été patchée à la main) est maintenant résolue à la source.
- `mytcg-backup.service` durci : 7 directives systemd supplémentaires, dont `RestrictAddressFamilies=AF_UNIX` — plus strict que l'unit API, car ce job ne doit jamais ouvrir de connexion réseau.

#### Notes
- La nouvelle unit `mytcg-prices-jp` avait `/srv/mytcg` codé en dur **sans repli**, contrairement aux 4 units historiques qui lisent une variable d'environnement en priorité. Son premier lancement a échoué (binaire introuvable) — c'est ce qui a révélé que la dérive `/srv`→`/opt` n'avait jamais été reportée dans le dépôt.
- Le durcissement du backup a été validé par un run réel, pas seulement « le service démarre » : le fichier produit a été vérifié avec `gzip -t` et `PRAGMA integrity_check`.

## [3.5.1] - 2026-09-06

### MyTCG — migration `/srv/mytcg` → `/opt/mytcg`

#### Changed
- Le code de MyTCG (LXC 107) vit désormais dans `/opt/mytcg`, alignant enfin ce service sur la convention du reste de l'infra (`/opt/watchlist`, `/opt/n8n`). L'écart signalé dans les Notes du `[3.5.0]` est résolu.

#### Notes
- Les 4 units systemd (`mytcg-api`, `mytcg-autodeploy`, `mytcg-backup`, `mytcg-prices`) et la conf Nginx ont été repointées vers `/opt/mytcg`, l'utilisateur système `mytcg` a son `home` mis à jour (`/etc/passwd`), et le virtualenv Python a été **reconstruit** (son binaire `uvicorn` porte un shebang absolu — un simple déplacement de dossier l'aurait cassé).
- Le dépôt applicatif `MyTGC` (units et conf Nginx sous `deploy/`) référence encore `/srv/mytcg` en dur. Plutôt que de corriger des scripts que le prochain `git reset --hard` du déploiement automatique aurait de toute façon écrasés, deux variables (`MYTCG_APP_DIR`, `MYTCG_WEB_DIR`) ont été ajoutées à `/etc/mytcg/mytcg.env` — hors du checkout, donc stables face aux redéploiements. `deploy.sh`/`autodeploy.sh` les lisaient déjà en priorité sur leur valeur par défaut.
- Effet de bord attendu : le contrôle de dérive intégré à `deploy.sh` signalera désormais les 4 units comme « differs from the installed copy » à chaque déploiement, tant que les templates du dépôt ne sont pas mis à jour côté `MyTGC`. Non bloquant (avertissement seul), mais à corriger en amont pour faire taire le bruit.
- Validé de bout en bout : `backup.sh` et `deploy.sh` rejoués manuellement depuis le nouvel emplacement (build, 213 tests front + suite pytest, redémarrage API, `/health` correct), puis **`pct reboot 107`** pour prouver que nginx, l'API et les 3 timers remontent seuls sans unit en échec — même rigueur que le bug de boot Nginx du 2026-08-15.

## [3.5.0] - 2026-08-07

### Déploiement MyTCG — gestionnaire de collection de cartes

#### Added
- **MyTCG** déployé sur `pve-extranet` (Beelink) : LXC 107 dédié, **stack native (sans Docker)** — uvicorn/FastAPI + Nginx + SQLite
  - LXC non-privilégié, `nesting=1`, 4 Go RAM / 2 cœurs / 20 Go disque, IP statique `192.168.1.117`, Debian 13
  - API en écoute sur `127.0.0.1:8000` (unit `mytcg-api`, hardening systemd), Nginx sert la SPA et les images en direct
  - Données applicatives hors du checkout : `/var/lib/mytcg` (base SQLite + 2,5 Go d'images de cartes)
- **`mytcg.elmzn.be`** exposé publiquement via NPM (CNAME OVH vers le DDNS, Let's Encrypt, Force SSL, HTTP/2)
  - Nginx du LXC restreint aux seules requêtes du reverse proxy (`allow` NPM + loopback, `deny all`) → un accès direct par IP depuis le LAN renvoie **403**
- **Déploiement automatique pull-based** (timer systemd, toutes les 5 minutes) : détecte un nouveau commit sur `main`, **n'agit que si la CI est verte**, puis backup → pull → dépendances → build front → tests → redémarrage de l'API
- **Backup nocturne** de la base : `sqlite3 .backup` + gzip, rétention 30 jours (timer systemd)
- Inscriptions fermées par défaut (**mode `invite`** — code d'invitation obligatoire, exception pour le premier compte)

#### Notes
- ⚠️ **`NoNewPrivileges=yes` et `sudo` sont incompatibles dans une unit systemd.** L'unit de déploiement portait ce flag alors que son script se termine par `sudo systemctl restart` : le déploiement réussissait **entièrement** (pull, build, tests) puis échouait sur le seul redémarrage — le nouveau code sur le disque, l'ancien processus toujours en service, et **aucun symptôme visible côté site**. Le piège ne se reproduit pas en lançant le script à la main (le flag n'est posé que par systemd). Corrigé par un drop-in `NoNewPrivileges=no`, le reste du durcissement conservé et la règle sudoers limitée à cette seule commande.
- L'endpoint `/health` publie le **commit servi** : moyen le plus rapide de vérifier quelle version tourne réellement, sans ouvrir de session SSH.
- Nginx : après installation d'un nouveau site, `systemctl reload` a laissé servir la page par défaut alors que `nginx -T` montrait bien la bonne configuration. **`restart` requis** — réflexe à garder quand la conf chargée et le comportement observé divergent.
- Un dossier de déploiement préparé sous Windows arrive en **CRLF** : les scripts meurent sur `env: 'bash\r': No such file or directory`. Nettoyer avec `tr -d '\015'` (un `sed "s/\r$//"` passé à travers plusieurs couches de shell distant perd son `\r` en route et ne corrige rien).
- Chaque nouveau sous-domaine doit être ajouté au fichier `hosts` du poste de travail, **vers le reverse proxy** — le hairpin NAT de la box ne permet pas de repasser par l'IP publique depuis le LAN.
- ⚠️ **Le code vit dans `/srv/mytcg`, pas `/opt/<app>` comme les autres services** (`watchlist`, `n8n`). Écart volontaire non corrigé : le dossier de déploiement fourni pour ce projet était écrit pour une autre infra et fixait déjà ses chemins sur `/srv`, repris tel quel. Sans conséquence pratique (les 4 units systemd, la conf Nginx et l'utilisateur système `mytcg` sont cohérents entre eux), mais à garder en tête si un service est un jour reprovisionné à partir de ce dossier de déploiement.

---

## [3.4.0] - 2026-08-05

### LLM local (Ollama) pour les workflows n8n

#### Added
- **Ollama** ajouté à la stack Docker du LXC 106 (image `ollama/ollama:latest`), modèle **`qwen2.5:7b`** en inférence CPU
  - **Aucun port publié** : le service n'est joignable que par n8n via le réseau interne Compose (`http://ollama:11434`) — évite d'exposer une API d'inférence non authentifiée sur le LAN
  - Volume nommé `ollama_models` pour la persistance des modèles
  - Objectif : génération de contenu sans dépendance à une API tierce (pas de transfert de données hors infrastructure, coût marginal nul)

#### Changed
- **LXC 106** redimensionné : RAM `2 Go → 8 Go`, cœurs `2 → 4`, disque `16 Go → 32 Go` (opérations à chaud, sans interruption de service)

#### Notes
- Performances mesurées (Intel N95, CPU seul) : ~17 s de chargement à froid, **~101 s pour 400 tokens** (4,4 tokens/s), pic RAM ~5 Go
- Timeout HTTP à prévoir côté n8n : **300 s** (le modèle est déchargé après 5 min d'inactivité, chaque exécution repart donc à froid)
- L'image Ollama pèse **6,3 Go** (bibliothèques GPU incluses même en usage CPU) — à prendre en compte dans le dimensionnement disque

---

## [3.3.0] - 2026-08-05

### Exposition publique de n8n + endpoint media statique

#### Added
- **n8n** exposé publiquement sur 2 sous-domaines dédiés (reverse proxy NPM + Let's Encrypt) :
  - `n8n.elmzn.be` — éditeur + API REST, accès restreint LAN/VPN (Access List NPM)
  - `hooks.elmzn.be` — webhooks uniquement (`/webhook/*`, `/webhook-test/*`), public, pour intégrations externes
- **Endpoint media statique** `media.elmzn.be` — service nginx dédié (LXC 106, port 8081), lecture seule, sans listing de répertoire
  - Purge automatique horaire des fichiers de plus de 48h (cron)
  - Écriture par n8n via volume partagé sur le même LXC
- `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` (au lieu du mode mémoire par défaut) pour le traitement de fichiers volumineux

#### Changed
- n8n : `N8N_PROTOCOL=https`, `WEBHOOK_URL` et `N8N_EDITOR_BASE_URL` sur des domaines dédiés, `N8N_PROXY_HOPS=1`

---

## [3.2.0] - 2026-08-05

### Déploiement n8n — automatisation self-hosted

#### Added
- **n8n** déployé sur `pve-extranet` (Beelink) : LXC 106 dédié, Docker (image `n8nio/n8n:latest`), port 5678
  - LXC non-privilégié, `nesting=1,keyctl=1`, 2 Go RAM / 2 cœurs / 16 Go disque, IP statique `192.168.1.116`
  - Volume Docker nommé pour la persistance des workflows/credentials (`/home/node/.n8n`)
  - Licence Community Edition activée
- Accès **LAN uniquement** pour l'instant (pas d'exposition VPN ni sous-domaine public)

---

## [3.1.1] - 2026-07-30

### Mise à jour Immich — migration VectorChord

#### Changed
- **Immich** mis à jour `v2.3.1` → `v3.1.0` sur vm-intranet (192.168.1.201)
- **PostgreSQL** (service `database`, vm-intranet) : image `tensorchord/pgvecto-rs:pg14-v0.2.0` → `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0`
- Reindexation automatique des index `clip_index` et `face_index` (recherche par similarité, reconnaissance faciale) déclenchée au redémarrage du service

#### Fixed
- Extension vectorielle Postgres dépréciée (`pgvecto.rs`) supprimée avant qu'Immich v3 n'en abandonne le support

---

## [3.1.0] - 2026-04-28

### Déploiement web Next.js — portfolio.elmzn.be

#### Added
- **`portfolio.elmzn.be`** déployé en production sur lxc-web
  - Stack : Next.js SSR, mode `output: 'standalone'`
  - Process manager : PM2 (`portfolio` — port 3001)
  - Chemin : `/var/www/school_portfolio/mm-elmazani-portfolio/`
- **Node.js 20 LTS** installé sur lxc-web (192.168.1.112)
- **PM2** installé globalement sur lxc-web
- Proxy host NPM `portfolio.elmzn.be` → `192.168.1.112:80` + SSL Let's Encrypt
- Virtual host Nginx `portfolio.elmzn.be` → reverse proxy `localhost:3001`
- `docs/web-server-doc-v2.docx` — documentation web server mise à jour (section 5 Next.js complète : RAM, rsync, env vars, standalone, PM2)

#### Changed
- RAM lxc-web augmentée : 512 MB → **1536 MB** (nécessaire pour le build Next.js)

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
