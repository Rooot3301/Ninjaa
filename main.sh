#!/bin/bash

set -euo pipefail

# =====================================
#      RMM Agent Manager v3.0
#      Created by Root3301 (R.V)
# =====================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
        echo -e "\033[1;33mAucun fichier .env trouvé. Création automatique depuis .env.example…\033[0m"
        cp "${SCRIPT_DIR}/.env.example" "$ENV_FILE"
        echo -e "\033[1;32mFichier .env créé avec succès.\033[0m"
    else
        echo -e "\033[1;31m⚠️ Fichier .env introuvable !\033[0m"
        echo -e "\033[1;33mVeuillez créer un fichier .env à partir de .env.example\033[0m"
        echo -e "\033[1;34mCommande : cp .env.example .env\033[0m"
        exit 1
    fi
fi

set -a
source "$ENV_FILE"
set +a

# Valeurs par défaut sûres pour éviter les erreurs avec `set -u`
: "${PREDEFINED_AGENT_URL:=http://example.com/agent.rpm}"
: "${SERVICE_NAME:=ninjarmm-agent.service}"
: "${LOG_FILE:=/var/log/ninjarmm_agent_manager.log}"
: "${DOWNLOAD_DIR:=/tmp}"
: "${AGENT_PACKAGE_NAME:=ninjarmm-agent}"
: "${AGENT_PACKAGE_TYPE:=auto}"
: "${LOG_LEVEL:=INFO}"

# Normalisation basique des variables (suppression CR/newline, sécurisation de noms)
PREDEFINED_AGENT_URL="$(echo "$PREDEFINED_AGENT_URL" | tr -d '\r\n')"
SERVICE_NAME="$(basename "$SERVICE_NAME")"
AGENT_PACKAGE_NAME="$(basename "$AGENT_PACKAGE_NAME")"
LOG_FILE="$(echo "$LOG_FILE" | tr -d '\r')"

# S'assurer que le répertoire de téléchargement existe
if [[ ! -d "$DOWNLOAD_DIR" ]]; then
    mkdir -p "$DOWNLOAD_DIR" 2>/dev/null || DOWNLOAD_DIR="/tmp"
fi

GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

function check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}⚠️ Ce script doit être exécuté en tant qu'utilisateur root.${NC}"
        exit 1
    fi
}

function init_log() {
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"

    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            echo -e "${YELLOW}⚠️ Impossible de créer le répertoire de logs. Utilisation de /tmp${NC}"
            LOG_FILE="/tmp/ninjarmm_agent_manager.log"
        }
    fi

    if [[ ! -f "$LOG_FILE" ]]; then
        {
            echo "=== RMM Agent Manager Script v3.0 ==="
            echo "Initialisé le : $(date)"
            echo "======================================="
        } > "$LOG_FILE" 2>/dev/null || {
            echo -e "${YELLOW}⚠️ Impossible d'écrire dans le fichier de logs.${NC}"
            LOG_FILE="/dev/null"
        }
    fi

    rotate_logs
}

function rotate_logs() {
    local max_size=$((10 * 1024 * 1024))

    if [[ -f "$LOG_FILE" ]] && [[ "$LOG_FILE" != "/dev/null" ]]; then
        local file_size
        file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)

        if [[ $file_size -gt $max_size ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old" 2>/dev/null || true
            touch "$LOG_FILE" 2>/dev/null || true
        fi
    fi
}

function log_message() {
    local log_type="$1"
    local log_message="$2"

    case "$LOG_LEVEL" in
        ERROR)
            [[ "$log_type" == "ERROR" ]] || return 0
            ;;
        WARN)
            [[ "$log_type" =~ ^(ERROR|WARN)$ ]] || return 0
            ;;
        INFO)
            [[ "$log_type" =~ ^(ERROR|WARN|INFO)$ ]] || return 0
            ;;
        DEBUG)
            ;;
    esac

    echo "[${log_type}] $(date '+%Y-%m-%d %H:%M:%S') - $log_message" >> "$LOG_FILE" 2>/dev/null || true
}

