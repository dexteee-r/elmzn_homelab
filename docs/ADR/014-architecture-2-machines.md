# ADR-011: Architecture à 2 Machines Séparées

**Date :** 2025-11-28  
**Statut :** ✅ Accepté  
**Décideurs :** Markus  
**Tags :** `architecture`, `infrastructure`, `sécurité`

> ⚠️ **Note (2026-09-22) :** cette ADR documente une décision figée au moment de sa rédaction. Depuis, Machine #1 est passée du Dell OptiPlex 7040 à un Beelink S12 (migration du 2026-03-21, voir `docs/MIGRATION-M1-vers-nouvelle-machine.md`) — l'ancien OptiPlex a été reconverti en Machine #3 (NAS ZimaOS). L'IP `192.168.1.101` citée plus bas pour VM-INTRANET est aussi **obsolète** (la vraie IP vérifiée est `192.168.1.201`), et l'infrastructure compte aujourd'hui 3 machines, pas 2. Pour l'état réel actuel, voir `README.md`.

---

## Contexte

L'infrastructure initiale utilisait **1 seule machine** (Dell OptiPlex 7040) hébergeant tous les services via 2 VMs (EXTRANET + INTRANET). 

**Acquisition d'une 2ème machine** plus puissante (i7-6700 + GTX 980 + capacité ajout 4 TB) ouvre opportunité de **repenser l'architecture** pour améliorer :
- Sécurité (isolation physique)
- Performance (répartition charge)
- Évolutivité (ajout services sans contrainte ressources)
- Apprentissage (concepts DMZ/LAN avancés)

---

## Décision

**Migrer vers architecture à 2 machines physiquement séparées** :

### **Machine #1 : EXTRANET (DMZ)**
- **Rôle :** Exposition Internet UNIQUEMENT
- **Hardware :** Dell OptiPlex 7040 (i5-6500, 16 GB RAM)
- **Services :** Reverse proxy, VPN, DNS dynamique, firewall
- **IP :** 192.168.1.111

### **Machine #2 : INTRANET (LAN Privé)**
- **Rôle :** Stockage famille + Services applicatifs + VMs laboratoire
- **Hardware :** Custom PC (i7-6700, 16 GB RAM, GTX 980, 4 TB HDD)
- **Services :** Immich, Nextcloud, PostgreSQL, VMs dev
- **IP :** 192.168.1.101

**Principe clé :** Machine #2 **JAMAIS** exposée directement à Internet.

---

## Justification

### ✅ **Avantages**

#### 1. **Sécurité Renforcée (Defense in Depth)**
```
Internet
   ↓
Machine #1 (DMZ) ← Seul point d'exposition
   ↓ (reverse proxy)
Machine #2 (LAN) ← Jamais exposé directement
```

- Isolation physique = barrière matérielle supplémentaire
- Si Machine #1 compromise → Machine #2 reste protégé
- Réduction surface d'attaque (moins de services exposés)
- Facilite audit sécurité (périmètre clair)

#### 2. **Performance Optimisée**
- **Machine #1** : i5-6500 (4T) dédié reverse proxy léger
- **Machine #2** : i7-6700 (8T) gère workloads intensifs
  - Immich (indexation photos 4 TB)
  - Nextcloud (sync fichiers)
  - VMs laboratoire (2x simultanées)
  - GPU disponible pour transcoding futur

#### 3. **Apprentissage & Portfolio**
- Concepts réseau avancés (DMZ, zones sécurité)
- Architecture multi-tiers réelle
- Bonne pratique production (séparation responsabilités)
- Portfolio professionnel impressionnant

