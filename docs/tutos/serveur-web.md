# 🌐 Serveur web (Nginx + NPM) — héberger plusieurs sites

> **Ce que tu obtiens :** un LXC qui sert **plusieurs sites** (statique, React, Next.js SSR) derrière Nginx, exposés sur Internet en **HTTPS** via Nginx Proxy Manager + Let's Encrypt.

| | |
|---|---|
| 🎯 Résultat | `elmzn.be` et ses sous-domaines servis publiquement en HTTPS, multi-sites sur un seul LXC |
| ⏱️ Durée | ~2 h (1er site) · ~10 min par site suivant |
| 📊 Niveau | Intermédiaire |
| 🧩 Pré-requis | Un hôte Proxmox ([tuto](installer-proxmox.md)) · un nom de domaine (zone DNS OVH) · ports 80/443 forwardés depuis la box |
| 🔗 Décisions liées | [ADR-002 — Docker vs LXC](../ADR/002-docker-vs-lxc.md) · [ADR-003 — Traefik vs Nginx](../ADR/003-traefik-vs-nginx.md) · [ADR-008 — Architecture EXTRANET/INTRANET](../ADR/008-architecture%20multi-VM%20%20EXTRANET%20+%20INTRANET.md) · [ADR-010 — DNS + DDNS OVH](../ADR/010-DNS%20public%20avec%20DDNS%20dynamique%20elmzn.be%20+%20OVH.md) |

> ℹ️ **Redaction :** l'IP publique est notée `<IP_PUBLIQUE>` dans tout ce tuto — ne jamais l'écrire en clair dans le repo. Les IP `192.168.1.x` sont privées (LAN), donc montrées telles quelles.

## 🗺️ Ce qu'on construit

```
Internet
   │  (DNS OVH : elmzn.be → <IP_PUBLIQUE>, maintenu par DDNS)
   ▼
Box FAI  ──port-forward 80/443──►  VM-EXTRANET 192.168.1.111
                                    └─ Nginx Proxy Manager (NPM)
                                       • reçoit elmzn.be + sous-domaines
                                       • SSL Let's Encrypt (HTTPS)
                                       ▼  (http vers le LAN)
                                   LXC-WEB 192.168.1.112 (ID 102)
                                    └─ Nginx (virtual hosts)
                                       • sites statiques  → fichiers
                                       • Next.js SSR      → reverse proxy → PM2 :3001
```

| Composant | Rôle | IP / Port |
|-----------|------|-----------|
| Hôte Proxmox `pve-extranet` | Hyperviseur (DMZ) | `192.168.1.100:8006` |
| VM-EXTRANET | Nginx Proxy Manager (NPM) | `192.168.1.111` |
| LXC-WEB (ID 102) | Nginx + sites | `192.168.1.112:80` |
| NPM | Reverse proxy + SSL Let's Encrypt | `:80` / `:443` / `:81` (dashboard) |
| OVH DNS | Résolution `elmzn.be` → `<IP_PUBLIQUE>` | — |

> 📚 **Pourquoi cette archi ?** LXC plutôt que VM pour un site web ([ADR-002](../ADR/002-docker-vs-lxc.md)), Nginx plutôt que Traefik ([ADR-003](../ADR/003-traefik-vs-nginx.md)), NPM en DMZ qui ne laisse jamais le LXC exposé en direct ([ADR-008](../ADR/008-architecture%20multi-VM%20%20EXTRANET%20+%20INTRANET.md)).

## 🚶 Étapes

### Étape 1 — Créer le LXC web
*Pourquoi :* un conteneur léger (~50-200 Mo au repos vs ~800 Mo pour une VM) suffit largement pour Nginx.

Depuis le **shell de l'hôte Proxmox** :

```bash
# Récupérer le template Ubuntu 24.04 LTS
pveam update
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst

# Créer le conteneur
pct create 102 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname lxc-web \
  --cores 2 \
  --memory 1536 \
  --swap 512 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.112/24,gw=192.168.1.1 \
  --nameserver 1.1.1.1 \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1 \
  --start 1
```