function check_dependencies() {
    local missing_deps=()

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v systemctl &> /dev/null; then
        missing_deps+=("systemctl")
    fi

    if [[ "$AGENT_PACKAGE_TYPE" == "rpm" ]] || [[ "$AGENT_PACKAGE_TYPE" == "auto" ]]; then
        if ! command -v rpm &> /dev/null; then
            if [[ "$AGENT_PACKAGE_TYPE" == "rpm" ]]; then
                missing_deps+=("rpm")
            fi
        fi
    fi

    if [[ "$AGENT_PACKAGE_TYPE" == "deb" ]] || [[ "$AGENT_PACKAGE_TYPE" == "auto" ]]; then
        if ! command -v dpkg &> /dev/null; then
            if [[ "$AGENT_PACKAGE_TYPE" == "deb" ]]; then
                missing_deps+=("dpkg")
            fi
        fi
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        display_message "$RED" "⚠️ Dépendances manquantes : ${missing_deps[*]}"
        log_message "ERROR" "Dépendances manquantes : ${missing_deps[*]}"
        return 1
    fi

    log_message "INFO" "Toutes les dépendances sont présentes."
    return 0
}

function detect_pkg_manager() {
    if command -v apt-get &> /dev/null || command -v apt &> /dev/null; then
        PKG_FAMILY="deb"
        PKG_TOOL="apt-get"
    elif command -v dnf &> /dev/null; then
        PKG_FAMILY="rpm"
        PKG_TOOL="dnf"
    elif command -v yum &> /dev/null; then
        PKG_FAMILY="rpm"
        PKG_TOOL="yum"
    else
        PKG_FAMILY="unknown"
        PKG_TOOL=""
    fi
    log_message "DEBUG" "Detected package family: $PKG_FAMILY, tool: $PKG_TOOL"
}

function verify_checksum() {
    local file="$1"
    local expected="$2"

    if [[ -z "$expected" ]]; then
        return 0
    fi

    if command -v sha256sum &> /dev/null; then
        local got
        got=$(sha256sum "$file" 2>/dev/null | awk '{print $1}') || got=""
    elif command -v shasum &> /dev/null; then
        local got
        got=$(shasum -a 256 "$file" 2>/dev/null | awk '{print $1}') || got=""
    else
        display_message "$YELLOW" "⚠️ Aucun utilitaire de checksum disponible (sha256sum/shasum). Vérification ignorée."
        return 0
    fi

    if [[ "$got" == "$expected" ]]; then
        log_message "INFO" "Checksum valide pour $file"
        return 0
    else
        log_message "ERROR" "Checksum invalide pour $file (attendu: $expected, obtenu: $got)"
        display_message "$RED" "⚠️ Checksum invalide pour $file"
        return 1
    fi
}

function selinux_apparmor_check() {
    if command -v getenforce &> /dev/null; then
        local se
        se=$(getenforce 2>/dev/null || echo "")
        if [[ "$se" == "Enforcing" ]]; then
            display_message "$YELLOW" "⚠️ SELinux en mode Enforcing détecté — certaines actions peuvent échouer sans contextes SELinux appropriés."
            log_message "WARN" "SELinux Enforcing"
        fi
    fi

    if command -v aa-status &> /dev/null; then
        if aa-status --enabled &> /dev/null; then
            display_message "$YELLOW" "⚠️ AppArmor activé — vérifiez les profiles si l'agent rencontre des problèmes."
            log_message "WARN" "AppArmor activé"
        fi
    fi
}

function install_via_installer_script() {
    # Utilisation d'un installateur distant (script) avec token/ID
    local installer_url="${INSTALL_SCRIPT_URL:-}"
    local installer_id="${INSTALLER_ID:-}"
    local installer_token="${INSTALL_TOKEN:-}"

    if [[ -z "$installer_url" ]]; then
        display_message "$RED" "⚠️ Aucune URL d'installateur fournie dans INSTALL_SCRIPT_URL"
        return 1
    fi

    local installer_file="$DOWNLOAD_DIR/installer.sh"
    echo -e "Téléchargement de l'installateur depuis ${GREEN}$installer_url${NC}..."
    if ! download_file "$installer_url" "$installer_file"; then
        return 1
    fi

    if [[ -n "${CHECKSUM:-}" ]]; then
        if ! verify_checksum "$installer_file" "$CHECKSUM"; then
            rm -f "$installer_file" 2>/dev/null || true
            return 1
        fi
    fi

    chmod +x "$installer_file" 2>/dev/null || true

    # Exécuter le script avec variables d'environnement si fournies
    if [[ -n "$installer_token" ]]; then
        INSTALLER_TOKEN="$installer_token" bash "$installer_file"
    elif [[ -n "$installer_id" ]]; then
        INSTALLER_ID="$installer_id" bash "$installer_file"
    else
        bash "$installer_file"
    fi

    local rc=$?
    rm -f "$installer_file" 2>/dev/null || true
    return $rc
}

