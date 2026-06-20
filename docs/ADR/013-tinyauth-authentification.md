# ADR 013 : TinyAuth pour authentification NPM

## Statut
📋 **Planifié** - À implémenter (prochaine session)

## Contexte

Nginx Proxy Manager (NPM) exposera plusieurs services sur Internet via HTTPS :
- **Public :** Jellyfin, sites web personnels
- **Semi-privé :** Immich (photos famille)
- **Sensible :** Grafana (monitoring), NPM dashboard, Vaultwarden

**Problématique :** Comment protéger l'accès à ces services contre les accès non autorisés ?

### Besoins identifiés
1. **Authentification avant accès** : Utilisateur doit s'identifier avant de voir le service
2. **Gestion multi-utilisateurs** : Admin + famille (3-4 comptes)
3. **Compatible NPM** : Forward auth ou intégration native
4. **Léger** : VM-EXTRANET limitée à 4 GB RAM
5. **Simple** : Maintenance minimale (projet homelab personnel)

### Services à protéger

| Service | Niveau protection | Besoin auth |
|---------|-------------------|-------------|
| Jellyfin | Public | ❌ Auth native Jellyfin |
| Sites web | Public | ❌ Pas d'auth nécessaire |
| Immich | Semi-privé | ✅ Auth requis |
| Grafana | Sensible | ✅ Auth requis + VPN recommandé |
| Vaultwarden | Critique | ✅ VPN ONLY (pas via NPM) |
| NPM Dashboard | Critique | ✅ Auth requis + access list IP |

---

## Décision

**Utiliser TinyAuth comme solution d'authentification pour Nginx Proxy Manager.**

### Principe de fonctionnement
```
Internet → NPM (port 443)
           ↓
      [TinyAuth]
           ↓ (si auth OK)
      Reverse proxy → Service (INTRANET)
```

**Flow d'authentification :**
1. User accède à `https://photos.elmzn.be`
2. NPM redirige vers TinyAuth
3. TinyAuth affiche formulaire login
4. User entre credentials (username + password)
5. Si OK : TinyAuth crée session cookie
6. NPM autorise accès au service

---

## Alternatives considérées

### 1. Authelia ❌ (trop complexe)

**Description :** Solution complète d'authentification et autorisation.

**Avantages :**
- ✅ Très complet (2FA, LDAP, OIDC, etc.)
- ✅ Communauté large et active
- ✅ Documentation exhaustive
- ✅ Support de nombreux backends (LDAP, SQL, etc.)

**Inconvénients :**
- ❌ **Overkill pour homelab** : Fonctionnalités enterprise inutiles ici
- ❌ **Complexe à configurer** : Fichier YAML ~200 lignes minimum
- ❌ **Lourd en ressources** : ~150 MB RAM (vs ~20 MB TinyAuth)
- ❌ **Dépendances** : Redis requis (ajoute complexité)

**Verdict :** Trop complexe pour un usage personnel/familial.

---

### 2. OAuth2 Proxy ❌ (dépendance externe)

**Description :** Authentification via providers externes (Google, GitHub, etc.).

**Avantages :**
- ✅ Pas de gestion de passwords (délégué à Google/GitHub)
- ✅ 2FA inclus (via provider)
- ✅ Simple pour les users (compte existant)

**Inconvénients :**
- ❌ **Dépendance externe** : Si Google down, pas d'accès
- ❌ **Privacy** : Google/GitHub sait quand tu accèdes à tes services
- ❌ **Pas de contrôle total** : Dépend des CGU des providers
- ❌ **Internet requis** : Pas d'auth si coupure Internet

**Verdict :** Perte d'autonomie et de privacy, incompatible avec philosophie self-hosted.

---

### 3. Authentification basique NPM ❌ (insuffisant)

**Description :** Auth HTTP Basic ou Access Lists intégrés à NPM.

**Avantages :**
- ✅ Intégré à NPM (pas de service supplémentaire)
- ✅ Simple à configurer (quelques clics)

**Inconvénients :**
- ❌ **HTTP Basic = popup moche** : Mauvaise UX
- ❌ **Pas de 2FA** : Seulement username + password
- ❌ **Access Lists = IP only** : Pas pratique (IP dynamiques)
- ❌ **Pas de session management** : Credentials envoyés à chaque requête

**Verdict :** Sécurité et UX insuffisantes.

---

### 4. TinyAuth ✅ (choisi)

**Description :** Solution d'authentification minimaliste et légère.

**Avantages :**
- ✅ **Simple** : Configuration en 10 minutes
- ✅ **Léger** : ~20 MB RAM (vs 150 MB Authelia)
- ✅ **Pas de dépendances** : Self-contained, pas de Redis/DB
- ✅ **Forward auth** : Compatible NPM out-of-the-box
- ✅ **Suffisant pour homelab** : Répond à tous les besoins identifiés
- ✅ **Self-hosted complet** : Aucune dépendance externe

**Inconvénients :**
- ⚠️ **Moins de features** : Pas de LDAP, pas de 2FA (acceptable pour homelab)
- ⚠️ **Communauté plus petite** : Moins de ressources que Authelia
- ⚠️ **Pas de 2FA natif** : Peut être ajouté via Nginx (si vraiment nécessaire)

