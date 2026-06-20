# 🚶 Tutos — Guides pas à pas reproductibles

Cette section regroupe les **tutoriels** du homelab : on les **suit** pour reproduire un service de bout en bout.

> 📚 **Tuto ≠ ADR.** Un tuto dit **comment** faire (étapes, commandes, vérifs). Un [ADR](../ADR/) dit **pourquoi** ce choix a été fait. Chaque tuto **lie** vers les ADR concernés pour le contexte.

---

## 👉 Commence ici (parcours)

| Ordre | Tuto | Niveau | Ce que tu obtiens |
|-------|------|--------|-------------------|
| 1 | [VPN WireGuard (subnet-router)](vpn-wireguard-subnet-router.md) | Intermédiaire | Accès à tout le LAN homelab depuis l'extérieur |
| 2 | [Serveur Minecraft (mc-switch)](serveur-minecraft.md) | Intermédiaire | Serveur Minecraft multi-modpacks, bascule en 1 commande |
| 3 | [NAS ZimaOS](nas-zimaos.md) | Débutant | NAS domestique : partages SMB/NFS + apps |
| — | _Setup Proxmox (à convertir depuis `../SETUP-MACHINE1.md`)_ | — | _à venir_ |
| — | _Déploiement web (à convertir depuis `web-server-doc-v2.pdf`)_ | — | _à venir_ |

---

## ✍️ Conventions d'écriture

Un tuto **faux** est pire qu'une doc moche. Donc :

- **Texte en français**, **blocs de code en anglais**.
- Style **80/20** : pratique, pas exhaustif. Les commandes et leurs sorties portent l'info.
- **Valeurs réelles uniquement** : IP, versions, RAM viennent de **vrais outputs**. Jamais inventer une valeur.
- Une valeur manquante ou ambiguë se marque **`⚠️ À VÉRIFIER`**, jamais une supposition.
- **Secrets & IP publique** : redactés dans le repo (placeholder `<IP_PUBLIQUE>`), jamais en clair.

### Structure d'un tuto

Chaque tuto suit [`_TEMPLATE.md`](_TEMPLATE.md) : **résultat d'abord**, puis pré-requis, puis des **étapes orientées action**. Chaque étape contient :

- *Pourquoi* (1 ligne)
- les commandes copier-coller
- 🔎 **Résultat attendu** (la vraie sortie)
- ✅ **Vérifie que** (la condition de réussite)

Et le tuto se termine par : **✅ Test final** (end-to-end) · **🆘 Dépannage** · **➡️ Et après**.

### Démarrer un nouveau tuto

```bash
cp docs/tutos/_TEMPLATE.md docs/tutos/<mon-service>.md
# puis ajoute la ligne correspondante dans le parcours ci-dessus
```
