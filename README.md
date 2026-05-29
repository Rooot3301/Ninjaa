# 🛠️ RMM Agent Manager v2.0

Script shell avancé pour gérer l'installation, la mise à jour, la vérification et la désinstallation d'agents RMM (comme NinjaRMM) sur des machines Linux. Ce script supporte aussi bien les distributions basées sur RPM (Red Hat, CentOS, Fedora) que sur DEB (Debian, Ubuntu).

---

## 📋 Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Nouveautés v2.0](#nouveautés-v20)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
  - [Mode interactif](#mode-interactif)
  - [Mode non-interactif](#mode-non-interactif)
- [Détails techniques](#détails-techniques)
- [Logs](#logs)
- [Contributions](#contributions)
- [Licence](#licence)

---

## ✨ Fonctionnalités

- **Installation de l'agent** : Téléchargement et installation depuis une URL prédéfinie ou personnalisée
- **Support multi-distributions** : Gestion automatique des packages RPM et DEB
- **Vérification du service** : Contrôle du statut du service systemd
- **Mise à jour (Patch)** : Mise à jour de l'agent existant
- **Désinstallation** : Suppression complète de l'agent
- **Consultation des logs** : Affichage des logs du service (journalctl) et du script
- **Diagnostic de santé** : Vérification complète de l'état de l'agent et du service
- **Mode non-interactif** : Exécution en ligne de commande pour l'automatisation
- **Gestion robuste des erreurs** : Protection contre les échecs de téléchargement et d'installation
- **Rotation des logs** : Rotation automatique des fichiers de logs au-delà de 10 MB
- **Configuration externalisée** : Toutes les variables dans un fichier .env

---

## 🎉 Nouveautés v2.0

### Améliorations majeures

- **Configuration externalisée** : Fichier `.env` pour toutes les variables avec valeurs par défaut
- **Support .deb** : Ajout du support complet pour Debian/Ubuntu en plus de RPM
- **Détection automatique** : Détection intelligente du type de package (.rpm ou .deb)
- **Gestion d'erreurs renforcée** : `set -euo pipefail`, `curl --fail`, validation à chaque étape
- **Système de logs amélioré** : Rotation automatique, niveaux de logs (ERROR, WARN, INFO, DEBUG)
- **Vérification des dépendances** : Contrôle automatique de la présence de curl, systemctl, rpm/dpkg
- **Fonction de patching** : Mise à jour de l'agent sans réinstallation complète
- **Health check complet** : Diagnostic approfondi de l'état de l'agent
- **Consultation des logs** : Affichage centralisé des logs du service et du script
- **Mode non-interactif** : Options CLI pour l'automatisation et l'intégration CI/CD

---

## ✅ Prérequis

### Systèmes supportés
- Distributions basées sur **RPM** : Red Hat, CentOS, Fedora, Rocky Linux, AlmaLinux
- Distributions basées sur **DEB** : Debian, Ubuntu, Linux Mint

### Dépendances requises
- `curl` : pour le téléchargement des fichiers
- `systemctl` : pour la gestion des services
- `rpm` ou `dpkg` : selon votre distribution (détection automatique)
- Permissions **root** : le script doit être exécuté avec sudo ou en tant que root

---

## 🚀 Installation

Clonez ce dépôt et donnez les permissions d'exécution au script :

```bash
git clone https://github.com/Rooot3301/Ninjaa.git
cd Ninjaa
chmod +x main.sh
```

---

## ⚙️ Configuration

### Création du fichier .env

Copiez le fichier d'exemple et adaptez-le à votre environnement :

```bash
cp .env.example .env
nano .env
```

### Variables de configuration

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `PREDEFINED_AGENT_URL` | URL de téléchargement de l'agent | `http://example.com/agent.rpm` |
| `SERVICE_NAME` | Nom du service systemd | `ninjarmm-agent.service` |
| `LOG_FILE` | Chemin du fichier de logs | `/var/log/ninjarmm_agent_manager.log` |
| `DOWNLOAD_DIR` | Répertoire de téléchargement | `/tmp` |
| `AGENT_PACKAGE_NAME` | Nom du package | `ninjarmm-agent` |
| `AGENT_PACKAGE_TYPE` | Type de package (auto/rpm/deb) | `auto` |
| `LOG_LEVEL` | Niveau de logs (ERROR/WARN/INFO/DEBUG) | `INFO` |

### Exemple de configuration

```bash
# Pour NinjaRMM sur Red Hat/CentOS
PREDEFINED_AGENT_URL=https://app.ninjarmm.com/agent/installer/YOUR_INSTALLER_ID/agent.rpm
SERVICE_NAME=ninjarmm-agent.service
AGENT_PACKAGE_NAME=ninjarmm-agent
AGENT_PACKAGE_TYPE=rpm

# Pour un agent sur Ubuntu/Debian
PREDEFINED_AGENT_URL=https://your-server.com/agent.deb
AGENT_PACKAGE_TYPE=deb

# Variables additionnelles (optionnelles)
# - `INSTALL_SCRIPT_URL` : URL d'un script d'installation distant (exécutable) fourni par le vendor
# - `INSTALLER_ID` : Identifiant d'installateur (si requis par le fournisseur)
# - `INSTALL_TOKEN` : Token d'installation (si requis pour l'installateur)
# - `CHECKSUM` : Valeur SHA256 attendue du binaire/script téléchargé (pour vérification d'intégrité)

# Exemple :
# INSTALL_SCRIPT_URL=https://app.ninjarmm.com/installers/install.sh
# INSTALLER_ID=12345
# INSTALL_TOKEN=abcdef0123456789
# CHECKSUM=0123456789abcdef... (sha256)
```

---

## 💻 Utilisation

### Mode interactif

Lancez le script sans arguments pour accéder au menu interactif :

```bash
sudo ./main.sh
```

#### Menu principal

```
1) Installer l'agent (lien prédéfini)
2) Installer l'agent (lien personnalisé)
3) Vérifier le statut du service
4) Mettre à jour l'agent (Patch)
5) Désinstaller l'agent
6) Afficher les logs
7) Diagnostic de santé (Health Check)
8) Quitter
```

### Mode non-interactif

Utilisez les options CLI pour l'automatisation :

```bash
# Installer l'agent avec l'URL prédéfinie
sudo ./main.sh --install-default

# Vérifier le statut du service
sudo ./main.sh --status

# Effectuer un diagnostic complet
sudo ./main.sh --health-check

# Afficher l'aide
./main.sh --help
```

### Exemples d'utilisation

#### Installation automatisée

```bash
# Configuration de l'environnement
echo "PREDEFINED_AGENT_URL=https://app.ninjarmm.com/agent/installer/12345/agent.rpm" > .env

# Installation silencieuse
sudo ./main.sh --install-default
```

#### Vérification dans un script de monitoring

```bash
#!/bin/bash
if sudo ./main.sh --health-check; then
    echo "Agent OK"
    exit 0
else
    echo "Agent KO - Intervention nécessaire"
    exit 1
fi
```

#### Déploiement via Ansible

```yaml
- name: Déployer l'agent RMM
  hosts: servers
  become: yes
  tasks:
    - name: Copier le script et la configuration
      copy:
        src: "{{ item }}"
        dest: /opt/rmm-manager/
        mode: '0755'
      with_items:
        - main.sh
        - .env

    - name: Installer l'agent
      command: /opt/rmm-manager/main.sh --install-default
      args:
        creates: /usr/bin/ninjarmm-agent
```

---

## 🔧 Détails techniques

### Gestion robuste des erreurs

Le script utilise `set -euo pipefail` pour :
- `-e` : Arrêt immédiat en cas d'erreur
- `-u` : Erreur si une variable non définie est utilisée
- `-o pipefail` : Erreur si une commande dans un pipe échoue

### Détection automatique du package

Le script détecte automatiquement le type de package :
1. Si `AGENT_PACKAGE_TYPE=auto` (par défaut)
2. Analyse l'extension du fichier (.rpm ou .deb)
3. Utilise la commande d'installation appropriée

### Support multi-distributions

#### Pour RPM (Red Hat, CentOS, Fedora)
- Installation : `rpm -i package.rpm`
- Mise à jour : `rpm -U package.rpm`
- Désinstallation : `rpm -e package-name`

#### Pour DEB (Debian, Ubuntu)
- Installation : `dpkg -i package.deb && apt-get install -f -y`
- Mise à jour : `dpkg -i package.deb && apt-get install -f -y`
- Désinstallation : `dpkg -r package-name`

### Health Check

Le diagnostic vérifie :
1. **Installation du package** : Présence via rpm/dpkg
2. **État du service** : Actif/Inactif via systemctl
3. **Activation au démarrage** : Enabled/Disabled
4. **Processus en cours** : Recherche via pgrep

---

## 📊 Logs

### Fichier de logs du script

Par défaut : `/var/log/ninjarmm_agent_manager.log`

Format des logs :
```
[INFO] 2025-12-03 14:30:45 - Installation réussie depuis http://example.com/agent.rpm
[ERROR] 2025-12-03 14:35:12 - Échec du téléchargement depuis http://invalid-url.com
[WARN] 2025-12-03 14:40:23 - Le service ninjarmm-agent.service n'est pas actif
```

### Rotation automatique

- Taille maximale : **10 MB**
- Ancien fichier : `${LOG_FILE}.old`
- Rotation automatique à chaque démarrage du script

### Niveaux de logs

Configurez `LOG_LEVEL` dans le fichier `.env` :

- **ERROR** : Seulement les erreurs critiques
- **WARN** : Erreurs + avertissements
- **INFO** : Erreurs + avertissements + informations (recommandé)
- **DEBUG** : Tous les messages (très verbeux)

### Consultation des logs

```bash
# Via le menu interactif (option 6)
sudo ./main.sh
# Puis choisir l'option 6

# Manuellement
sudo tail -f /var/log/ninjarmm_agent_manager.log

# Logs du service
sudo journalctl -u ninjarmm-agent.service -f
```

---

## 🔒 Sécurité

- **Permissions root requises** : Vérification automatique au démarrage
- **Validation des téléchargements** : `curl --fail` pour échouer en cas d'erreur HTTP
- **Gestion sécurisée des fichiers** : Utilisation de `/tmp` par défaut avec possibilité de personnalisation
- **Logs protégés** : Écriture dans `/var/log` avec fallback vers `/tmp` si nécessaire
- **Pas de secrets dans le code** : Configuration externalisée dans `.env`

---

## 🐛 Dépannage

### Le script ne démarre pas

```bash
# Vérifier les permissions
ls -l main.sh
# Doit afficher : -rwxr-xr-x

# Rendre exécutable si nécessaire
chmod +x main.sh

# Vérifier que vous êtes root
sudo -i
whoami  # Doit afficher : root
```

### Erreur de dépendances manquantes

```bash
# Sur Red Hat/CentOS/Fedora
sudo dnf install curl systemd

# Sur Debian/Ubuntu
sudo apt update
sudo apt install curl systemd
```

### Le téléchargement échoue

```bash
# Tester manuellement l'URL
curl -I https://your-agent-url.com/agent.rpm

# Vérifier la configuration
cat .env | grep PREDEFINED_AGENT_URL

# Vérifier les logs
sudo tail -n 50 /var/log/ninjarmm_agent_manager.log
```

### Le service ne démarre pas

```bash
# Vérifier l'état détaillé
sudo systemctl status ninjarmm-agent.service

# Voir les logs du service
sudo journalctl -u ninjarmm-agent.service -n 50

# Réinstaller l'agent
sudo ./main.sh
# Choisir option 5 (désinstaller) puis option 1 (réinstaller)
```

---

## 🤝 Contributions

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Forker le projet
2. Créer une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Commiter vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Pousser vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## 📝 Changelog

### v2.0 (2025-12-03)
- Ajout de la configuration externalisée (.env)
- Support complet des packages .deb (Debian/Ubuntu)
- Détection automatique du type de package
- Gestion d'erreurs renforcée (set -euo pipefail)
- Système de logs amélioré avec rotation
- Vérification automatique des dépendances
- Fonction de patching/mise à jour
- Health check complet
- Consultation centralisée des logs
- Mode non-interactif avec options CLI
- Menu adapté avec 8 options

### v1.0 (2024)
- Version initiale
- Support RPM uniquement
- Installation et désinstallation basiques
- Vérification du service
- Logs simples

---

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

---

## 👤 Auteur

**Root3301 (R.V)**

- GitHub: [@Rooot3301](https://github.com/Rooot3301)

---

## 🙏 Remerciements

Merci à tous les contributeurs et utilisateurs de ce script !

---

**Note** : Ce script est conçu pour fonctionner avec NinjaRMM mais peut être facilement adapté pour d'autres agents RMM en modifiant les variables de configuration dans le fichier `.env`.
