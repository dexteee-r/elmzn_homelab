# Migration Machine #1 (EXTRANET) — Dell OptiPlex 7040 → Beelink S12

**Date de rédaction :** 2026-03-21
**Date de migration :** 2026-03-21
**Statut :** ✅ MIGRATION TERMINÉE

> Toutes les valeurs de ce document sont **vérifiées sur les machines réelles**.

---

## 1. État avant migration (ancienne machine)

### Proxmox host (M1 — Dell OptiPlex 7040)

| Champ | Valeur |
|-------|--------|
| Hostname | `pve` |
| IP | `192.168.1.100` |
| Rôle réseau | Passerelle vers le LAN depuis Internet (DMZ / EXTRANET) |
| PVE version | `8.4.14` |
| Kernel | `6.8.12-16-pve` |
| Hardware | Dell OptiPlex 7040, i5-6500, 16 GB RAM, SSD NVMe 256 GB + HDD 500 GB |
| Statut post-migration | ⚠️ Hors réseau (config DHCP ratée) — éteint, non critique |

---

## 2. Nouvelle machine (Beelink S12)

| Champ | Valeur |
|-------|--------|
| Hardware | Beelink S12 Mini PC, Intel N95 (Alder Lake, 12e gen), 16 GB DDR4, SSD 512 GB, LAN 2.5G |
| Hostname | `pve-extranet` |
| IP | `192.168.1.100` |
| PVE version | `9.1` |
| Interface réseau | `nic0` (2.5 Gbps) → bridge `vmbr0` |

---

## 3. Inventaire migré

### VM 101 — `vm-extranet` ✅

| Champ | Valeur |
|-------|--------|
| VMID | 101 |
| Nom | `vm-extranet` |
| OS | Debian 13 Trixie |
| IP | `192.168.1.111` |
| RAM | 4096 MB |
| CPU | 2 cores |
| Disque | 20 GB (local-lvm) |
| MAC | `BC:24:11:2F:D7:90` |
| Statut | running ✅ |

**Docker containers actifs :**

| Conteneur | Image | Ports exposés | Statut |
|-----------|-------|--------------|--------|
| `npm` | jc21/nginx-proxy-manager:latest | 80, 81, 443 | ✅ Up, HTTP 200 OK |

**Services systemd :**

| Service | Statut |
|---------|--------|
| fail2ban | active ✅ |
| UFW | active ✅ |

**Sécurité (UFW + Fail2ban) :**

| Protection | Règle | Statut |
|------------|-------|--------|
| UFW | SSH autorisé LAN uniquement (192.168.1.0/24) | ✅ |
| UFW | HTTP/HTTPS ouvert (Internet) | ✅ |
| UFW | Tout le reste bloqué + IPv6 off | ✅ |
| Fail2ban | SSH : 3 tentatives → ban 24h | ✅ |
| Fail2ban | Nginx auth : 5 tentatives → ban 1h | ✅ |
| Fail2ban | Nginx rate-limit : 10 req → ban 1h | ✅ |

**Proxy hosts NPM configurés :**

| # | Domaine(s) | Destination |
|---|-----------|-------------|
| 1 | `elmzn.be`, `www.elmzn.be` | → `192.168.1.112:80` (LXC lxc-web) |

---

### LXC 102 — `lxc-web` ✅

| Champ | Valeur |
|-------|--------|
| CTID | 102 |
| Hostname | `lxc-web` |
| IP | `192.168.1.112` |
| RAM | 512 MB |
| CPU | 2 cores |
| Disque | 8 GB (local-lvm) |
| Statut | running ✅ |

---

## 4. Réseau

| Rôle | IP | Statut |
|------|-----|--------|
| Proxmox host (Beelink) | 192.168.1.100 | ✅ |
| vm-extranet | 192.168.1.111 | ✅ |
| lxc-web | 192.168.1.112 | ✅ |
| Bridge | vmbr0 → LAN 192.168.1.0/24, GW 192.168.1.1 | ✅ |

**Ports forwardés depuis la box Internet (inchangés) :**
- `80/tcp` → 192.168.1.111 (NPM HTTP)
- `443/tcp` → 192.168.1.111 (NPM HTTPS)

---

## 5. Étapes réalisées

```
[✅] Snapshots ZFS sur M1 : tank-hdd@pre-migration + tank-ssd@pre-migration
[✅] vzdump VM 101 → vzdump-qemu-101-2026_03_21-22_45_24.vma.zst (1.7 GB)
[✅] vzdump LXC 102 → vzdump-lxc-102-2026_03_21-22_49_10.tar.zst (257 MB)
[✅] Installation Proxmox VE 9.1 sur Beelink S12 (IP temporaire 192.168.1.61)
[✅] Transfert des backups via SCP (M1 → Beelink, ~110 MB/s)
[✅] Arrêt VM 101 + LXC 102 sur M1 (éviter conflits IP)
[✅] qmrestore VM 101 sur Beelink (storage: local-lvm)
[✅] pct restore LXC 102 sur Beelink (storage: local-lvm)
[✅] Détachement ISO Debian orpheline (qm set 101 --ide2 none)
[✅] Démarrage VM 101 + LXC 102 sur Beelink
[✅] Changement IP Beelink : 192.168.1.61 → 192.168.1.100
[✅] Validation réseau : ping + curl HTTP 200 OK sur 192.168.1.111
[✅] Validation NPM : elmzn.be accessible
```

---

## 6. Incident réseau rencontré (et résolu)

**Problème :** Après restauration, le tap/veth des VMs n'était pas attaché au bridge `vmbr0` au premier démarrage.

**Symptôme :** La VM pingait depuis l'intérieur mais était injoignable depuis le LAN. La box répondait à la place (`192.168.1.2`) à cause d'un ARP cache obsolète.

**Cause :** Premier démarrage post-migration sur un nouveau host — le tap ne s'était pas rattaché automatiquement.

**Résolution manuelle (temporaire) :**
```bash
# VM
brctl addif vmbr0 tap101i0

# LXC
brctl addif vmbr0 veth102i0
```

**Résolution définitive :** Un reboot propre de chaque VM/LXC via `qm reboot 101` et `pct reboot 102` a résolu le problème — le tap se rattache bien automatiquement au bridge depuis.

---

## 7. État post-migration

| Composant | IP | Statut |
|-----------|-----|--------|
| Proxmox VE 9.1 (Beelink S12) | 192.168.1.100 | ✅ |
| vm-extranet | 192.168.1.111 | ✅ running |
| lxc-web | 192.168.1.112 | ✅ running |
| NPM (Docker) | :80 / :443 / :81 | ✅ HTTP 200 OK |
| elmzn.be | — | ✅ accessible |

---

## 8. Actions restantes

```
[ ] Tester elmzn.be depuis Internet (téléphone 4G, WiFi coupé)
[ ] Éteindre définitivement le Dell OptiPlex 7040 après quelques jours de stabilité
[ ] (Optionnel) Récupérer le Dell en DHCP si besoin (accès physique requis)
[ ] (Optionnel) Installer ddclient sur vm-extranet si DDNS elmzn.be nécessaire
[✅] (Optionnel) Activer UFW sur vm-extranet
```

---

## 9. Informations Machine #2 (inchangée)

M2 est restée en place pendant toute la migration et continue de fonctionner normalement.

| Élément | Valeur |
|---------|--------|
| IP Proxmox M2 | 192.168.1.200 |
| VM-INTRANET | 192.168.1.201 |
| LXC Minecraft | 192.168.1.202 |
| Dépendance M1→M2 | NPM sur vm-extranet redirige vers services M2 ✅ |
