# RMM Agent Manager v3.0

Script shell avancé pour gérer l'installation, la mise à jour, la vérification et la désinstallation d'agents RMM (comme NinjaRMM) sur des machines Linux. Ce script supporte aussi bien les distributions basées sur RPM (Red Hat, CentOS, Fedora) que sur DEB (Debian, Ubuntu).

---

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Nouveautés v3.0](#nouveautés-v30)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
  - [Mode interactif](#mode-interactif)
  - [Mode non-interactif](#mode-non-interactif)
- [Détails techniques](#détails-techniques)
- [Logs](#logs)
- [Sécurité](#sécurité)
- [Dépannage](#dépannage)
- [Contributions](#contributions)
- [Licence](#licence)

---

## Fonctionnalités

- **Installation de l'agent** : Téléchargement et installation depuis une URL prédéfinie, personnalisée, ou via un script/token distant
- **Support multi-distributions** : Gestion automatique des packages RPM et DEB
- **Gestion du service** : Démarrage, arrêt, redémarrage et vérification du statut via systemd
- **Mise à jour (Patch)** : Mise à jour de l'agent existant
- **Désinstallation** : Suppression complète de l'agent
- **Consultation des logs** : Affichage des logs du service (journalctl) et du script
- **Diagnostic de santé** : Vérification complète (package, service, MainPID, processus)
- **Mode non-interactif** : Exécution en ligne de commande pour l'automatisation
- **Vérification d'intégrité** : Contrôle SHA256 du fichier téléchargé
- **Gestion robuste des erreurs** : Protection contre les échecs de téléchargement et d'installation
- **Rotation des logs** : Rotation automatique des fichiers de logs au-delà de 10 MB
- **Configuration externalisée** : Toutes les variables dans un fichier `.env`
- **Drop-in systemd** : Override systemd optionnel pour éviter les crash-loops
- **Détection SELinux/AppArmor** : Avertissement si un LSM actif est détecté

---

## Nouveautés v3.0

### Améliorations majeures

- **Configuration externalisée** : Fichier `.env` pour toutes les variables avec valeurs par défaut
- **Support .deb** : Ajout du support complet pour Debian/Ubuntu en plus de RPM
- **Détection automatique** : Détection intelligente du type de package (.rpm ou .deb)
- **Gestion d'erreurs renforcée** : `set -euo pipefail`, `curl --fail`, validation à chaque étape
- **Système de logs amélioré** : Rotation automatique, niveaux de logs (ERROR, WARN, INFO, DEBUG)
- **Vérification des dépendances** : Contrôle automatique de la présence de curl, systemctl, rpm/dpkg
- **Fonction de patching** : Mise à jour de l'agent sans réinstallation complète
- **Health check complet** : Diagnostic via MainPID systemd + fallback pgrep
- **Consultation des logs** : Affichage centralisé des logs du service et du script
- **Mode non-interactif** : Options CLI pour l'automatisation et l'intégration CI/CD
- **Installation via script/token** : Support des installateurs distants fournis par le vendor
- **Vérification SHA256** : Contrôle d'intégrité optionnel du fichier téléchargé
- **Drop-in systemd sûr** : Création optionnelle d'un override `Restart=on-failure`
- **Détection SELinux/AppArmor** : Avertissement automatique si un LSM actif est détecté
- **Menu hiérarchique** : Navigation en sous-menus (Installation, Service, Maintenance, Logs)
- **Guards de sécurité** : `ALLOW_INSTALL=false` par défaut — aucune exécution automatique sans consentement explicite

---

## Prérequis

### Systèmes supportés

- Distributions basées sur **RPM** : Red Hat, CentOS, Fedora, Rocky Linux, AlmaLinux
- Distributions basées sur **DEB** : Debian, Ubuntu, Linux Mint

### Dépendances requises

- `curl` : pour le téléchargement des fichiers
- `systemctl` : pour la gestion des services
- `rpm` ou `dpkg` : selon votre distribution (détection automatique)
- Permissions **root** : le script doit être exécuté avec sudo ou en tant que root

---

## Installation

Clonez ce dépôt et donnez les permissions d'exécution au script :

```bash
git clone https://github.com/Rooot3301/Ninjaa.git
cd Ninjaa
chmod +x main.sh
```

---

## Configuration

### Création du fichier .env

Copiez le fichier d'exemple et adaptez-le à votre environnement :

```bash
cp .env.example .env
nano .env
```

Si le fichier `.env` est absent au lancement, le script le crée automatiquement depuis `.env.example`.

### Variables de configuration

| Variable | Description | Valeur par défaut |
|---|---|---|
| `PREDEFINED_AGENT_URL` | URL de téléchargement de l'agent | `http://example.com/agent.rpm` |
| `SERVICE_NAME` | Nom du service systemd | `ninjarmm-agent.service` |
| `LOG_FILE` | Chemin du fichier de logs | `/var/log/ninjarmm_agent_manager.log` |
| `DOWNLOAD_DIR` | Répertoire de téléchargement | `/tmp` |
| `AGENT_PACKAGE_NAME` | Nom du package | `ninjarmm-agent` |
| `AGENT_PACKAGE_TYPE` | Type de package (auto/rpm/deb) | `auto` |
| `LOG_LEVEL` | Niveau de logs (ERROR/WARN/INFO/DEBUG) | `INFO` |
| `ALLOW_INSTALL` | Autoriser l'exécution automatique de l'installateur | `false` |
| `SYSTEMD_SAFE_OVERRIDE` | Créer un drop-in systemd `Restart=on-failure` | `false` |
| `INSTALL_SCRIPT_URL` | URL d'un script d'installation distant (vendor) | _(optionnel)_ |
| `INSTALLER_ID` | Identifiant d'installateur requis par le vendor | _(optionnel)_ |
| `INSTALL_TOKEN` | Token d'installation requis par l'installateur | _(optionnel)_ |
| `CHECKSUM` | Valeur SHA256 attendue du fichier téléchargé | _(optionnel)_ |

### Exemple de configuration

```bash
# Pour NinjaRMM sur Red Hat/CentOS
PREDEFINED_AGENT_URL=https://app.ninjarmm.com/agent/installer/YOUR_INSTALLER_ID/agent.rpm
SERVICE_NAME=ninjarmm-agent.service
AGENT_PACKAGE_NAME=ninjarmm-agent
AGENT_PACKAGE_TYPE=rpm
ALLOW_INSTALL=true

# Pour un agent sur Ubuntu/Debian
PREDEFINED_AGENT_URL=https://your-server.com/agent.deb
AGENT_PACKAGE_TYPE=deb
ALLOW_INSTALL=true

# Avec vérification d'intégrité
CHECKSUM=0123456789abcdef...  # SHA256 du fichier téléchargé

# Via script d'installation distant (vendor)
INSTALL_SCRIPT_URL=https://app.ninjarmm.com/installers/install.sh
INSTALLER_ID=12345
INSTALL_TOKEN=abcdef0123456789
ALLOW_INSTALL=true

# Drop-in systemd (redémarrage automatique en cas de crash)
SYSTEMD_SAFE_OVERRIDE=true
```

---

## Utilisation

### Mode interactif

Lancez le script sans arguments pour accéder au menu interactif :

```bash
sudo ./main.sh
```

#### Menu principal

```
1) Installation
2) Gestion du service
3) Maintenance
4) Logs & Diagnostics
5) Quitter
```

#### Sous-menu Installation

```
1) Installer l'agent (lien prédéfini)
2) Installer l'agent (lien personnalisé)
3) Installer l'agent via script/token
4) Retour
```

#### Sous-menu Gestion du service

```
1) Vérifier le statut du service
2) Démarrer le service
3) Arrêter le service
4) Redémarrer le service
5) Retour
```

#### Sous-menu Maintenance

```
1) Mettre à jour l'agent (Patch)
2) Désinstaller l'agent
3) Diagnostic de santé (Health Check)
4) Retour
```

#### Sous-menu Logs & Diagnostics

```
1) Afficher les logs
2) Diagnostic de santé (Health Check)
3) Retour
```

### Mode non-interactif

Utilisez les options CLI pour l'automatisation :

```bash
# Installer l'agent avec l'URL prédéfinie
sudo ./main.sh --install-default

# Installer l'agent via script/token (INSTALL_SCRIPT_URL requis dans .env)
sudo ./main.sh --install-with-token

# Vérifier le statut du service
sudo ./main.sh --status

# Effectuer un diagnostic complet
sudo ./main.sh --health-check

# Afficher l'aide
./main.sh --help
```

Les flags globaux suivants peuvent être passés **avant** la commande pour surcharger le `.env` :

```bash
# Activer le drop-in systemd pour cette exécution
sudo ./main.sh --systemd-override --install-default

# Autoriser l'installation automatique pour cette exécution
sudo ./main.sh --allow-install --install-default
```

### Exemples d'utilisation

#### Installation automatisée

```bash
# Configuration
echo "PREDEFINED_AGENT_URL=https://app.ninjarmm.com/agent/installer/12345/agent.rpm" > .env
echo "ALLOW_INSTALL=true" >> .env

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

## Détails techniques

### Gestion robuste des erreurs

Le script utilise `set -euo pipefail` pour :

- `-e` : Arrêt immédiat en cas d'erreur
- `-u` : Erreur si une variable non définie est utilisée
- `-o pipefail` : Erreur si une commande dans un pipe échoue

### Détection automatique du package

Le script détecte automatiquement le type de package :

1. Si `AGENT_PACKAGE_TYPE=auto` (par défaut)
2. Analyse l'extension du fichier (`.rpm` ou `.deb`)
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

### Vérification d'intégrité (SHA256)

Si `CHECKSUM` est défini dans le `.env`, le script vérifie l'empreinte SHA256 du fichier téléchargé avant toute installation. Compatible avec `sha256sum` (Linux) et `shasum -a 256` (macOS/BSD).

### Installation via script distant

Lorsque `INSTALL_SCRIPT_URL` est défini, le script télécharge l'installateur du vendor :

1. Téléchargement dans `DOWNLOAD_DIR`
2. Vérification SHA256 si `CHECKSUM` est fourni
3. Si `ALLOW_INSTALL=false` (défaut) : le fichier est conservé localement et l'exécution manuelle est indiquée
4. Si `ALLOW_INSTALL=true` : exécution du script avec `INSTALLER_TOKEN` ou `INSTALLER_ID` injectés en variable d'environnement

### Drop-in systemd

Si `SYSTEMD_SAFE_OVERRIDE=true` (ou `--systemd-override`), le script crée `/etc/systemd/system/<SERVICE_NAME>.d/override.conf` avec :

```ini
[Unit]
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Restart=on-failure
RestartSec=5
```

Un `systemctl daemon-reload` est effectué automatiquement. Le redémarrage du service reste **manuel** pour éviter toute interruption non souhaitée.

### Health Check

Le diagnostic vérifie dans l'ordre :

1. **Installation du package** : Présence via `rpm -q` ou `dpkg -s` (vérifie le champ `Status: install ok installed`)
2. **État du service** : Actif/Inactif via `systemctl is-active`
3. **Activation au démarrage** : Enabled/Disabled via `systemctl is-enabled`
4. **Processus principal** : Via `MainPID` fourni par systemd (`/proc/<pid>`) — fallback sur `pgrep` si MainPID indisponible

### Détection SELinux / AppArmor

Avant l'installation via script distant, le script vérifie :

- **SELinux** : si `getenforce` retourne `Enforcing`, un avertissement est affiché
- **AppArmor** : si `aa-status --enabled` est actif, un avertissement est affiché

Ces vérifications sont informatives ; elles n'interrompent pas l'installation.

---

## Logs

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
# Via le menu interactif : Logs & Diagnostics > Afficher les logs

# Manuellement
sudo tail -f /var/log/ninjarmm_agent_manager.log

# Logs du service
sudo journalctl -u ninjarmm-agent.service -f
```

---

## Sécurité

- **Permissions root requises** : Vérification automatique au démarrage
- **`ALLOW_INSTALL=false` par défaut** : aucun installateur distant n'est exécuté sans activation explicite
- **Validation des téléchargements** : `curl --fail` pour échouer en cas d'erreur HTTP
- **Vérification SHA256** : contrôle d'intégrité optionnel via `CHECKSUM`
- **Normalisation des variables** : suppression des caractères CR/newline et `basename` sur les noms sensibles pour éviter les injections de chemin
- **Gestion sécurisée des fichiers** : utilisation de `/tmp` par défaut, suppression du fichier téléchargé après installation
- **Logs protégés** : écriture dans `/var/log` avec fallback vers `/tmp` si nécessaire
- **Pas de secrets dans le code** : configuration externalisée dans `.env` (exclu du dépôt via `.gitignore`)

---

## Dépannage

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
grep PREDEFINED_AGENT_URL .env

# Vérifier les logs
sudo tail -n 50 /var/log/ninjarmm_agent_manager.log
```

### Le service ne démarre pas

```bash
# Vérifier l'état détaillé
sudo systemctl status ninjarmm-agent.service

# Voir les logs du service
sudo journalctl -u ninjarmm-agent.service -n 50

# Réinstaller l'agent via le menu interactif
sudo ./main.sh
# Installation > Installer l'agent (lien prédéfini)
```

### L'installation est bloquée (ALLOW_INSTALL=false)

Par défaut, l'exécution automatique est désactivée. Pour l'activer :

```bash
# Option 1 : via le .env
echo "ALLOW_INSTALL=true" >> .env

# Option 2 : via flag CLI (une seule exécution)
sudo ./main.sh --allow-install --install-default
```

---

## Contributions

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Forker le projet
2. Créer une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Commiter vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Pousser vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## Changelog

### v3.0 (2026-05-29)

- Configuration externalisée (.env) avec auto-création depuis .env.example
- Support complet des packages .deb (Debian/Ubuntu)
- Détection automatique du type de package
- Gestion d'erreurs renforcée (set -euo pipefail)
- Système de logs amélioré avec rotation
- Vérification automatique des dépendances
- Fonction de patching/mise à jour
- Health check : MainPID systemd + fallback pgrep
- Consultation centralisée des logs
- Mode non-interactif avec options CLI (`--install-default`, `--install-with-token`, `--status`, `--health-check`)
- Flags globaux CLI (`--allow-install`, `--systemd-override`)
- Installation via script/token distant (INSTALL_SCRIPT_URL)
- Vérification d'intégrité SHA256 (CHECKSUM)
- Drop-in systemd sûr (SYSTEMD_SAFE_OVERRIDE)
- Détection SELinux/AppArmor
- Menu hiérarchique (Installation, Service, Maintenance, Logs & Diagnostics)
- Guard ALLOW_INSTALL=false par défaut

### v1.0 (2024)

- Version initiale
- Support RPM uniquement
- Installation et désinstallation basiques
- Vérification du service
- Logs simples

---

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

---

## Auteur

**Root3301 (R.V)**

- GitHub: [@Rooot3301](https://github.com/Rooot3301)

---

Merci à tous les contributeurs et utilisateurs de ce script !

---

**Note** : Ce script est conçu pour fonctionner avec NinjaRMM mais peut être facilement adapté pour d'autres agents RMM en modifiant les variables de configuration dans le fichier `.env`.