function detect_package_type() {
    local filename="$1"

    if [[ "$AGENT_PACKAGE_TYPE" != "auto" ]]; then
        echo "$AGENT_PACKAGE_TYPE"
        return 0
    fi

    if [[ "$filename" =~ \.rpm$ ]]; then
        echo "rpm"
    elif [[ "$filename" =~ \.deb$ ]]; then
        echo "deb"
    else
        echo "unknown"
    fi
}

function install_package() {
    local package_file="$1"
    local pkg_type
    pkg_type=$(detect_package_type "$package_file")

    log_message "INFO" "Type de package détecté : $pkg_type"

    case "$pkg_type" in
        rpm)
            if command -v rpm &> /dev/null; then
                rpm -i "$package_file"
                return $?
            else
                display_message "$RED" "⚠️ rpm n'est pas disponible sur ce système."
                log_message "ERROR" "rpm non disponible."
                return 1
            fi
            ;;
        deb)
            if command -v dpkg &> /dev/null; then
                dpkg -i "$package_file"
                apt-get install -f -y 2>/dev/null || true
                return $?
            else
                display_message "$RED" "⚠️ dpkg n'est pas disponible sur ce système."
                log_message "ERROR" "dpkg non disponible."
                return 1
            fi
            ;;
        *)
            display_message "$RED" "⚠️ Type de package non reconnu."
            log_message "ERROR" "Type de package inconnu : $package_file"
            return 1
            ;;
    esac
}

function uninstall_package() {
    local pkg_type="$AGENT_PACKAGE_TYPE"

    if [[ "$pkg_type" == "auto" ]]; then
        if command -v rpm &> /dev/null && rpm -q "$AGENT_PACKAGE_NAME" &> /dev/null; then
            pkg_type="rpm"
        elif command -v dpkg &> /dev/null && dpkg -l | grep -q "^ii.*$AGENT_PACKAGE_NAME"; then
            pkg_type="deb"
        fi
    fi

    case "$pkg_type" in
        rpm)
            rpm -e "$AGENT_PACKAGE_NAME"
            return $?
            ;;
        deb)
            dpkg -r "$AGENT_PACKAGE_NAME"
            return $?
            ;;
        *)
            display_message "$RED" "⚠️ Impossible de déterminer le type de package."
            return 1
            ;;
    esac
}

function draw_separator() {
    echo -e "${BLUE}=========================================================${NC}"
}

function display_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

function download_file() {
    local url="$1"
    local output="$2"

    if ! curl --fail --location --progress-bar --output "$output" "$url"; then
        log_message "ERROR" "Échec du téléchargement depuis $url"
        return 1
    fi

    log_message "INFO" "Téléchargement réussi : $url -> $output"
    return 0
}

function install_with_default_url() {
    clear
    draw_separator
    display_message "$YELLOW" "Installation depuis le lien prédéfini"
    draw_separator

    local filename
    filename=$(basename "$PREDEFINED_AGENT_URL")
    local target_file="$DOWNLOAD_DIR/$filename"

    echo -e "Téléchargement de l'agent depuis ${GREEN}$PREDEFINED_AGENT_URL${NC}..."

    if download_file "$PREDEFINED_AGENT_URL" "$target_file"; then
        if [[ -n "${CHECKSUM:-}" ]]; then
            if ! verify_checksum "$target_file" "$CHECKSUM"; then
                rm -f "$target_file" 2>/dev/null || true
                return 1
            fi
        fi
        display_message "$GREEN" "Téléchargement réussi. Installation en cours..."

        if install_package "$target_file"; then
            display_message "$GREEN" "✅ L'installation de l'agent a été effectuée avec succès."
            log_message "INFO" "Installation réussie depuis $PREDEFINED_AGENT_URL"
            rm -f "$target_file" 2>/dev/null || true
        else
            display_message "$RED" "⚠️ Erreur lors de l'installation de l'agent."
            log_message "ERROR" "Échec de l'installation depuis $target_file"
            return 1
        fi
    else
        display_message "$RED" "⚠️ Échec du téléchargement."
        log_message "ERROR" "Échec du téléchargement depuis $PREDEFINED_AGENT_URL"
    fi
}

