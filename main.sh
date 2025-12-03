#!/bin/bash

set -euo pipefail

# =====================================
#      RMM Agent Manager v2.0
#      Created by Root3301 (R.V)
# =====================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

DEFAULT_PREDEFINED_AGENT_URL="http://example.com/agent.rpm"
DEFAULT_SERVICE_NAME="ninjarmm-agent.service"
DEFAULT_LOG_FILE="/var/log/ninjarmm_agent_manager.log"
DEFAULT_DOWNLOAD_DIR="/tmp"
DEFAULT_AGENT_PACKAGE_NAME="ninjarmm-agent"
DEFAULT_AGENT_PACKAGE_TYPE="auto"
DEFAULT_LOG_LEVEL="INFO"

if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

PREDEFINED_AGENT_URL="${PREDEFINED_AGENT_URL:-$DEFAULT_PREDEFINED_AGENT_URL}"
SERVICE_NAME="${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}"
LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$DEFAULT_DOWNLOAD_DIR}"
AGENT_PACKAGE_NAME="${AGENT_PACKAGE_NAME:-$DEFAULT_AGENT_PACKAGE_NAME}"
AGENT_PACKAGE_TYPE="${AGENT_PACKAGE_TYPE:-$DEFAULT_AGENT_PACKAGE_TYPE}"
LOG_LEVEL="${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"

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
            echo "=== RMM Agent Manager Script v2.0 ==="
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
        display_message "$GREEN" "Téléchargement réussi. Installation en cours..."

        if install_package "$target_file"; then
            display_message "$GREEN" "✅ L'installation de l'agent a été effectuée avec succès."
            log_message "INFO" "Installation réussie depuis $PREDEFINED_AGENT_URL"
        else
            display_message "$RED" "⚠️ Erreur lors de l'installation de l'agent."
            log_message "ERROR" "Échec de l'installation depuis $target_file"
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
        display_message "$GREEN" "Téléchargement réussi. Installation en cours..."

        if install_package "$target_file"; then
            display_message "$GREEN" "✅ L'installation de l'agent a été effectuée avec succès."
            log_message "INFO" "Installation réussie depuis $custom_url"
        else
            display_message "$RED" "⚠️ Erreur lors de l'installation de l'agent."
            log_message "ERROR" "Échec de l'installation depuis $target_file"
        fi
    else
        display_message "$RED" "⚠️ Échec du téléchargement."
        log_message "ERROR" "Échec du téléchargement depuis $custom_url"
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
        display_message "$GREEN" "Téléchargement réussi. Installation de la mise à jour..."

        local pkg_type
        pkg_type=$(detect_package_type "$target_file")

        case "$pkg_type" in
            rpm)
                if rpm -U "$target_file"; then
                    display_message "$GREEN" "✅ Mise à jour effectuée avec succès."
                    log_message "INFO" "Patch réussi depuis $patch_url"
                else
                    display_message "$RED" "⚠️ Erreur lors de la mise à jour."
                    log_message "ERROR" "Échec du patch depuis $target_file"
                fi
                ;;
            deb)
                if install_package "$target_file"; then
                    display_message "$GREEN" "✅ Mise à jour effectuée avec succès."
                    log_message "INFO" "Patch réussi depuis $patch_url"
                else
                    display_message "$RED" "⚠️ Erreur lors de la mise à jour."
                    log_message "ERROR" "Échec du patch depuis $target_file"
                fi
                ;;
            *)
                display_message "$RED" "⚠️ Type de package non reconnu."
                log_message "ERROR" "Type de package inconnu pour le patch : $target_file"
                ;;
        esac
    else
        display_message "$RED" "⚠️ Échec du téléchargement de la mise à jour."
        log_message "ERROR" "Échec du téléchargement du patch depuis $patch_url"
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
    echo -e "${YELLOW}        Version v2.0         |   Created by Root3301 (R.V)${NC}"
    draw_separator
}

function handle_non_interactive_mode() {
    case "${1:-}" in
        --install-default)
            init_log
            check_dependencies || exit 1
            install_with_default_url
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
            echo "RMM Agent Manager v2.0"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-default    Installer l'agent avec l'URL prédéfinie"
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
    echo -e "${YELLOW}Que souhaitez-vous faire ?${NC}"
    echo "1) Installer l'agent (lien prédéfini)"
    echo "2) Installer l'agent (lien personnalisé)"
    echo "3) Vérifier le statut du service"
    echo "4) Mettre à jour l'agent (Patch)"
    echo "5) Désinstaller l'agent"
    echo "6) Afficher les logs"
    echo "7) Diagnostic de santé (Health Check)"
    echo "8) Quitter"
    draw_separator
    read -rp "→ Votre choix : " choice

    case $choice in
        1) install_with_default_url ;;
        2) install_with_custom_url ;;
        3) check_service_status ;;
        4) patch_agent ;;
        5) uninstall_agent ;;
        6) show_logs ;;
        7) health_check ;;
        8)
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
