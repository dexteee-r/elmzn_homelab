# ADR-003 : Nginx Proxy Manager comme reverse-proxy principal

**Date création** : 20/10/2025  
**Date révision** : 02/11/2025  
**Statut** : ✅ Accepté (révisé)  
**Décideurs** : Équipe projet  
**Tags** : `reverse-proxy`, `npm`, `traefik`, `nginx`, `ssl`

> ⚠️ **Note (2026-09-22) :** cette ADR documente une décision figée au moment de sa rédaction. L'IP `192.168.1.101` citée plus bas pour VM-INTRANET est **obsolète** (la vraie IP vérifiée est `192.168.1.201`). Pour l'état réel actuel de l'infrastructure, voir `README.md`.

---

## 📋 Contexte

Le homelab expose plusieurs services web (Jellyfin, Immich, Grafana, etc.) sur des ports différents. Un **reverse-proxy** est nécessaire pour :

1. **Centraliser l'accès** : Un seul point d'entrée HTTPS (port 443)
2. **Gestion SSL automatique** : Certificats Let's Encrypt pour chaque service
3. **Isolation réseau** : Services en backend (pas d'exposition directe)
4. **URL propres** : `media.elmzn.be` → Jellyfin:8096, `photos.elmzn.be` → Immich:2283

**Candidats évalués** :
- **Traefik** (v3) - Reverse-proxy cloud-native avec auto-discovery
- **Nginx Proxy Manager (NPM)** - Interface web pour Nginx
- **Caddy** (v2) - Reverse-proxy avec HTTPS automatique
- **HAProxy** - Load balancer entreprise

---

## 🤔 Décision (révision 02/11/2025)

**Choix initial (20/10/2025)** : Traefik  
**Choix final (02/11/2025)** : **Nginx Proxy Manager (NPM)**

**Raison du changement** :
Après tests pratiques, NPM s'est avéré **plus simple et plus stable** pour un homelab avec architecture multi-VM. Traefik est puissant mais overkill pour nos besoins.

---

## ⚖️ Analyse comparative (mise à jour 02/11/2025)

### Nginx Proxy Manager (choix final)

**✅ Avantages** :
- **Interface web intuitive** : Gestion visuelle (vs fichiers YAML Traefik)
- **Certificats SSL automatiques** : Let's Encrypt intégré (1 clic)
- **Logs centralisés** : Dashboard avec logs en temps réel
- **Gestion utilisateurs** : Multi-admins avec rôles
- **Templates proxy** : Configurations prêtes pour apps populaires
- **Stabilité** : Nginx battle-tested depuis 20 ans
- **Ressources légères** : ~200 MB RAM (vs 300 MB Traefik)
- **Documentation riche** : Guides communautaires nombreux

**❌ Inconvénients** :
- **Pas d'auto-discovery** : Faut créer manuellement chaque proxy host
- **Moins flexible** : Pas de middlewares avancés (vs Traefik)
- **UI = single point of failure** : Si NPM down, config immutable

### Traefik (v3) - Évaluation initiale

**✅ Avantages** :
- **Auto-discovery Docker** : Labels sur containers → routes automatiques
- **Middlewares puissants** : Rate-limiting, authentication, compression
- **Dashboard intégré** : Visualisation routes en temps réel
- **Cloud-native** : Support Kubernetes, Consul, Nomad
- **Hot-reload** : Pas de redémarrage pour changement config

**❌ Inconvénients** (raisons abandon) :
- **Complexité** : YAML + labels Docker + middlewares = courbe apprentissage
- **Debugging difficile** : Logs cryptiques, routing parfois imprévisible
- **Multi-VM compliqué** : Traefik découvre containers locaux, pas services sur autres VMs
- **Documentation fragmentée** : v3 récent, exemples v2 obsolètes
- **Overhead** : Auto-discovery = polling constant (CPU/RAM)

### Caddy (v2)

**✅ Avantages** :
- **HTTPS automatique** : Certificats Let's Encrypt sans config
- **Caddyfile simple** : Syntaxe lisible (vs Nginx conf)
- **Léger** : ~100 MB RAM
- **HTTP/3 natif** : Support QUIC intégré

**❌ Inconvénients** :
- **Jeune** : Moins de communauté que Nginx/Traefik
- **Pas d'UI** : Configuration fichiers uniquement (vs NPM interface web)
- **Modules limités** : Ecosystem moins riche que Nginx

### HAProxy

**✅ Avantages** :
- **Performance** : Load-balancing ultra-optimisé
- **Fiabilité** : Utilisé par GitHub, Stack Overflow, Reddit

**❌ Inconvénients** :
- **Overkill** : Conçu pour datacenters (vs homelab simple)
- **Config complexe** : Syntaxe archaïque
- **Pas de gestion SSL native** : Faut certbot externe

---

## 📊 Tableau décisionnel (mise à jour)

| Critère | NPM | Traefik v3 | Caddy v2 | HAProxy |
|---------|-----|------------|----------|---------|
| **Facilité setup** | ⭐⭐⭐⭐⭐ (UI) | ⭐⭐ (YAML) | ⭐⭐⭐⭐ (Caddyfile) | ⭐ (complexe) |
| **SSL automatique** | ⭐⭐⭐⭐⭐ (1 clic) | ⭐⭐⭐⭐ (auto) | ⭐⭐⭐⭐⭐ (auto) | ⭐⭐ (certbot) |
| **Multi-VM support** | ⭐⭐⭐⭐⭐ | ⭐⭐ (compliqué) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Performance** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Logs/monitoring** | ⭐⭐⭐⭐⭐ (UI) | ⭐⭐⭐⭐ (dashboard) | ⭐⭐⭐ (fichiers) | ⭐⭐ (stats port) |
| **Ressources** | ⭐⭐⭐⭐ (200 MB) | ⭐⭐⭐ (300 MB) | ⭐⭐⭐⭐⭐ (100 MB) | ⭐⭐⭐⭐ (150 MB) |
| **Documentation** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ (v3 récent) | ⭐⭐⭐⭐ | ⭐⭐ (obsolète) |
| **Communauté** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

**Score total** :
- **NPM : 37/40** ✅ (choix final)
- Traefik v3 : 27/40
- Caddy v2 : 33/40
- HAProxy : 26/40

---

## 🎯 Justification du choix (révision)

### Pourquoi NPM remplace Traefik

**Tests pratiques (20-25/10/2025)** :

1. **Setup Traefik (3h)** :
   ```yaml
   # docker-compose.yml (extrait)
   traefik:
     image: traefik:v3
     command:
       - "--providers.docker=true"
       - "--entrypoints.web.address=:80"
       - "--entrypoints.websecure.address=:443"
       - "--certificatesresolvers.myresolver.acme.email=admin@elmzn.be"
     labels:
       - "traefik.enable=true"
   
   jellyfin:
     image: jellyfin/jellyfin
     labels:
       - "traefik.http.routers.jellyfin.rule=Host(`media.elmzn.be`)"
       - "traefik.http.routers.jellyfin.entrypoints=websecure"
       - "traefik.http.routers.jellyfin.tls.certresolver=myresolver"
   ```
   
   **Problèmes rencontrés** :
   - ❌ Traefik ne voit que containers locaux (VM-EXTRANET)
   - ❌ Jellyfin sur VM-INTRANET = pas auto-découvert
   - ❌ Fallback : Traefik file provider (TOML/YAML complexe)
   - ❌ Certificat wildcard *.elmzn.be = challenge DNS-01 manuel

2. **Setup NPM (30 min)** :
   ```yaml
   # docker-compose.yml (extrait)
   npm:
     image: jc21/nginx-proxy-manager:latest
     ports:
       - 80:80
       - 443:443
       - 81:81  # Admin UI
     volumes:
       - ./data:/data
       - ./letsencrypt:/etc/letsencrypt
   ```
   
   **Interface web (http://192.168.1.100:81)** :
   1. Proxy Hosts → Add Proxy Host
   2. Domain : `media.elmzn.be`
   3. Forward Hostname : `192.168.1.101` (VM-INTRANET)
   4. Forward Port : `8096` (Jellyfin)
   5. SSL → Request SSL Certificate (Let's Encrypt)
   6. ✅ Certificat généré en 30s, routing OK

   **Résultat** : **media.elmzn.be fonctionne immédiatement**, HTTPS valide.

**Conclusion** : NPM est **10x plus simple** pour architecture multi-VM.

### Avantages spécifiques NPM pour ce projet

1. **Multi-VM natif** :
   - NPM sur VM-EXTRANET (192.168.1.100)
   - Forward vers VM-INTRANET (192.168.1.101)
   - Pas besoin auto-discovery (services connus à l'avance)

2. **Gestion centralisée** :
   - Tous les proxy hosts dans une UI
   - Logs accessibles sans SSH
   - Modifications sans redémarrage Nginx

3. **Certificats SSL simplifiés** :
   - Let's Encrypt HTTP-01 automatique
   - Wildcard *.elmzn.be via DNS-01 (plugin OVH)
   - Renouvellement auto tous les 60j

4. **Sécurité intégrée** :
   - Access Lists (IP whitelist/blacklist)
   - Basic Auth pour services sensibles
   - Rate-limiting par IP

5. **Monitoring** :
   - Dashboard avec stats traffic
   - Logs 404, 502, SSL errors
   - Intégration possible avec Prometheus

---

## 📦 Configuration retenue (02/11/2025)

### Déploiement NPM (VM-EXTRANET)

```yaml
# /opt/npm/docker-compose.yml (VM-EXTRANET 192.168.1.100)

services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: npm
    restart: unless-stopped
    ports:
      - 80:80      # HTTP (redirect → HTTPS)
      - 443:443    # HTTPS
      - 81:81      # Admin UI
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    environment:
      DB_SQLITE_FILE: /data/database.sqlite
    networks:
      - npm-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:81/api"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  npm-net:
    driver: bridge
```

**Démarrage** :
```bash
cd /opt/npm
docker compose up -d
```

**Accès admin** :
- URL : http://192.168.1.100:81
- Email : admin@example.com
- Password : changeme (à changer 1er login)

### Proxy Hosts configurés

**Jellyfin (media.elmzn.be)** :
```yaml
Domain Names: media.elmzn.be
Scheme: http
Forward Hostname/IP: 192.168.1.101 (VM-INTRANET)
Forward Port: 8096
Block Common Exploits: ✅
Websockets Support: ✅
SSL:
  - Force SSL: ✅
  - HTTP/2 Support: ✅
  - HSTS Enabled: ✅
  - Certificate: Let's Encrypt (auto-renew)
```

**Immich (photos.elmzn.be)** :
```yaml
Domain Names: photos.elmzn.be
Scheme: http
Forward Hostname/IP: 192.168.1.101
Forward Port: 2283
Block Common Exploits: ✅
Websockets Support: ✅
SSL:
  - Force SSL: ✅
  - HTTP/2 Support: ✅
  - HSTS Enabled: ✅
  - Certificate: Let's Encrypt (auto-renew)
```

**Grafana (grafana.elmzn.be)** :
```yaml
Domain Names: grafana.elmzn.be
Scheme: http
Forward Hostname/IP: 192.168.1.101
Forward Port: 3000
Block Common Exploits: ✅
Websockets Support: ✅
Access List: LAN + VPN only (192.168.1.0/24, 10.8.0.0/24)
SSL:
  - Force SSL: ✅
  - HTTP/2 Support: ✅
  - Certificate: Let's Encrypt (auto-renew)
```

### Certificats SSL wildcard (optionnel)

**Plugin OVH pour DNS-01 challenge** :

```bash
# Depuis container NPM
docker exec -it npm bash

# Installer plugin certbot OVH
pip install certbot-dns-ovh

# Config OVH API
cat > /etc/letsencrypt/ovhapi.ini <<EOF
dns_ovh_endpoint = ovh-eu
dns_ovh_application_key = VOTRE_APP_KEY
dns_ovh_application_secret = VOTRE_APP_SECRET
dns_ovh_consumer_key = VOTRE_CONSUMER_KEY
EOF

chmod 600 /etc/letsencrypt/ovhapi.ini

# Générer certificat wildcard
certbot certonly \
  --dns-ovh \
  --dns-ovh-credentials /etc/letsencrypt/ovhapi.ini \
  -d elmzn.be \
  -d *.elmzn.be \
  --agree-tos \
  --email admin@elmzn.be

# Certificat créé dans /etc/letsencrypt/live/elmzn.be/
```

**Intégration NPM** :
1. NPM → SSL Certificates → Add Certificate
2. Type : Custom
3. Upload `fullchain.pem` + `privkey.pem`
4. Assigner certificat wildcard à tous les proxy hosts

---

## 🔒 Sécurité

### Access Lists (NPM)

**Création liste "LAN + VPN"** :
```yaml
Name: LAN_VPN_Access
Pass Auth: No (pas d'auth supplémentaire si IP autorisée)
Satisfy Any: Yes (IP OU user/pass)

Access:
  Allow 192.168.1.0/24   # LAN local
  Allow 10.8.0.0/24       # OpenVPN clients
  Deny all               # Bloquer reste du monde
```

**Application** :
- Grafana → Access List : LAN_VPN_Access
- Prometheus → Access List : LAN_VPN_Access
- NPM Admin UI → Access List : LAN_VPN_Access

**Effet** : Services sensibles accessibles uniquement depuis LAN ou VPN.

### Rate-limiting (Nginx custom config)

**NPM → Proxy Host → Advanced** :
```nginx
# Rate limit: 10 req/s par IP
limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;
limit_req zone=mylimit burst=20 nodelay;

# Ban après 100 req/min
limit_req_status 429;
```

### Headers de sécurité

**NPM → Proxy Host → Advanced** :
```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

# HSTS (Force HTTPS 1 an)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

---

## 📊 Résultats mesurés

### Performance (benchmarks ApacheBench)

**Test** : 1000 requêtes, 10 concurrentes sur media.elmzn.be :

```bash
ab -n 1000 -c 10 https://media.elmzn.be/
```

**Résultats NPM** :
- Requests/sec : **245 req/s**
- Time/request : 40 ms (mean)
- 99th percentile : 120 ms
- Failed requests : 0

**Comparaison Traefik (tests précédents)** :
- Requests/sec : 220 req/s
- Time/request : 45 ms
- 99th percentile : 140 ms

**Conclusion** : NPM légèrement plus rapide que Traefik (Nginx optimisé).

### Consommation ressources (idle + charge)

| Metric | NPM idle | NPM charge | Traefik idle | Traefik charge |
|--------|----------|------------|--------------|----------------|
| **RAM** | 180 MB | 320 MB | 280 MB | 450 MB |
| **CPU** | 0.5% | 12% | 1.2% | 18% |
| **Disk I/O** | 0 MB/s | 2 MB/s | 0 MB/s | 3 MB/s |

**Conclusion** : NPM ~40% moins gourmand en RAM que Traefik.

---

## 🔮 Évolution future

### Migration vers Traefik (si besoin)

**Cas où Traefik redevient pertinent** :
1. Migration Docker Swarm / Kubernetes (auto-discovery utile)
2. >20 services (config NPM devient lourde)
3. Besoin middlewares avancés (circuit breaker, retry, canary)

**Script migration** :
```bash
# Export configs NPM vers Traefik
# (script custom à développer)
./npm-to-traefik-converter.sh

# Génère fichiers Traefik
# - traefik.yml (entrypoints, providers)
# - dynamic/*.yml (routes, middlewares)
```

### HAProxy (si performance critique)

**Si traffic >1000 req/s** :
- Remplacer NPM par HAProxy
- Configuration manuelle (fichier .cfg)
- Trade-off : Performance vs simplicité

---

## 🔗 Références

- [Nginx Proxy Manager docs](https://nginxproxymanager.com/guide/)
- [Traefik v3 documentation](https://doc.traefik.io/traefik/)
- [NPM vs Traefik comparison](https://github.com/NginxProxyManager/nginx-proxy-manager/discussions/1234)
- [Let's Encrypt DNS-01 challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)

---

## ✅ Validation (révision)

**Critères d'acceptation** :
- [x] NPM déployé sur VM-EXTRANET
- [x] Proxy hosts configurés (Jellyfin, Immich, Grafana)
- [x] Certificats SSL Let's Encrypt valides
- [x] Access Lists fonctionnelles (LAN + VPN)
- [x] Logs accessibles via UI NPM
- [x] Performance >200 req/s

**Date validation initiale** : 20/10/2025 (Traefik)  
**Date révision** : 02/11/2025 (NPM)  
**Testeur** : Équipe projet  
**Résultat** : ✅ Accepté (NPM remplace Traefik)

---

## 📝 Mises à jour

| Date | Auteur | Changement |
|------|--------|------------|
| 20/10/2025 | Équipe | Création ADR (Traefik choisi) |
| 25/10/2025 | Équipe | Tests Traefik (problèmes multi-VM) |
| 02/11/2025 | Équipe | Révision ADR : NPM remplace Traefik |