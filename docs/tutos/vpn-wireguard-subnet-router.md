# 🧩 VPN WireGuard (subnet-router) — Mise en place pas à pas

> **Ce que tu obtiens :** un accès chiffré à **tout ton LAN homelab** depuis l'extérieur (4G, réseau d'un ami…), comme si tu étais à la maison — sans exposer aucun service publiquement.

| | |
|---|---|
| 🎯 Résultat | Depuis n'importe où, tu atteins `192.168.1.0/24` (Immich, NPM, Stremio…) via le VPN |
| ⏱️ Durée | ~45 min |
| 📊 Niveau | Intermédiaire |
| 🧩 Pré-requis | Un hôte **Proxmox allumé 24/7** · un **nom DDNS** qui suit ton IP publique · accès admin à ta **box** |
| 🔗 Décisions liées | [ADR-010 — DNS public + DDNS OVH](../ADR/010-DNS%20public%20avec%20DDNS%20dynamique%20elmzn.be%20+%20OVH.md) · [ADR-002 — Docker vs LXC](../ADR/002-docker-vs-lxc.md) · [ADR-014 — Architecture 2 machines](../ADR/014-architecture-2-machines.md) |

## 🗺️ Ce qu'on construit

Un **LXC dédié** sur le Beelink (allumé 24/7) fait tourner **wg-easy** (WireGuard + interface web). Il s'annonce comme **routeur de sous-réseau** : les clients VPN atteignent tout le LAN sans toucher à la config des autres machines.

```
Internet ──UDP 51820──▶ Box FAI ──port-forward──▶ Beelink 24/7 (pve-extranet, .100)
                                                     │
                                          LXC 103 « wireguard » (Docker)
                                          • wg-easy (GUI + QR codes)
                                          • route 192.168.1.0/24
                                                     │
   Clients (Android TV / téléphone / PC) ──VPN──▶ tout le LAN
                                               → Immich, NPM, Stremio…
```

