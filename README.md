# 🛠️ Agent Management Script

Ce script shell permet de gérer l’installation, la vérification et la désinstallation d’un agent (comme NinjaRMM) sur une machine Linux. Vous pouvez utiliser ce script pour automatiser le déploiement de l'agent avec une interface utilisateur simple et des logs complets.

---

## 📋 Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Détails Techniques](#détails-techniques)
- [Contributions](#contributions)
- [Licence](#licence)

---

## ✨ Fonctionnalités

- **Installation de l'agent** : Demande l'URL de l'agent et télécharge automatiquement le fichier dans le répertoire `/tmp`, puis installe le package.
- **Vérification du statut du service** : Vérifie si le service `ninjarmm-agent.service` fonctionne sur la machine.
- **Désinstallation de l'agent** : Supprime l'agent installé de la machine.
- **Logs détaillés** : Stocke les logs dans un répertoire `/log` pour permettre un suivi complet de toutes les actions.

---

## ✅ Prérequis

- Linux OS (recommandé pour des distributions basées sur RPM)
- `curl` pour le téléchargement des fichiers
- `sudo` pour les permissions d'installation
- `systemd` pour la gestion des services

---

## 🚀 Installation

Clonez ce dépôt et donnez les permissions d’exécution au script.

```bash
git clone https://github.com/Rooot3301/Ninjaa.git
cd Ninjaa
chmod +x main.sh