**Verdict :** Meilleur compromis simplicité/sécurité pour usage personnel.

---

## Conséquences

### Positives ✅

1. **Simplicité opérationnelle**
   - Installation : 1 conteneur Docker
   - Configuration : ~20 lignes (fichier config + users)
   - Maintenance : Aucune (stable une fois configuré)

2. **Légèreté**
   - RAM : ~20 MB (vs 150 MB Authelia)
   - CPU : <1% en idle
   - Disque : ~10 MB

3. **Suffisance fonctionnelle**
   - Multi-utilisateurs : ✅ (admin + 3-4 famille)
   - Session management : ✅ (cookies sécurisés)
   - Forward auth NPM : ✅ (compatible direct)
   - Logout : ✅
   - Password hashing : ✅ (bcrypt)

4. **Self-hosted complet**
   - Pas de dépendance externe
   - Contrôle total des données
   - Fonctionne offline (après premier déploiement)

### Négatives ⚠️

1. **Pas de 2FA natif**
   - **Risque :** Moins sécurisé qu'Authelia avec 2FA
   - **Mitigation :** 
     - Passwords forts obligatoires (16+ caractères)
     - Fail2ban sur NPM (ban après 5 tentatives)
     - VPN requis pour Vaultwarden (jamais via NPM)
     - Accès depuis Internet limité (IP whitelisting si nécessaire)

2. **Communauté plus petite**
   - **Risque :** Moins de support si problème
   - **Mitigation :** 
     - Code simple (facile à débugger)
     - Fallback : Authelia si vraiment nécessaire (migration possible)

3. **Pas de features avancées**
   - Pas de LDAP (inutile pour 4 users)
   - Pas de OIDC (pas de besoin identifié)
   - Pas de règles ACL complexes (pas nécessaire)

**Verdict :** Inconvénients acceptables pour un homelab personnel.

---

## Implémentation prévue

### Architecture
```
VM-EXTRANET (192.168.1.111)
├─ Docker containers
│  ├─ NPM (ports 80/443)
│  │  └─ Forward auth → TinyAuth
│  │
│  └─ TinyAuth (port 8085)
│     ├─ Config : /mnt/appdata/tinyauth/config.yml
│     └─ Users : admin, user1, user2, user3
│
└─ Config NPM (per proxy host)
   └─ Advanced → Forward auth to http://tinyauth:8085
```

### Configuration TinyAuth

**`/mnt/appdata/tinyauth/config.yml`**
```yaml
# TinyAuth configuration
listen: ":8085"
cookie_domain: ".elmzn.be"
cookie_secret: "CHANGE_ME_RANDOM_64_CHARS"
session_timeout: 2592000  # 30 days

users:
  - username: admin
    password: "$2a$10$HASHED_PASSWORD_BCRYPT"  # bcrypt hash
    
  - username: markus
    password: "$2a$10$HASHED_PASSWORD_BCRYPT"
    
  - username: famille1
    password: "$2a$10$HASHED_PASSWORD_BCRYPT"
```

### Configuration NPM (per proxy host)

**Exemple : Immich (photos.elmzn.be)**
```
Advanced tab:
├─ Forward auth URL: http://tinyauth:8085/auth
├─ Forward auth sign-in URL: http://tinyauth:8085/login
└─ Custom Nginx Config:
    proxy_set_header X-Forwarded-User $auth_user;
```

### Utilisateurs prévus

| Username | Rôle | Accès |
|----------|------|-------|
| admin | Administrateur | Tous services + NPM dashboard |
| markus | Propriétaire | Tous services sauf NPM dashboard |
| famille1 | Famille | Jellyfin + Immich uniquement |
| famille2 | Famille | Jellyfin + Immich uniquement |

---

## Plan de déploiement

### Phase 1 : Installation (15 min)
```bash
# VM-EXTRANET
cd /opt/extranet

# Ajouter au docker-compose.yml
docker compose up -d tinyauth

# Générer hash passwords
docker exec -it tinyauth htpasswd -bnBC 10 "" "password123" | tr -d ':\n'

# Configurer users dans config.yml
nano /mnt/appdata/tinyauth/config.yml
```

### Phase 2 : Configuration NPM (10 min par service)
- Immich : Forward auth activé
- Grafana : Forward auth activé
- NPM Dashboard : Forward auth + IP whitelist

### Phase 3 : Tests (15 min)
- ✅ Login successful
- ✅ Logout successful
- ✅ Session cookie persiste (30 jours)
- ✅ Accès refusé si pas authentifié
- ✅ Fail2ban ban après 5 tentatives

---

## Références

- [TinyAuth GitHub](https://github.com/bradrydzewski/tinyauth) (exemple, adapter au vrai projet)
- [Nginx Proxy Manager - Forward Auth](https://nginxproxymanager.com/advanced-config/#forward-auth)
- [Fail2ban avec NPM](https://github.com/NginxProxyManager/nginx-proxy-manager/wiki/Fail2Ban)

---

## Décision prise par
- Markus (propriétaire projet)

## Date
11 novembre 2025

## Implémentation prévue
Prochaine session (déploiement VM-EXTRANET)

## Révision prévue
Après 6 mois d'utilisation : Évaluer si besoin de migrer vers Authelia (2FA) ou rester sur TinyAuth.