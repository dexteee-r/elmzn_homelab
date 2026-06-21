# 🖥️ Installer Proxmox VE — base reproductible

> **Ce que tu obtiens :** un hôte **Proxmox VE** propre (repo gratuit activé), un **pool ZFS** sur le disque de données exporté en **NFS** au LAN, et une **première VM Debian** prête à recevoir des services.

| | |
|---|---|
| 🎯 Résultat | Un nœud Proxmox opérationnel : web UI, pool ZFS, partage NFS, 1 VM Debian |
| ⏱️ Durée | ~1 h 30 – 2 h (hors téléchargement ISO) |
| 📊 Niveau | Intermédiaire |
| 🧩 Pré-requis | 1 machine x86-64 (VT-x/VT-d) · 1 disque OS + 1 disque data · clé USB · une image ISO Proxmox VE 9 |
| 🔗 Décisions liées | [ADR-001 — Hyperviseur Proxmox](../ADR/001-hyperviseur-proxmox.md) · [ADR-004 — ZFS vs Btrfs](../ADR/004-zfs-vs-btrfs.md) · [ADR-007 — Stratégie de stockage](../ADR/007-strategie-stockage.md) |

> 📚 Ce tuto dit **comment** poser un hôte Proxmox. Le **pourquoi** (choix Proxmox, ZFS, répartition SSD/HDD) est dans les ADR liés ci-dessus.

## 🗺️ Ce qu'on construit

Le schéma cible, avec les valeurs réelles de l'hôte **Intranet** du homelab (`srv2`) comme exemple. Adapte les IP / noms à ta machine.

```
Machine Proxmox (exemple : srv2 — 192.168.1.200, PVE 9.1.1)
├─ Disque OS    : SSD/NVMe  → install Proxmox (ext4 ou ZFS root)
├─ Disque data  : HDD       → pool ZFS « data-pool » (~3.62 To)
│   └─ datasets : data-pool/photos, data-pool/files, data-pool/backups, data-pool/media
├─ Export NFS   : datasets exposés au LAN 192.168.1.0/24
└─ VM Debian    : ex. 101 « vm-intranet » (192.168.1.201) → monte les NFS, fait tourner les services
```

> ℹ️ **Convention IP :** toutes les IP ci-dessous sont **privées LAN** (`192.168.1.x`), donc montrées en clair. Seule une **IP publique** se redacte (`<IP_PUBLIQUE>`) — il n'y en a aucune dans ce tuto.

## 🚶 Étapes

### Étape 1 — Activer la virtualisation dans le BIOS
*Pourquoi :* sans VT-x/VT-d, Proxmox ne peut pas lancer de VM ni faire de passthrough.

Au démarrage, entrer dans le BIOS/UEFI (souvent `Suppr`, `F2` ou `F12`) et activer :

```
Intel VT-x (Virtualization Technology) : Enabled
Intel VT-d (Directed I/O / IOMMU)       : Enabled
```

Vérifier aussi que les **deux disques** (OS + data) sont bien détectés. Sauvegarder et redémarrer.

✅ **Vérifie que :** les disques OS et data apparaissent dans la liste de boot, et que la virtualisation est `Enabled`.

### Étape 2 — Installer Proxmox VE
*Pourquoi :* poser l'hyperviseur sur le disque OS et lui donner une IP fixe sur le LAN.

Flasher l'ISO **Proxmox VE 9** sur une clé USB (Rufus / `dd` / balenaEtcher), booter dessus, choisir **Install Proxmox VE (graphical)**, puis renseigner :

```
Target Harddisk : <disque OS>   (⚠️ efface tout le disque choisi)
  └─ Filesystem : ext4 (simple) ou zfs (RAID1) selon ton matériel
Country / Timezone : Belgium / Europe/Brussels
Keyboard           : French (Belgium) ou US

Management Network :
  Hostname (FQDN) : srv2.local        # exemple — nom réel de l'hôte
  IP Address      : 192.168.1.200/24  # IP fixe sur le LAN
  Gateway         : 192.168.1.1        # la box
  DNS             : 192.168.1.1        # ou 1.1.1.1
```

Lancer l'installation (~10-15 min), retirer la clé, redémarrer.

🔎 **Résultat attendu** — la web UI répond :
```
https://192.168.1.200:8006
→ login : root  /  (mot de passe défini à l'install)
```
✅ **Vérifie que :** tu te connectes à `https://192.168.1.200:8006` et que le nœud (`srv2`) apparaît dans l'arborescence.

### Étape 3 — Activer le dépôt « no-subscription » (gratuit)
*Pourquoi :* sans abonnement, le repo *enterprise* renvoie une erreur `401` à chaque `apt update`. Le repo **no-subscription** est gratuit et suffit pour un homelab.

Méthode **GUI** (la plus robuste, indépendante de la version) :

```
Datacenter > srv2 > Updates > Repositories
  1. Sélectionner la ligne « pve-enterprise » → bouton « Disable »
  2. (idem pour « ceph … enterprise » si présente)
  3. Bouton « Add » → choisir « No-Subscription » → Add
```