function install_with_custom_url() {
    clear
    draw_separator
    display_message "$YELLOW" "Installation depuis un lien personnalisé"
    draw_separator

    local custom_url
    while true; do
        read -rp "Veuillez entrer l'URL de l'agent : " custom_url
        if [[ -n $custom_url ]]; then
            break
        else
            display_message "$RED" "⚠️ L'URL ne peut pas être vide."
        fi
    done

    local filename
    filename=$(basename "$custom_url")
    local target_file="$DOWNLOAD_DIR/$filename"

    echo -e "Téléchargement de l'agent depuis ${GREEN}$custom_url${NC}..."

    if download_file "$custom_url" "$target_file"; then
        if [[ -n "${CHECKSUM:-}" ]]; then
            if ! verify_checksum "$target_file" "$CHECKSUM"; then
                rm -f "$target_file" 2>/dev/null || true
                return 1
            fi
        fi
        display_message "$GREEN" "Téléchargement réussi. Installation en cours..."

        if install_package "$target_file"; then
            display_message "$GREEN" "✅ L'installation de l'agent a été effectuée avec succès."
            log_message "INFO" "Installation réussie depuis $custom_url"
            rm -f "$target_file" 2>/dev/null || true
        else
            display_message "$RED" "⚠️ Erreur lors de l'installation de l'agent."
            log_message "ERROR" "Échec de l'installation depuis $target_file"
            return 1
        fi
    else
        display_message "$RED" "⚠️ Échec du téléchargement."
        log_message "ERROR" "Échec du téléchargement depuis $custom_url"
        return 1
    fi
}

function start_service() {
    clear
    draw_separator
    display_message "$YELLOW" "Démarrage du service $SERVICE_NAME"
    draw_separator

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        display_message "$YELLOW" "ℹ️ Le service est déjà actif."
        log_message "INFO" "Tentative de démarrage d'un service déjà actif."
        return 0
    fi

    if systemctl start "$SERVICE_NAME" 2>&1; then
        display_message "$GREEN" "✅ Le service $SERVICE_NAME a été démarré avec succès."
        log_message "INFO" "Service $SERVICE_NAME démarré."
        sleep 2
        systemctl status "$SERVICE_NAME" --no-pager | head -n 10
    else
        display_message "$RED" "⚠️ Échec du démarrage du service."
        log_message "ERROR" "Échec du démarrage du service $SERVICE_NAME."
        return 1
    fi
}

function stop_service() {
    clear
    draw_separator
    display_message "$YELLOW" "Arrêt du service $SERVICE_NAME"
    draw_separator

    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        display_message "$YELLOW" "ℹ️ Le service est déjà arrêté."
        log_message "INFO" "Tentative d'arrêt d'un service déjà arrêté."
        return 0
    fi

    if systemctl stop "$SERVICE_NAME" 2>&1; then
        display_message "$GREEN" "✅ Le service $SERVICE_NAME a été arrêté avec succès."
        log_message "INFO" "Service $SERVICE_NAME arrêté."
    else
        display_message "$RED" "⚠️ Échec de l'arrêt du service."
        log_message "ERROR" "Échec de l'arrêt du service $SERVICE_NAME."
        return 1
    fi
}

function restart_service() {
    clear
    draw_separator
    display_message "$YELLOW" "Redémarrage du service $SERVICE_NAME"
    draw_separator

    if systemctl restart "$SERVICE_NAME" 2>&1; then
        display_message "$GREEN" "✅ Le service $SERVICE_NAME a été redémarré avec succès."
        log_message "INFO" "Service $SERVICE_NAME redémarré."
        sleep 2
        systemctl status "$SERVICE_NAME" --no-pager | head -n 10
    else
        display_message "$RED" "⚠️ Échec du redémarrage du service."
        log_message "ERROR" "Échec du redémarrage du service $SERVICE_NAME."
        return 1
    fi
}

function check_service_status() {
    clear
    draw_separator
    display_message "$YELLOW" "Vérification du statut du service $SERVICE_NAME"
    draw_separator

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        display_message "$GREEN" "✅ Le service $SERVICE_NAME est actif."
        systemctl status "$SERVICE_NAME" --no-pager | head -n 10
        log_message "INFO" "Le service $SERVICE_NAME est actif."
    else
        display_message "$RED" "❌ Le service $SERVICE_NAME n'est pas actif."
        echo -e "💡 Essayez : ${BLUE}sudo systemctl start $SERVICE_NAME${NC}"
        log_message "WARN" "Le service $SERVICE_NAME n'est pas actif."
    fi
}