> 💡 **RAM = 1536 Mo** : 512 Mo suffisent pour Nginx + sites statiques, **mais** un build Next.js peut consommer ~1 Go et se faire tuer (OOM) à 512. On part directement à 1536 pour éviter l'aller-retour.

✅ **Vérifie que :** `pct list` montre `102  lxc-web  running`, puis entre dedans :
```bash
pct enter 102        # prompt attendu : root@lxc-web:~#
```

### Étape 2 — Installer Nginx + le 1er virtual host
*Pourquoi :* Nginx sert les fichiers et route chaque domaine vers le bon site (virtual hosts). Tout ce qui suit s'exécute **dans le LXC**.

```bash
apt update && apt upgrade -y && apt install -y nginx curl

# Dossier du site + permissions (www-data = utilisateur Nginx)
mkdir -p /var/www/elmzn.be
chown -R www-data:www-data /var/www/elmzn.be
chmod -R 755 /var/www/elmzn.be
```

Créer le virtual host `/etc/nginx/sites-available/elmzn.be` :

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name elmzn.be www.elmzn.be;
    root /var/www/elmzn.be;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # En-têtes de sécurité
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    access_log /var/log/nginx/elmzn.be.access.log;
    error_log  /var/log/nginx/elmzn.be.error.log;
}
```

Activer le site :

```bash
ln -s /etc/nginx/sites-available/elmzn.be /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default     # retirer la page par défaut
nginx -t                                   # tester la syntaxe
systemctl reload nginx
```

🔎 **Résultat attendu**
```
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
✅ **Vérifie que :** `curl -H "Host: elmzn.be" http://localhost` renvoie ton HTML (ou un 404 si le dossier est encore vide, mais **pas** la page « Welcome to nginx »).

### Étape 3 — Déployer un site statique
*Pourquoi :* HTML/CSS/JS pur = aucun serveur applicatif, Nginx sert les fichiers directement.

Depuis **ta machine de dev** (pas depuis le LXC) :

```bash
# Copier le contenu du site vers le LXC
rsync -avz ./mon-site/ root@192.168.1.112:/var/www/elmzn.be/

# Corriger les permissions côté serveur
ssh root@192.168.1.112 'chown -R www-data:www-data /var/www/elmzn.be'
```

✅ **Vérifie que :** `http://192.168.1.112` (depuis le LAN) affiche le site. La directive `try_files $uri $uri/ =404;` gère seule tous les fichiers (`/css/style.css`, etc.).

### Étape 4 — Déployer un site React (build statique)
*Pourquoi :* un build React (`npm run build`) produit des fichiers statiques ; il faut juste rediriger toutes les routes vers `index.html` pour le routing côté client.

```bash
# Sur ta machine de dev : builder
npm install && npm run build         # sortie dans ./build (CRA) ou ./dist (Vite)

# Uploader le build
rsync -avz ./build/ root@192.168.1.112:/var/www/app.elmzn.be/
ssh root@192.168.1.112 'chown -R www-data:www-data /var/www/app.elmzn.be'
```

La **seule** différence Nginx vs site statique = le `try_files` qui retombe sur `/index.html` :

```nginx
location / {
    try_files $uri $uri/ /index.html;   # React Router gère le routing
}
```

✅ **Vérifie que :** recharger une route profonde (ex. `/about`) ne renvoie **pas** de 404. Sans ce `try_files`, le rechargement casse.

### Étape 5 — Déployer un site Next.js (SSR)
*Pourquoi :* Next.js en SSR a besoin d'un **serveur Node.js actif** ; Nginx devient reverse proxy vers ce serveur (exemple réel : `portfolio.elmzn.be` sur le port `3001`).

**5.1 — Installer Node.js 20 LTS dans le LXC :**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
node --version        # v20.x.x
```

**5.2 — Activer le mode `standalone`** dans `next.config.js` (sur ta machine de dev) — réduit le déploiement d'environ 70 % :
```js
const nextConfig = { output: 'standalone' }
module.exports = nextConfig
```

**5.3 — Uploader la source (sans `node_modules` ni `.next`)** puis builder sur le serveur :
```bash
# Depuis la machine de dev — JAMAIS scp brut sur node_modules
rsync -avz --exclude='node_modules' --exclude='.next' \
  ./mon-app/ root@192.168.1.112:/var/www/portfolio.elmzn.be/