#### 4. **Évolutivité Naturelle**
- Ajout services INTRANET sans impact EXTRANET
- Upgrade matériel Machine #2 indépendant Machine #1
- Possibilité cluster futur (ajout Node #3)
- Scalabilité horizontale facilitée

#### 5. **Maintenance Simplifiée**
- Update Machine #1 sans toucher Machine #2 (et inversement)
- Debugging isolé (problème réseau ≠ problème app)
- Rollback granulaire (restaurer 1 machine sans impacter l'autre)

### ⚠️ **Inconvénients & Mitigations**

| Inconvénient | Mitigation |
|--------------|------------|
| **Complexité setup** (2 machines vs 1) | Guides détaillés + scripts automatisation |
| **Consommation électrique** (+40W) | VMs lab on-demand (économise ~15W) |
| **Coût matériel** (2ème machine) | ✅ Déjà acquise (coût nul) |
| **Latence réseau** (M1→M2 proxy) | Négligeable LAN Gigabit (~1ms) |
| **Single Point of Failure** (pas HA) | Accepté (homelab, pas production critique) |

---

## Alternatives Considérées

### ❌ **Alternative 1 : Garder 1 Machine + VMs**
```
Configuration :
- 1 seule machine (Machine #2 plus puissante)
- 2 VMs (EXTRANET + INTRANET) sur même host

Rejetée car :
- Pas d'isolation physique (sécurité moindre)
- GPU sous-utilisé (pas de passthrough VM simple)
- Moins didactique (concepts réseau limités)
```

### ❌ **Alternative 2 : Cluster Proxmox HA (2 nodes)**
```
Configuration :
- 2 machines en cluster HA
- Migration live VMs
- Failover automatique

Rejetée car :
- Complexité excessive pour besoins actuels
- Nécessite 3ème device (Quorum)
- Setup/maintenance lourds (apprentissage)
- Consommation électrique x2 (2 machines H24)
```

### ❌ **Alternative 3 : Machine #2 = NAS pur**
```
Configuration :
- Machine #1 : tous services
- Machine #2 : stockage NFS/Samba uniquement

Rejetée car :
- GPU GTX 980 totalement inutilisé
- CPU i7-6700 sous-exploité
- Pas de VMs laboratoire (objectif apprentissage)
```

---

## Conséquences

### 📈 **Impacts Positifs**

1. **Sécurité**
   - Surface d'attaque réduite de ~60%
   - Isolation physique EXTRANET/INTRANET
   - Facilite compliance (audit, logs séparés)

2. **Performance**
   - Machine #2 dédiée workloads intensifs
   - Pas de contention ressources (reverse proxy ≠ apps)
   - GPU disponible pour future expansion

3. **Fiabilité**
   - Problème Machine #1 ≠ perte données (Machine #2 intacte)
   - Backups Machine #2 → Machine #1 (redondance physique)

4. **Maintenance**
   - Updates Rolling (1 machine à la fois)
   - Tests isolés (dev sur Machine #2, prod sur Machine #1)

### ⚙️ **Changements Techniques Requis**

#### Migration Réseau
```bash
# Avant (1 machine)
192.168.1.100 : Proxmox host unique
├─ 192.168.1.111 : VM-EXTRANET
└─ 192.168.1.101 : VM-INTRANET

# Après (2 machines)
192.168.1.111 : Machine #1 EXTRANET (host physique)
192.168.1.101 : Machine #2 INTRANET (host physique)
```

#### Configuration Firewall
```bash
# Machine #1 UFW
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw allow 1194/udp    # OpenVPN
ufw allow from 192.168.1.101  # Allow Machine #2

# Machine #2 UFW
ufw default deny incoming
ufw allow from 192.168.1.111  # Allow Machine #1 (reverse proxy)
ufw allow from 192.168.1.0/24 # Allow LAN direct
```

#### Reverse Proxy (Nginx NPM)
```nginx
# Machine #1 → Machine #2
photos.elmzn.be → 192.168.1.101:2283 (Immich)
files.elmzn.be  → 192.168.1.101:8080 (Nextcloud)
```

### 📊 **Métriques de Succès**

- ✅ Temps migration < 12h (2 weekends)
- ✅ Downtime < 2h (migration données)
- ✅ Latence ajoutée reverse proxy < 10ms
- ✅ Consommation électrique < 100W (2 machines idle)
- ✅ Sécurité validée (pentest basique)

---

## Notes d'Implémentation

### Timeline Réalisée
```
Weekend 1 (6h) : Setup Machine #2 INTRANET
├─ Installation Proxmox VE + ZFS 4 TB
├─ Création VM-INTRANET + services Docker
└─ Création VMs laboratoire

Weekend 2 (3h) : Reconfiguration Machine #1 EXTRANET
├─ Migration services INTRANET → Machine #2
├─ Configuration reverse proxy
└─ Tests validation

TOTAL : 9h effectives
```

### Coûts
- **Matériel** : 0€ (Machine #2 déjà acquise, HDD 4 TB ~110€)
- **Électricité** : +10€/mois (~40W additionnel)
- **Temps setup** : 9h (acceptable pour bénéfices)

### Risques Identifiés
| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Perte données migration** | Faible | Élevé | Backups multiples avant migration |
| **Downtime prolongé** | Moyen | Faible | Guide détaillé + rollback plan |
| **Latence réseau** | Faible | Faible | Tests charge avant production |

---

## Validation

### ✅ Critères d'Acceptation

- [x] Architecture documentée (schémas Mermaid)
- [x] Guides installation Machine #1 + Machine #2
- [x] Tests communication inter-machines OK
- [x] Backups automatisés fonctionnels
- [x] Monitoring déployé (Grafana)
- [x] Sécurité validée (UFW + Fail2ban)

### 🎯 Critères de Réussite Long Terme

- Performance services ≥ architecture 1 machine
- Disponibilité (uptime) ≥ 99% (hors maintenance)
- Facilité ajout nouveaux services
- Apprentissage concepts réseau avancés validé

---

## Références

- [RFC 2827 - Network Ingress Filtering](https://www.rfc-editor.org/rfc/rfc2827)
- [NIST SP 800-41 Rev. 1 - Guidelines on Firewalls and Firewall Policy](https://csrc.nist.gov/publications/detail/sp/800-41/rev-1/final)
- [Proxmox VE Best Practices](https://pve.proxmox.com/wiki/Network_Configuration)
- [r/selfhosted - DMZ Architecture Discussions](https://www.reddit.com/r/selfhosted/)

---

## Changelog

- **2025-11-28** : Création ADR (architecture 2 machines acceptée)
- **2025-11-XX** : (futur) Feedback post-implémentation

---

**Status Final :** ✅ **ACCEPTÉ et EN PRODUCTION**