function uninstall_agent() {
    clear
    draw_separator
    display_message "$YELLOW" "Désinstallation de l'agent"
    draw_separator

    if uninstall_package; then
        display_message "$GREEN" "✅ L'agent a été désinstallé avec succès."
        log_message "INFO" "Désinstallation réussie."
    else
        display_message "$RED" "⚠️ Erreur lors de la désinstallation."
        log_message "ERROR" "Échec de la désinstallation."
    fi
}

function show_logs() {
    clear
    draw_separator
    display_message "$YELLOW" "Affichage des logs du service"
    draw_separator

    if systemctl list-units --full --all | grep -q "$SERVICE_NAME"; then
        echo -e "${BLUE}Logs du service $SERVICE_NAME (20 dernières lignes) :${NC}"
        journalctl -u "$SERVICE_NAME" -n 20 --no-pager
        log_message "INFO" "Consultation des logs du service."
    else
        display_message "$RED" "⚠️ Le service $SERVICE_NAME n'existe pas."
        log_message "WARN" "Tentative de consultation des logs d'un service inexistant."
    fi

    echo ""
    echo -e "${BLUE}Logs du script (20 dernières lignes) :${NC}"
    if [[ -f "$LOG_FILE" ]] && [[ "$LOG_FILE" != "/dev/null" ]]; then
        tail -n 20 "$LOG_FILE"
    else
        echo "Aucun fichier de logs disponible."
    fi
}

function health_check() {
    clear
    draw_separator
    display_message "$YELLOW" "Diagnostic de santé de l'agent"
    draw_separator

    local status=0

    echo -e "${BLUE}1. Vérification de l'installation du package...${NC}"
    if command -v rpm &> /dev/null && rpm -q "$AGENT_PACKAGE_NAME" &> /dev/null; then
        display_message "$GREEN" "✅ Package installé (RPM)"
        rpm -qi "$AGENT_PACKAGE_NAME" | grep -E "(Name|Version|Install Date)"
    elif command -v dpkg &> /dev/null && dpkg -l | grep -q "^ii.*$AGENT_PACKAGE_NAME"; then
        display_message "$GREEN" "✅ Package installé (DEB)"
        dpkg -l | grep "$AGENT_PACKAGE_NAME"
    else
        display_message "$RED" "❌ Package non installé"
        status=1
    fi

    echo ""
    echo -e "${BLUE}2. Vérification du service...${NC}"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        display_message "$GREEN" "✅ Service actif"
        systemctl show "$SERVICE_NAME" --property=MainPID,ActiveState,SubState --no-pager
    else
        display_message "$RED" "❌ Service inactif"
        status=1
    fi

    echo ""
    echo -e "${BLUE}3. Vérification du statut enabled...${NC}"
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        display_message "$GREEN" "✅ Service activé au démarrage"
    else
        display_message "$YELLOW" "⚠️ Service non activé au démarrage"
    fi

    echo ""
    echo -e "${BLUE}4. Vérification des processus...${NC}"
    if pgrep -f "$AGENT_PACKAGE_NAME" > /dev/null; then
        display_message "$GREEN" "✅ Processus en cours d'exécution"
        pgrep -fa "$AGENT_PACKAGE_NAME"
    else
        display_message "$RED" "❌ Aucun processus trouvé"
        status=1
    fi

    echo ""
    draw_separator
    if [[ $status -eq 0 ]]; then
        display_message "$GREEN" "✅ L'agent est en bonne santé"
        log_message "INFO" "Health check: OK"
    else
        display_message "$RED" "❌ Des problèmes ont été détectés"
        log_message "WARN" "Health check: Problèmes détectés"
    fi

    return $status
}

