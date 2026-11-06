# Journal de bord — Mise à jour de sécurité de tout le parc — 2026-11-06

## Objectif

Corriger la faille d'APT publiée le 4 novembre 2026 (DSA-6607-1, CVE-2026-109518) sur
toutes les machines du homelab, puis en profiter pour appliquer les mises à jour en
attente (autres correctifs de sécurité Debian, mises à jour Proxmox, nouveaux noyaux).

Périmètre : 2 hôtes Proxmox (Beelink `pve-extranet`, `srv2`) et tous leurs invités
(8 LXC + 1 VM sur le Beelink, 3 LXC + 1 VM sur srv2).

---

## Les avis de sécurité concernés

| Avis | Paquet | Date | Contenu |
|------|--------|------|---------|
| DSA-6607-1 | `apt` | 2026-11-04 | CVE-2026-109518 : deux téléchargements qui obtiennent la même URI après une redirection HTTP peuvent être fusionnés, et la reprise d'un téléchargement HTTP permet de remplacer un paquet **après** sa vérification. Un attaquant placé sur le chemin réseau (homme du milieu) obtient l'exécution de code en root. Corrigé dans apt 3.0.4 (Debian 13), 2.6.2 (Debian 12) et 2.8.4ubuntu0.1 (Ubuntu 24.04). |
| DSA-6602-1 | `linux` | début novembre 2026 | Plus de 300 CVE du noyau Debian. Corrigé dans le noyau 6.12.115 (Debian 13). Ne concerne **pas** les hôtes Proxmox, qui utilisent le noyau `proxmox-kernel` (série 7.0). |
| DSA-6599-1 | `nss` | 2026-10-31 | Des autorités de certification intermédiaires eMudhra sont compromises ; le correctif retire 3 certificats racine. |
| DSA-6582-1 | `brotli` | 2026-10-23 | CVE-2026-111497 : déni de service, voire exécution de code, dans la bibliothèque de compression. |
| DSA-6600-1 | `vim` | 2026-11-01 | Une quarantaine de CVE : injections de commandes via les greffons (netrw, tar, zip, complétion), dépassements de mémoire avec des fichiers piégés. Exploitable seulement en ouvrant un fichier piégé dans vim. |

Le dépôt de paquets est interrogé en `http://` : tant qu'apt n'était pas corrigé, un
attaquant sur le réseau pouvait exploiter la faille. Le correctif d'apt a donc été
appliqué **en premier** sur chaque machine, avant le reste.

---

## Résultat : versions avant / après

### Hôtes Proxmox

| Hôte | Proxmox VE | Noyau actif | apt |
|------|-----------|-------------|-----|
| Beelink `pve-extranet` | 9.2.21 → **9.2.26** | 7.0.14-20 → **7.0.14-28** | 3.0.3 → **3.0.4** |
| `srv2` | 9.2.21 → **9.2.26** | 7.0.14-25 → **7.0.14-28** | 3.0.3 → **3.0.4** |

### Invités