Puis mettre à jour depuis un terminal (`>_ Shell` sur le nœud, ou SSH) :

```bash
apt update && apt full-upgrade -y
```

🔎 **Résultat attendu** (sortie réelle `srv2`)
```
Hit:1 http://deb.debian.org/debian trixie InRelease
Get:6 http://download.proxmox.com/debian/ceph-squid trixie InRelease [2,736 B]
Get:7 http://download.proxmox.com/debian/pve trixie InRelease [3,534 B]
Get:8 http://download.proxmox.com/debian/pve trixie/pve-no-subscription amd64 Packages [469 kB]
Fetched 919 kB in 1s (931 kB/s)
202 packages can be upgraded. Run 'apt list --upgradable' to see them.
```
Aucune ligne `401` vers `enterprise.proxmox.com` → le repo gratuit est bien actif.

✅ **Vérifie que :** `apt update` se termine **sans erreur 401** et que la version est bien PVE 9 :
```bash
pveversion
# pve-manager/9.1.1/42db4a6cf33dac83 (running kernel: 6.17.2-2-pve)
```

### Étape 4 — Créer le pool ZFS sur le disque de données
*Pourquoi :* regrouper le disque data dans un pool ZFS (intégrité + snapshots + compression) — voir [ADR-004](../ADR/004-zfs-vs-btrfs.md).

Identifier le disque data (⚠️ **pas** le disque OS — confonds-les et tu écrases Proxmox) :

```bash
lsblk
```
🔎 **Résultat attendu** (sortie réelle `srv2` — adapter aux lettres de **ta** machine)
```
NAME                         SIZE TYPE MOUNTPOINTS
sda                          3.6T disk            # disque DATA → pour le pool ZFS
├─sda1                       3.6T part            #   (sda1 + sda9 = ZFS pleine-disque)
└─sda9                         8M part
sdb                        447.1G disk            # disque OS Proxmox — NE PAS toucher
├─sdb2                          1G part
└─sdb3                      446.1G part
  ├─pve-root                   96G lvm  /         #   racine Proxmox (LVM)
  ├─pve-swap                    8G lvm  [SWAP]
  └─pve-data … pve-vm--101 …   …  lvm            #   thin pool + disques des VM
```
> 💡 Repère : le **gros disque** (3.6T, ici `sda`) = data ; le disque qui porte `pve-root /` (ici `sdb`) = OS. Sur ta machine ça peut être `nvme0n1`, etc.

Créer le pool (nom réel du homelab : `data-pool`) directement sur le disque entier :

```bash
zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  data-pool /dev/sda        # le disque DATA repéré ci-dessus

# Datasets par usage, montés sous /mnt/data-pool/* (réutilisés par les exports NFS)
zfs create -o mountpoint=/mnt/data-pool/photos  data-pool/photos
zfs create -o mountpoint=/mnt/data-pool/files   data-pool/files
zfs create -o mountpoint=/mnt/data-pool/backups data-pool/backups
zfs create -o mountpoint=/mnt/data-pool/media   data-pool/media

# Quotas (exemple homelab — adapter selon tes besoins) pour cloisonner l'espace
zfs set quota=2T   data-pool/photos
zfs set quota=512G data-pool/files
zfs set quota=512G data-pool/backups
zfs set quota=512G data-pool/media
```

🔎 **Résultat attendu** (sortie réelle `srv2`)
```bash
zpool status data-pool
```
```
  pool: data-pool
 state: ONLINE
  scan: scrub repaired 0B in 00:00:56 with 0 errors on Sun Mar  8 00:24:57 2026
config:
        NAME        STATE     READ WRITE CKSUM
        data-pool   ONLINE       0     0     0
          sda       ONLINE       0     0     0
errors: No known data errors
```
✅ **Vérifie que :** le pool `data-pool` est `ONLINE` (~3.6 To), les mountpoints et quotas sont bons :
```bash
df -h | grep /mnt
```
```
data-pool/files       512G  128K  512G   1% /mnt/data-pool/files
data-pool/media       512G  128K  512G   1% /mnt/data-pool/media
data-pool/photos      2.0T  160G  1.9T   8% /mnt/data-pool/photos
data-pool/backups     512G   36G  477G   8% /mnt/data-pool/backups
```
Chaque dataset apparaît à son mountpoint `/mnt/data-pool/*`, avec la taille = son quota.

### Étape 5 — Exporter les datasets en NFS vers le LAN
*Pourquoi :* permettre aux VM (ex. `vm-intranet`) de monter le stockage du host sans dupliquer les données.

Les chemins d'export = les mountpoints des datasets vus à l'Étape 4 (`/mnt/data-pool/*`) :

```bash
apt install -y nfs-kernel-server

cat >> /etc/exports << 'EOF'
/mnt/data-pool/photos   192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/data-pool/files    192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/data-pool/backups  192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/data-pool/media    192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
EOF

exportfs -ra
systemctl enable --now nfs-server
```