function patch_agent() {
    clear
    draw_separator
    display_message "$YELLOW" "Mise à jour (Patch) de l'agent"
    draw_separator

    echo "Choix de la source de mise à jour :"
    echo "1) Utiliser l'URL prédéfinie"
    echo "2) Entrer une URL personnalisée"
    echo "3) Retour au menu principal"
    draw_separator
    read -rp "→ Votre choix : " patch_choice

    local patch_url=""

    case $patch_choice in
        1)
            patch_url="$PREDEFINED_AGENT_URL"
            ;;
        2)
            read -rp "Veuillez entrer l'URL de mise à jour : " patch_url
            if [[ -z "$patch_url" ]]; then
                display_message "$RED" "⚠️ URL vide. Annulation."
                return 1
            fi
            ;;
        3)
            return 0
            ;;
        *)
            display_message "$RED" "⚠️ Option invalide."
            return 1
            ;;
    esac

    local filename
    filename=$(basename "$patch_url")
    local target_file="$DOWNLOAD_DIR/$filename"

    echo -e "Téléchargement de la mise à jour depuis ${GREEN}$patch_url${NC}..."

    if download_file "$patch_url" "$target_file"; then
        display_message "$GREEN" "Téléchargement réussi."

        local service_was_running=false
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            service_was_running=true
            display_message "$YELLOW" "Arrêt du service avant la mise à jour..."
            systemctl stop "$SERVICE_NAME" || true
            sleep 2
        fi

        display_message "$YELLOW" "Installation de la mise à jour..."
        local pkg_type
        pkg_type=$(detect_package_type "$target_file")
        local update_success=false

        case "$pkg_type" in
            rpm)
                if rpm -U "$target_file" 2>&1; then
                    update_success=true
                fi
                ;;
            deb)
                if dpkg -i "$target_file" 2>&1 && apt-get install -f -y 2>&1; then
                    update_success=true
                fi
                ;;
            *)
                display_message "$RED" "⚠️ Type de package non reconnu."
                log_message "ERROR" "Type de package inconnu pour le patch : $target_file"
                return 1
                ;;
        esac

        if [[ "$update_success" == "true" ]]; then
            display_message "$GREEN" "✅ Mise à jour effectuée avec succès."
            log_message "INFO" "Patch réussi depuis $patch_url"

            if [[ "$service_was_running" == "true" ]]; then
                display_message "$YELLOW" "Redémarrage du service..."
                sleep 2
                if systemctl start "$SERVICE_NAME" 2>&1; then
                    display_message "$GREEN" "✅ Service redémarré avec succès."
                    log_message "INFO" "Service redémarré après patch."
                else
                    display_message "$RED" "⚠️ Échec du redémarrage du service."
                    log_message "ERROR" "Échec du redémarrage après patch."
                fi
            fi

            rm -f "$target_file" 2>/dev/null || true
        else
            display_message "$RED" "⚠️ Erreur lors de la mise à jour."
            log_message "ERROR" "Échec du patch depuis $target_file"

            if [[ "$service_was_running" == "true" ]]; then
                display_message "$YELLOW" "Tentative de redémarrage du service..."
                systemctl start "$SERVICE_NAME" 2>&1 || true
            fi
        fi
    else
        display_message "$RED" "⚠️ Échec du téléchargement de la mise à jour."
        log_message "ERROR" "Échec du téléchargement du patch depuis $patch_url"
        return 1
    fi
}

function show_header() {
    clear
    echo -e "${GREEN}"
    echo "███╗   ██╗██╗███╗   ██╗     ██╗ █████╗  █████╗     ██╗"
    echo "████╗  ██║██║████╗  ██║     ██║██╔══██╗██╔══██╗    ██║"
    echo "██╔██╗ ██║██║██╔██╗ ██║     ██║███████║███████║    ██║"
    echo "██║╚██╗██║██║██║╚██╗██║██   ██║██╔══██║██╔══██║    ╚═╝"
    echo "██║ ╚████║██║██║ ╚████║╚█████╔╝██║  ██║██║  ██║    ██╗"
    echo "╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝    ╚═╝"
    echo -e "${NC}"
    draw_separator
    echo -e "${YELLOW}        Version v3.0         |   Created by Root3301 (R.V)${NC}"
    draw_separator
}

function installation_menu() {
    while true; do
        clear
        draw_separator
        echo -e "${YELLOW}Menu Installation${NC}"
        draw_separator
        echo "1) Installer l'agent (lien prédéfini)"
        echo "2) Installer l'agent (lien personnalisé)"
        echo "3) Installer l'agent via script/token"
        echo "4) Retour"
        draw_separator
        read -rp "→ Votre choix : " install_choice

        case $install_choice in
            1)
                install_with_default_url
                ;;
            2)
                install_with_custom_url
                ;;
            3)
                selinux_apparmor_check
                detect_pkg_manager
                install_via_installer_script
                ;;
            4)
                return 0
                ;;
            *)
                display_message "$RED" "⚠️ Option invalide."
                ;;
        esac
        read -rp "Appuyez sur [Entrée] pour continuer..."
    done
}