| Machine | Système | apt | Paquets mis à jour | Autres changements notables |
|---------|---------|-----|--------------------|------------------------------|
| Beelink · LXC 100 `vaultwarden` | Debian | corrigé | 106 | |
| Beelink · LXC 102 `lxc-web` | Ubuntu 24.04 | 2.8.3 → 2.8.4ubuntu0.1 | 147 | |
| Beelink · LXC 103 `wireguard` | Debian | corrigé | 101 | Docker (wg-easy) redémarré |
| Beelink · LXC 104 `portfolio` | Debian | corrigé | 68 | |
| Beelink · LXC 105 `watchlist` | Debian | corrigé | 96 | |
| Beelink · LXC 107 `mytcg` | Debian | corrigé | 118 | |
| Beelink · LXC 108 `monitoring` | Debian | corrigé | 134 | |
| Beelink · LXC 106 `n8n` | Debian 13 | 3.0.3 → 3.0.4 | 101 | Docker 29.7.1 → 29.9.3, containerd 2.2.6 → 2.4.2 |
| Beelink · VM 101 `vm-extranet` | Debian 13 | 3.0.3 → 3.0.4 | 129 | Noyau → 6.12.115 ; Docker 28.5 → 29.9, containerd 1.7 → 2.4 |
| srv2 · VM 101 `vm-intranet` | Debian 13 | 3.0.3 → 3.0.4 | 122 | Noyau 6.12.57 → 6.12.115 ; Docker 29.1.2 → 29.9.3, containerd 2.2.0 → 2.4.2 |
| srv2 · LXC 201 `filestore` | Debian 12 | 2.6.1 → 2.6.2 | 66 | |
| srv2 · LXC 202 `nomad` | Debian 12 | 2.6.1 → 2.6.2 | 10 | Docker 29.9.2 → 29.9.3 |
| srv2 · LXC 200 `minecraft-cobblemon` | Debian 12 | 2.6.1 → 2.6.2 | 87 | Java Temurin 21.0.10 → 21.0.13 |

Les hôtes ont reçu 86 paquets (Beelink) et 73 paquets (srv2), plus le nouveau noyau.

---

## Déroulé

1. **Nuit du 5 au 6 novembre** — Beelink. Correctif d'apt sur l'hôte et sur `vm-extranet`,
   puis sur les 7 LXC allumés. Mise à jour complète de ces LXC (un à la fois), puis de
   `vm-extranet` avec redémarrage pour activer le noyau 6.12.115. Nettoyage d'une ligne
   `fstab` obsolète (voir pièges).
2. **6 novembre, après-midi** — `srv2` rallumé : correctif d'apt, mise à jour complète de
   l'hôte, **redémarrage** (noyau 7.0.14-28). Puis correctif d'apt dans les 3 invités
   allumés, puis leur mise à jour complète, un par un (`nomad`, `filestore`, `vm-intranet`).
3. **6 novembre, soir** — Redémarrage de `vm-intranet` (noyau 6.12.115). Mise à jour
   complète de l'hôte Beelink puis **redémarrage** : tous les invités sont revenus seuls.
4. **En dernier** — Les deux conteneurs normalement éteints (`minecraft-cobblemon` et
   `n8n`) ont été démarrés le temps de la mise à jour (correctif d'apt, puis mise à jour
   complète), puis éteints de nouveau.

Chaque étape a suivi la même règle : **simuler avant d'appliquer**, contrôler qu'il n'y a
aucune suppression de paquet, appliquer, puis vérifier le service avant de passer au
suivant.

---

## Procédure reproductible

```bash
# 1. Corriger d'abord le seul paquet vulnérable (sans toucher au reste)
apt-get -s install --only-upgrade apt      # simulation : 3 paquets attendus
apt-get install -y --only-upgrade apt
dpkg -l apt                                # 3.0.4 (Debian 13), 2.6.2 (Debian 12), 2.8.4ubuntu0.1 (Ubuntu 24.04)

# 2. Mise à jour complète, après simulation
apt-get -s dist-upgrade | grep -E '^(Remv|[0-9]+ upgraded)'     # 0 suppression attendue
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y \
  -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef

# 3. Noyau actif ou simplement installé ? (Debian ne crée pas /var/run/reboot-required)
uname -r ; ls /boot | grep vmlinuz

# 4. Contrôles
apt-get check ; systemctl is-system-running ; systemctl --failed
```

Depuis l'hôte Proxmox, pour atteindre les invités :

```bash
pct exec <id> -- <commande>                # conteneur LXC
qm guest exec <id> -- <commande>           # VM avec agent QEMU (sortie en JSON)
systemd-run --unit=maj --collect sh /root/up.sh   # mise à jour détachée (voir pièges)
```

Ordre conseillé : correctif d'apt partout, puis mises à jour complètes **un invité à la
fois**, hôtes Proxmox en **dernier** (leur redémarrage coupe tous les invités).