**Pourquoi WireGuard auto-hébergé** (plutôt qu'un service tiers type ZeroTier/Tailscale) : voie 100 % souveraine, aucun cloud externe. **Pourquoi un subnet-router** : un seul tunnel donne accès à tout le homelab, pas juste à un service.

---

## ⛔ Étape 0 — Vérifier l'absence de CGNAT (bloquant)

*Pourquoi :* WireGuard auto-hébergé **exige** un port-forward entrant, qui ne marche **que** si ta box a une vraie IP publique. Si ton opérateur fait du CGNAT (double-NAT), c'est impossible — à vérifier **avant** toute construction.

```bash
curl -4 ifconfig.me      # ton IP publique vue depuis Internet
traceroute -n 8.8.8.8    # regarde le saut n°2
```

🔎 **Résultat attendu** (lecture du traceroute)
```
1  192.168.1.1        ← ta box (passerelle LAN)
2  10.x.x.x           ← réseau interne opérateur (OK)
...
4  <backbone public>  ← IP publique de l'opérateur
```

✅ **Vérifie que :** le saut n°2 n'est **pas** dans la plage `100.64.0.0/10` (`100.64.x.x`–`100.127.x.x`), signature du CGNAT. Un `10.x` est le réseau d'accès interne de l'opérateur, c'est normal.

**Preuve définitive** (si tu héberges déjà un site public) : ouvre-le depuis ton **téléphone en 4G, WiFi coupé**. S'il charge, le trafic entrant atteint ta box → **pas de CGNAT**. 🔴 Si tu es en CGNAT : port-forward impossible, il faut un relais (VPS WireGuard) ou une solution qui traverse le NAT.

> 💡 IP publique **dynamique** ? Il te faut un **DDNS** (un nom qui suit ton IP). Voir [ADR-010](../ADR/010-DNS%20public%20avec%20DDNS%20dynamique%20elmzn.be%20+%20OVH.md). Ici on réutilise un DynHost OVH existant : `home.elmzn.be`.

---

## 🚶 Étape 1 — Créer le LXC WireGuard

*Pourquoi :* un conteneur isolé pour WireGuard (séparation des responsabilités), non-privilégié pour la sécurité, avec accès au device `/dev/net/tun`.

Sur l'hôte Proxmox (`pve-extranet`, `192.168.1.100`) :

```bash
# 1. Charger le module noyau WireGuard (+ persistant après reboot)
modprobe wireguard && lsmod | grep wireguard
echo "wireguard" > /etc/modules-load.d/wireguard.conf

# 2. Créer le LXC (adapte VMID / IP / template à ton infra)
pct create 103 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname wireguard --cores 1 --memory 512 --swap 512 \
  --rootfs local-lvm:4 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.113/24,gw=192.168.1.1 \
  --nameserver 1.1.1.1 \
  --features nesting=1,keyctl=1 --unprivileged 1 --onboot 1 --start 0

# 3. Passer le device TUN dans le conteneur (avant le 1er démarrage)
cat >> /etc/pve/lxc/103.conf <<'EOF'
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF

# 4. Démarrer et vérifier
pct start 103
pct exec 103 -- ls -l /dev/net/tun
pct exec 103 -- ping -c2 deb.debian.org
```

🔎 **Résultat attendu**
```
crw-rw-rw- 1 nobody nogroup 10, 200 ... /dev/net/tun
64 bytes from ...: icmp_seq=1 ttl=59 time=7.6 ms
```

✅ **Vérifie que :** le device `/dev/net/tun` (10:200) est présent **dans** le conteneur, et que le ping résout (DNS OK) — indispensable pour installer Docker juste après.

> `nesting=1` + `keyctl=1` = nécessaires pour faire tourner Docker dans un LXC. `onboot=1` = le VPN doit redémarrer tout seul (c'est ta passerelle d'accès distant).

---

## 🚶 Étape 2 — Installer Docker + wg-easy

*Pourquoi :* wg-easy se déploie en conteneur Docker (image officielle, interface web + QR codes).

Entre dans le conteneur (`pct enter 103`), puis :

```bash
# Docker
apt update && apt -y install curl
curl -fsSL https://get.docker.com | sh
docker run --rm hello-world        # doit afficher "Hello from Docker!"

# wg-easy via le compose officiel (téléchargé, jamais collé : voir Dépannage)
mkdir -p /opt/wg-easy && cd /opt/wg-easy
curl -fsSL https://raw.githubusercontent.com/wg-easy/wg-easy/master/docker-compose.yml -o docker-compose.yml

# Override pour autoriser l'interface en HTTP sur le LAN
printf 'services:\n  wg-easy:\n    environment:\n      - INSECURE=true\n' > docker-compose.override.yml

docker compose config >/dev/null && echo "YAML OK"
docker compose up -d
docker compose ps
```

🔎 **Résultat attendu**
```
YAML OK
NAME      IMAGE                        STATUS                    PORTS
wg-easy   ghcr.io/wg-easy/wg-easy:15   Up (healthy)              0.0.0.0:51820->51820/udp, 0.0.0.0:51821->51821/tcp
```

✅ **Vérifie que :** `hello-world` affiche bien son message (preuve que Docker tourne dans le LXC non-privilégié), et que le conteneur `wg-easy` est **Up**, ports `51820/udp` (WireGuard) et `51821/tcp` (interface web) mappés.

---

## 🚶 Étape 3 — Assistant de configuration wg-easy

*Pourquoi :* wg-easy v15 se configure au premier lancement via un assistant web (compte admin + endpoint).

Depuis un PC du LAN, ouvre :
```
http://192.168.1.113:51821
```

Suis l'assistant :
1. **Compte admin** : choisis un identifiant + un mot de passe solide (c'est ton accès à la GUI).
2. **Existing Setup ?** → **No** (nouvelle installation).
3. **Host Setup** :
   - **Host** = `home.elmzn.be`  *(ton nom DDNS — l'endpoint que les clients utiliseront)*
   - **Port** = `51820`

✅ **Vérifie que :** après l'assistant, tu arrives sur le panneau admin de wg-easy.

---

## 🚶 Étape 4 — Créer un client + activer le subnet-routing

*Pourquoi :* le réglage **Allowed IPs** du client décide quel trafic passe dans le tunnel. Pour atteindre le LAN, il doit inclure `192.168.1.0/24`.

Dans le panneau admin :
1. **Add a new client** → nomme-le (ex. `phone`).
2. Ouvre ses réglages → champ **Allowed IPs** → mets :
   ```
   192.168.1.0/24
   ```

**Split tunnel vs full tunnel :**

| Allowed IPs | Effet |
|-------------|-------|
| `192.168.1.0/24` *(recommandé)* | **Split tunnel** : seul le trafic homelab passe par le VPN, le reste d'Internet garde sa route normale. Léger. |
| `0.0.0.0/0, ::/0` | **Full tunnel** : *tout* le trafic du client sort par la maison (utile pour masquer ton IP partout). |

✅ **Vérifie que :** dans la config du client (QR / fichier), la ligne `Endpoint = home.elmzn.be:51820` et `AllowedIPs` contient `192.168.1.0/24`.

---

## 🚶 Étape 5 — Rediriger le port sur la box

*Pourquoi :* sans port-forward, le trafic VPN entrant n'atteint jamais le LXC.

Dans l'admin de ta box (`http://192.168.1.1`, section *Redirection de ports / NAT*), ajoute :

| Champ | Valeur |
|-------|--------|
| Protocole | **UDP** |
| Port externe (WAN) | **51820** |
| IP interne | **192.168.1.113** |
| Port interne | **51820** |

✅ **Vérifie que :** la règle est enregistrée et active.

---

## ✅ Test final (depuis la 4G)

1. Sur le téléphone : installe l'app **WireGuard** officielle.
2. wg-easy → **QR code** du client `phone`.
3. App WireGuard → **+** → *Scanner depuis QR code* → ajoute le tunnel.
4. **Coupe le WiFi, active la 4G/5G**, puis **active le tunnel**.
5. Deux niveaux de preuve :
   - App WireGuard → **Latest handshake** affiche un horodatage récent + des octets échangés → le **tunnel est monté** (port-forward + DDNS OK).
   - Ouvre `http://192.168.1.113:51821` (l'admin wg-easy) **puis** une autre machine du LAN, ex. `http://192.168.1.111:81` (NPM). Si les deux chargent en 4G → **subnet-routing complet validé** : tu atteins n'importe quelle IP du `192.168.1.0/24`.

> Teste une machine **allumée 24/7** : une cible éteinte donnerait un faux négatif (injoignable parce qu'éteinte, pas à cause du VPN).

---

## 🆘 Dépannage

| Symptôme | Cause probable | Fix |
|----------|----------------|-----|
| `docker: command not found` | Docker pas (encore) installé | Refais l'install Docker de l'Étape 2 |
| `yaml: ... did not find expected key` au `docker compose up` | Le terminal a mangé l'indentation au **collage** du YAML | Ne colle jamais de YAML multi-lignes : `curl` le compose, `printf` les overrides (comme dans ce tuto) |
| `docker compose up` plante sur `ip6tables` / IPv6 | IPv6 Docker pas dispo dans le LXC | Retire le réseau IPv6 du compose (variante IPv4-only) |
| Aucun handshake depuis la 4G | Port-forward box absent/erroné, **ou** opérateur qui filtre 51820, **ou** CGNAT | Revérifie l'Étape 5 ; teste un autre port UDP ; refais l'Étape 0 |
| `.113` joignable mais pas les autres machines | Cible éteinte, **ou** `AllowedIPs` n'inclut pas `192.168.1.0/24` | Teste une machine 24/7 ; corrige les Allowed IPs (Étape 4) |

> ℹ️ **Routage automatique :** aucune règle `iptables`/MASQUERADE manuelle n'est nécessaire. wg-easy masque le client derrière le conteneur, et le bridge Docker masque le conteneur derrière l'IP du LXC (`192.168.1.113`) en sortie vers le LAN. Double-NAT transparent.

---

## ➡️ Et après

- **Ajouter tes autres appareils** (Android TV, PC) : même méthode QR, mêmes Allowed IPs `192.168.1.0/24`.
- **Sécuriser l'interface wg-easy** : la passer derrière NPM en HTTPS (elle n'est de toute façon joignable que via LAN/VPN).
- **Fiabiliser le DDNS** : s'assurer qu'un client met activement à jour `home.elmzn.be` — sinon, un changement d'IP coupe l'accès. Voir [ADR-010](../ADR/010-DNS%20public%20avec%20DDNS%20dynamique%20elmzn.be%20+%20OVH.md).
- **Tuto Stremio** *(à venir)* : une fois déployé, il sera accessible via ce VPN sans config supplémentaire (juste une IP de plus dans le `192.168.1.0/24`).