function service_menu() {
    while true; do
        clear
        draw_separator
        echo -e "${YELLOW}Menu Service${NC}"
        draw_separator
        echo "1) Vérifier le statut du service"
        echo "2) Démarrer le service"
        echo "3) Arrêter le service"
        echo "4) Redémarrer le service"
        echo "5) Retour"
        draw_separator
        read -rp "→ Votre choix : " service_choice

        case $service_choice in
            1)
                check_service_status
                ;;
            2)
                start_service
                ;;
            3)
                stop_service
                ;;
            4)
                restart_service
                ;;
            5)
                return 0
                ;;
            *)
                display_message "$RED" "⚠️ Option invalide."
                ;;
        esac
        read -rp "Appuyez sur [Entrée] pour continuer..."
    done
}

function maintenance_menu() {
    while true; do
        clear
        draw_separator
        echo -e "${YELLOW}Menu Maintenance${NC}"
        draw_separator
        echo "1) Mettre à jour l'agent (Patch)"
        echo "2) Désinstaller l'agent"
        echo "3) Diagnostic de santé (Health Check)"
        echo "4) Retour"
        draw_separator
        read -rp "→ Votre choix : " maintenance_choice

        case $maintenance_choice in
            1)
                patch_agent
                ;;
            2)
                uninstall_agent
                ;;
            3)
                health_check
                ;;
            4)
                return 0
                ;;
            *)
                display_message "$RED" "⚠️ Option invalide."
                ;;
        esac
        read -rp "Appuyez sur [Entrée] pour continuer..."
    done
}

function logs_menu() {
    while true; do
        clear
        draw_separator
        echo -e "${YELLOW}Menu Logs & Diagnostics${NC}"
        draw_separator
        echo "1) Afficher les logs"
        echo "2) Diagnostic de santé (Health Check)"
        echo "3) Retour"
        draw_separator
        read -rp "→ Votre choix : " logs_choice

        case $logs_choice in
            1)
                show_logs
                ;;
            2)
                health_check
                ;;
            3)
                return 0
                ;;
            *)
                display_message "$RED" "⚠️ Option invalide."
                ;;
        esac
        read -rp "Appuyez sur [Entrée] pour continuer..."
    done
}

function handle_non_interactive_mode() {
    case "${1:-}" in
        --install-default)
            init_log
            check_dependencies || exit 1
            install_with_default_url
            exit $?
            ;;
        --install-with-token)
            init_log
            check_dependencies || exit 1
            selinux_apparmor_check
            detect_pkg_manager
            install_via_installer_script
            exit $?
            ;;
        --status)
            init_log
            check_service_status
            exit $?
            ;;
        --health-check)
            init_log
            check_dependencies || exit 1
            health_check
            exit $?
            ;;
        --help)
            echo "RMM Agent Manager v3.0"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-default    Installer l'agent avec l'URL prédéfinie"
            echo "  --install-with-token Installer l'agent via script/token"
            echo "  --status             Vérifier le statut du service"
            echo "  --health-check       Effectuer un diagnostic complet"
            echo "  --help               Afficher cette aide"
            echo ""
            echo "Sans option, le script démarre en mode interactif."
            exit 0
            ;;
        "")
            return 0
            ;;
        *)
            echo "Option inconnue : $1"
            echo "Utilisez --help pour voir les options disponibles."
            exit 1
            ;;
    esac
}

check_permissions
handle_non_interactive_mode "${1:-}"
init_log
check_dependencies || exit 1

while true; do
    show_header
    echo -e "${YELLOW}Menu principal${NC}"
    draw_separator
    echo "1) Installation"
    echo "2) Gestion du service"
    echo "3) Maintenance"
    echo "4) Logs & Diagnostics"
    echo "5) Quitter"
    draw_separator
    read -rp "→ Votre choix : " choice

    case $choice in
        1) installation_menu ;;
        2) service_menu ;;
        3) maintenance_menu ;;
        4) logs_menu ;;
        5)
            display_message "$GREEN" "Merci d'avoir utilisé ce script !"
            log_message "INFO" "Script terminé par l'utilisateur."
            exit 0
            ;;
        *)
            display_message "$RED" "⚠️ Option invalide."
            log_message "WARN" "Option invalide sélectionnée : $choice"
            ;;
    esac
    read -rp "Appuyez sur [Entrée] pour continuer..."
done