---

## Pièges rencontrés

- **L'agent QEMU est mis à jour pendant la mise à jour de la VM.** Le paquet
  `qemu-guest-agent` relance l'agent, ce qui tue les processus lancés par lui, y compris
  un `apt` en cours. Lancer la mise à jour dans une unité séparée :
  `systemd-run --unit=maj --collect sh /root/up.sh`, puis lire un fichier de résultat.
- **Debian ne signale pas le besoin de redémarrer** (pas de `/var/run/reboot-required`).
  Comparer `uname -r` aux fichiers `/boot/vmlinuz-*` pour savoir si un nouveau noyau est
  installé mais pas encore actif.
- **Docker redémarre tous les conteneurs** quand son paquet est mis à jour (pas de
  `live-restore`). Ils reviennent seuls grâce à leur politique de redémarrage
  (`always` / `unless-stopped`) : vérifier qu'ils sont `healthy` ensuite. Le saut Docker
  28 → 29 et containerd 1.7 → 2.4 s'est passé sans incident.
- **`wtmpdb-rotate.timer` reste en échec** après la mise à jour de plusieurs LXC (le
  fichier d'unité a disparu), ce qui fait passer le système en `degraded`. Sans conséquence :
  `systemctl reset-failed wtmpdb-rotate.timer`.
- **Le serveur Minecraft démarre tout seul avec son conteneur** (`minecraft.service`
  activé). Avant de mettre Java à jour, l'arrêter aussitôt :
  `systemctl stop minecraft.service`.
- **Mise à jour de GRUB sur un hôte en EFI** : `grub-install` s'exécute pendant la mise
  à jour. Avant, sauvegarder la partition EFI (`tar czf … /boot/efi /boot/grub`) et
  vérifier après coup que `shimx64.efi` est toujours présent dans `/boot/efi/EFI/proxmox/`.
  Les anciens noyaux restent installés en repli.
- **Une ligne `fstab` obsolète** sur `vm-extranet` (`/mnt/logs`, export NFS qui n'existe
  plus sur le Beelink) rallongeait chaque démarrage d'environ 90 secondes. Elle est
  commentée ; le redémarrage du Beelink l'a confirmé (démarrage propre, aucune unité en
  échec).
- **Depuis `srv2`**, les noms publics (`files.elmzn.be`) se résolvent vers l'IP publique et
  échouent (hairpin NAT) : pour tester un service, viser l'IP du conteneur directement.

---

## Vérifications finales

- Les deux hôtes tournent sur le noyau `7.0.14-28-pve` ; `srv2` et le Beelink : aucun
  service en échec, ZFS de `srv2` sain.
- Tous les invités configurés pour démarrer seuls (`onboot=1`) sont revenus après le
  redémarrage du Beelink ; `n8n`, `minecraft-cobblemon` et les VM de labo restent éteints
  (`onboot=0`).
- Sites publics testés via NPM : `home`, `links`, `watchlist`, `mytcg`, `vault` → 200,
  `elmzn.be` → 307. WireGuard écoute sur 51820/udp, Checkmk est `running`.
- Immich : l'API répond (200) et les conteneurs sont `healthy` ; `filestore` répond 200,
  `nomad` répond 302 (comme avant la mise à jour) ; `n8n` : `/healthz` → `ok`.
- Plus aucun paquet en attente sur aucune machine, et plus aucune machine avec l'ancien apt.

---

## Reste à faire / à envisager

- Vérifier dans Checkmk que les alertes sont bien revenues au vert après tous ces
  redémarrages (non contrôlé dans l'interface).
- Premier lancement de Minecraft après la mise à jour : Java est passé en Temurin 21.0.13
  (même version majeure). En cas de plantage du pack, regarder `journalctl -u minecraft`
  et la version de Java en premier.
- À envisager : passer les sources APT en `https://` pour réduire l'exposition aux
  attaques sur le réseau, indépendamment de ce correctif (non fait).