# Dans le LXC
cd /var/www/portfolio.elmzn.be && npm install && npm run build

# Étape OBLIGATOIRE en standalone : copier les assets dans la sortie
cp -r public      .next/standalone/
cp -r .next/static .next/standalone/.next/
```

**5.4 — Démarrer avec PM2** (maintient Node actif + relance au reboot) :
```bash
npm install -g pm2
PORT=3001 pm2 start .next/standalone/server.js --name 'portfolio'
pm2 startup && pm2 save        # survit aux reboots
pm2 list
```

**5.5 — Nginx en reverse proxy local** (`/etc/nginx/sites-available/portfolio.elmzn.be`) :
```nginx
server {
    listen 80;
    server_name portfolio.elmzn.be;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }
}
```
```bash
ln -s /etc/nginx/sites-available/portfolio.elmzn.be /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

🔎 **Résultat attendu** (`pm2 list`)
```
⚠️ À VÉRIFIER — coller la vraie sortie. Attendu : process « portfolio » en statut « online ».
```
✅ **Vérifie que :** `curl -I http://localhost:3001` répond `HTTP/1.1 200`, et `pm2 list` montre `portfolio  online`.

> 🧭 **Récap des 3 types de sites :**
>
> | Type | Serveur Node ? | `try_files` Nginx | Complexité |
> |------|----------------|-------------------|------------|
> | HTML/CSS/JS pur | Non | `$uri $uri/ =404` | Simple |
> | React (build) | Non | `$uri $uri/ /index.html` | Simple |
> | Next.js SSR | Oui (PM2) | `proxy_pass localhost:3001` | Intermédiaire |

### Étape 6 — Exposer sur Internet via Nginx Proxy Manager
*Pourquoi :* NPM (sur la VM-EXTRANET `.111`) reçoit le trafic Internet, gère le **HTTPS Let's Encrypt** et redirige vers le LXC — le LXC n'est jamais exposé en direct.