🔎 **Résultat attendu** (sortie réelle `srv2`)
```bash
showmount -e localhost
```
```
Export list for localhost:
/mnt/data-pool/media    192.168.1.0/24
/mnt/data-pool/backups  192.168.1.0/24
/mnt/data-pool/files    192.168.1.0/24
/mnt/data-pool/photos   192.168.1.0/24
```
✅ **Vérifie que :** les 4 exports `/mnt/data-pool/*` apparaissent dans `showmount -e localhost`.

### Étape 6 — Créer la première VM Debian
*Pourquoi :* l'hôte Proxmox reste minimal ; les services tournent dans une VM (ici Debian, ex. `vm-intranet`).

1. **Uploader l'ISO** : `srv2 > local > ISO Images > Upload` (ISO Debian 13 netinst).
2. **Create VM** avec ces réglages (valeurs réelles `vm-intranet` en exemple) :

```
General : VM ID 101 · Name vm-intranet · Start at boot ✔
OS      : ISO Debian 13 · Type Linux (6.x)
System  : Machine q35 · BIOS OVMF (UEFI) · Add EFI Disk ✔
Disks   : SCSI (VirtIO SCSI) · local-lvm · 40 GB · Discard ✔
CPU     : 1 socket · 3 cores · Type host
Memory  : 6144 MB (6 Go) · Ballooning ✔
Network : Bridge vmbr0 · Model VirtIO
```

3. **Installer Debian** (console noVNC) : hostname `vm-intranet`, SSH server ✔, **pas** de bureau, IP fixe `192.168.1.201/24`.

4. **Monter les NFS du host** dans la VM :

```bash
apt install -y nfs-common
mkdir -p /mnt/photos /mnt/files /mnt/backups /mnt/media

cat >> /etc/fstab << 'EOF'
192.168.1.200:/mnt/data-pool/photos   /mnt/photos   nfs  defaults  0  0
192.168.1.200:/mnt/data-pool/files    /mnt/files    nfs  defaults  0  0
192.168.1.200:/mnt/data-pool/backups  /mnt/backups  nfs  defaults  0  0
192.168.1.200:/mnt/data-pool/media    /mnt/media    nfs  defaults  0  0
EOF

mount -a
df -h | grep /mnt
```

🔎 **Résultat attendu**
```
⚠️ À VÉRIFIER — coller la vraie sortie `df -h | grep /mnt` depuis vm-intranet (.201).
Attendu : les 4 montages 192.168.1.200:/mnt/data-pool/* présents.
```
✅ **Vérifie que :** la VM démarre, répond en SSH sur `192.168.1.201`, et que `mount -a` monte les 4 partages sans erreur.

## ✅ Test final

Bout-en-bout : écrire depuis la VM, lire depuis l'hôte.

```bash
# Depuis la VM (192.168.1.201)
echo "ok-$(date +%s)" > /mnt/photos/test-nfs.txt

# Depuis l'hôte Proxmox (192.168.1.200)
cat /mnt/data-pool/photos/test-nfs.txt    # doit afficher la même ligne
```

Si le fichier écrit dans la VM apparaît côté hôte → **ZFS + NFS + VM fonctionnent**. 🎉

## 🆘 Dépannage

| Symptôme | Cause probable | Fix |
|----------|----------------|-----|
| `apt update` → erreur `401` | repo *enterprise* encore actif | Désactiver enterprise + ajouter no-subscription (Étape 3) |
| `zpool create` → *device or resource busy* | disque monté / déjà partitionné | `wipefs -a /dev/sdX` après avoir confirmé que c'est **le bon disque** |
| VM ne boote pas (écran noir UEFI) | EFI Disk manquant | Vérifier BIOS = OVMF (UEFI) **et** « Add EFI Disk » coché |
| `mount -a` → *access denied* / *timeout* | export NFS absent ou pare-feu | `showmount -e 192.168.1.200` ; vérifier `/etc/exports` + `exportfs -ra` |
| `mount.nfs: Connection refused` | `nfs-common` non installé dans la VM | `apt install -y nfs-common` |

## ➡️ Et après

- Déployer les services dans la VM (Immich, monitoring…) — voir les `docker-compose` de `configs/machine2-intranet/`.
- Ajouter un **NAS** dédié pour le stockage froid → [NAS ZimaOS](nas-zimaos.md).
- Accéder à tout ça depuis l'extérieur → [VPN WireGuard (subnet-router)](vpn-wireguard-subnet-router.md).
- Héberger un serveur de jeu sur un second nœud → [Serveur Minecraft (mc-switch)](serveur-minecraft.md).

---

> 🔧 **Sorties figées depuis `srv2` (2026-06-20).** Seul reste à confirmer le `df -h | grep /mnt` côté `vm-intranet` (.201) — bloc marqué `⚠️ À VÉRIFIER` à l'Étape 6.