> NPM tourne déjà en Docker sur la VM-EXTRANET (voir l'archi). Dashboard : `http://192.168.1.111:81`.

Dans le dashboard NPM → **Proxy Hosts → Add Proxy Host** :

```
Onglet Details :
  Domain Names      : elmzn.be, www.elmzn.be
  Scheme            : http
  Forward Hostname  : 192.168.1.112        (le LXC)
  Forward Port      : 80
  ☑ Block Common Exploits   ☑ Websockets Support

Onglet SSL :
  SSL Certificate   : Request a new SSL certificate
  ☑ Force SSL   ☑ HTTP/2 Support
  ☑ I agree to the Let's Encrypt Terms
```

✅ **Vérifie que :** le proxy host passe au statut **Online** et que le certificat SSL est émis. Pré-requis : le DNS pointe déjà vers `<IP_PUBLIQUE>` (Étape 7) et les ports 80/443 sont forwardés.

### Étape 7 — Configuration DNS (OVH)
*Pourquoi :* faire pointer le domaine vers ton IP publique. Comme l'IP est **dynamique**, un **DDNS** la maintient à jour ([ADR-010](../ADR/010-DNS%20public%20avec%20DDNS%20dynamique%20elmzn.be%20+%20OVH.md)).

Dans le manager OVH → **Domain names → elmzn.be → Zone DNS**, créer les enregistrements **A** :

| Sous-domaine | Type | Cible | TTL |
|--------------|------|-------|-----|
| `@` (racine) | A | `<IP_PUBLIQUE>` | défaut |
| `www` | A | `<IP_PUBLIQUE>` | défaut |
| `portfolio` | A | `<IP_PUBLIQUE>` | défaut |

> 💡 **IP dynamique :** ne pas figer l'IP à la main partout. Un **DynHost OVH** (ou un CNAME vers le host DDNS) met à jour l'IP automatiquement quand le FAI la change — sinon les sites tombent au prochain changement d'IP.

✅ **Vérifie que :** `dig elmzn.be +short` retourne `<IP_PUBLIQUE>` (propagation : 5 min à 24 h).

## ➕ Ajouter un nouveau site (workflow réutilisable)

Une fois la base posée, chaque nouveau site = 6 gestes :

- [ ] Enregistrement **A** dans OVH (`nouveau` → `<IP_PUBLIQUE>`)
- [ ] Dossier : `mkdir -p /var/www/nouveau.elmzn.be`
- [ ] Virtual host : `/etc/nginx/sites-available/nouveau.elmzn.be` (choisir le bon `try_files` selon le type)
- [ ] Activer : `ln -s … && nginx -t && systemctl reload nginx`
- [ ] Uploader les fichiers (`rsync`)
- [ ] **Proxy Host** dans NPM (avec SSL)

## 🧰 Référence rapide

```bash
# --- Hôte Proxmox ---
pct enter 102                 # entrer dans le LXC web
pct set 102 --onboot 1        # autostart

# --- LXC-WEB (Nginx) ---
nginx -t                      # tester la config
systemctl reload nginx        # recharger sans coupure
ls /etc/nginx/sites-enabled/  # sites actifs
tail -f /var/log/nginx/elmzn.be.error.log

# --- Next.js / PM2 ---
pm2 list                      # état des apps
pm2 logs portfolio            # logs en direct
pm2 restart portfolio

# --- NPM (VM-EXTRANET) ---
docker compose -f /opt/extranet/docker-compose.yml ps
docker logs npm --tail 50

# --- Diagnostic réseau ---
dig elmzn.be +short           # résolution DNS
curl -H "Host: elmzn.be" http://192.168.1.112    # tester Nginx via Host header
```

## ✅ Test final

Depuis un **réseau externe** (téléphone en 4G, WiFi coupé) :

```
https://elmzn.be             → le site se charge en HTTPS (cadenas valide)
https://portfolio.elmzn.be   → l'app Next.js répond
```

Si ça charge en 4G avec un certificat valide → DNS + port-forward + NPM + Nginx + (PM2) fonctionnent de bout en bout. 🎉

## 🆘 Dépannage

| Symptôme | Cause probable | Fix |
|----------|----------------|-----|
| Page « Welcome to nginx » | site `default` encore actif | `rm /etc/nginx/sites-enabled/default && systemctl reload nginx` |
| 404 au rechargement d'une route React | `try_files` sans fallback | `try_files $uri $uri/ /index.html;` |
| Let's Encrypt échoue (timeout) | DNS pas propagé / ports 80-443 non forwardés | `dig elmzn.be +short` ; vérifier le port-forward de la box ; tester en 4G |
| Next.js inaccessible après reboot | PM2 pas persisté | `pm2 startup && pm2 save` puis `pm2 restart portfolio` |
| `502 Bad Gateway` sur le sous-domaine Next.js | le process Node est tombé | `pm2 list` → `pm2 restart portfolio` (vérifier d'abord la RAM du LXC) |
| **Depuis le LAN**, le domaine ne passe pas par NPM (HTTP sans SSL) | **Hairpin NAT** | Ajouter `192.168.1.111 portfolio.elmzn.be` dans `C:\Windows\System32\drivers\etc\hosts` (Bloc-notes en admin) pour forcer le passage par NPM |

## ➡️ Et après

- **Si le FAI bloque les ports 80/443** (pas le cas ici — le port-forward fonctionne) : basculer sur un **Cloudflare Tunnel** (`cloudflared` sur la VM-EXTRANET) qui sort en connexion chiffrée sortante, sans aucun port entrant. À garder en plan B.
- Accéder aux **dashboards internes** (NPM `:81`, etc.) depuis l'extérieur sans les exposer → via le [VPN WireGuard](vpn-wireguard-subnet-router.md).
- Poser la base d'un nouvel hôte → [Installer Proxmox VE](installer-proxmox.md).

---

> 🔧 **Reste à figer (vraies sorties à coller) :** `pm2 list` (statut `portfolio`). Le reste = messages déterministes des outils (`nginx -t`, `node --version`) ou étapes GUI.
