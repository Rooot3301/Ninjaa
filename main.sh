#!/bin/bash

# =====================================
#      RMM Agent Manager v1.0
#      Created by Root3301 (R.V)
# =====================================

# Variables
DOWNLOAD_DIR="/tmp"
SERVICE_NAME="ninjarmm-agent.service"
PREDEFINED_AGENT_URL="http://example.com/agent.rpm"
LOG_FILE="/var/log/ninjarmm_agent_manager.log"

# Couleurs pour le style
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Vérifier les permissions du script (exigent être root)
function check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}⚠️ Ce script doit être exécuté en tant qu'utilisateur root.${NC}"
        exit 1
    fi
}

# Initialiser le fichier log
function init_log() {
    echo "=== RMM Agent Manager Script ===" > "$LOG_FILE"
    echo "Démarré le : $(date)" >> "$LOG_FILE"
    echo "================================" >> "$LOG_FILE"
}

# Fonction : journaliser les messages dans un fichier log
function log_message() {
    local log_type="$1"
    local log_message="$2"
    echo "[${log_type}] $(date '+%Y-%m-%d %H:%M:%S') - $log_message" >> "$LOG_FILE"
}

# Fonctions utilitaires
function draw_separator() {
    echo -e "${BLUE}=========================================================${NC}"
}

function display_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Fonction : Installer l'agent avec lien prédéfini
function install_with_default_url() {
    clear
    draw_separator
    display_message "$YELLOW" "Installation depuis le lien prédéfini"
    draw_separator

    local FILENAME
    FILENAME=$(basename "$PREDEFINED_AGENT_URL")

    # Télécharger l'agent
    echo -e "Téléchargement de l'agent depuis ${GREEN}$PREDEFINED_AGENT_URL${NC} vers ${YELLOW}$DOWNLOAD_DIR${NC}..."
    curl -o "$DOWNLOAD_DIR/$FILENAME" "$PREDEFINED_AGENT_URL" --progress-bar

    if [ $? -eq 0 ]; then
        display_message "$GREEN" "Téléchargement réussi. Installation en cours..."
        log_message "INFO" "Téléchargement depuis le lien prédéfini : $PREDEFINED_AGENT_URL réussi."

        sudo rpm -i "$DOWNLOAD_DIR/$FILENAME"
        if [ $? -eq 0 ]; then
            display_message "$GREEN" "L'installation de l'agent a été effectuée avec succès."
            log_message "INFO" "Installation de l'agent depuis $PREDEFINED_AGENT_URL réussie."
        else
            display_message "$RED" "⚠️ Erreur lors de l'installation de l'agent."
            log_message "ERROR" "Échec de l'installation de l'agent depuis $DOWNLOAD_DIR/$FILENAME."
        fi
    else
        display_message "$RED" "⚠️ Échec du téléchargement. Vérifiez le lien prédéfini et réessayez."
        log_message "ERROR" "Échec du téléchargement depuis $PREDEFINED_AGENT_URL."
    fi
}

# Fonction : Installer l'agent à partir d'une URL fournie par l'utilisateur
function install_with_custom_url() {
    clear
    draw_separator
    display_message "$YELLOW" "Installation depuis un lien personnalisé"
    draw_separator

    local CUSTOM_AGENT_URL
    while true; do
        read -p "Veuillez entrer l'URL de l'agent que vous souhaitez télécharger : " CUSTOM_AGENT_URL
        if [[ -n $CUSTOM_AGENT_URL ]]; then
            break
        else
            display_message "$RED" "⚠️ L'URL ne peut pas être vide. Veuillez réessayer."
        fi
    done

    local FILENAME
    FILENAME=$(basename "$CUSTOM_AGENT_URL")

    # Télécharger l'agent
    echo -e "Téléchargement de l'agent depuis ${GREEN}$CUSTOM_AGENT_URL${NC} vers ${YELLOW}$DOWNLOAD_DIR${NC}..."
    curl -o "$DOWNLOAD_DIR/$FILENAME" "$CUSTOM_AGENT_URL" --progress-bar

    if [ $? -eq 0 ]; then
        display_message "$GREEN" "Téléchargement réussi. Installation en cours..."
        log_message "INFO" "Téléchargement depuis une URL : $CUSTOM_AGENT_URL réussi."

        sudo rpm -i "$DOWNLOAD_DIR/$FILENAME"
        if [ $? -eq 0 ]; then
            display_message "$GREEN" "L'installation de l'agent a été effectuée avec succès."
            log_message "INFO" "Installation depuis $CUSTOM_AGENT_URL réussie."
        else
            display_message "$RED" "⚠️ Erreur lors de l'installation de l'agent."
            log_message "ERROR" "Échec de l'installation depuis $DOWNLOAD_DIR/$FILENAME."
        fi
    else
        display_message "$RED" "⚠️ Échec du téléchargement. Vérifiez l'URL et réessayez."
        log_message "ERROR" "Échec du téléchargement depuis $CUSTOM_AGENT_URL."
    fi
}

# Fonction : Vérifier le statut du service
function check_service_status() {
    clear
    draw_separator
    display_message "$YELLOW" "Vérification du statut du service $SERVICE_NAME"
    draw_separator

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        display_message "$GREEN" "✅ Le service $SERVICE_NAME est actif et fonctionne correctement."
        log_message "INFO" "Le service $SERVICE_NAME est actif."
    else
        display_message "$RED" "❌ Le service $SERVICE_NAME n'est pas actif."
        echo -e "💡 Essayez de démarrer le service avec :${BLUE} sudo systemctl start $SERVICE_NAME${NC}"
        log_message "WARN" "Le service $SERVICE_NAME n'est pas actif."
    fi
}

# Fonction : Désinstaller l'agent
function uninstall_agent() {
    clear
    draw_separator
    display_message "$YELLOW" "Désinstallation de l'agent"
    draw_separator

    sudo rpm -e "ninjarmm-agent"
    if [ $? -eq 0 ]; then
        display_message "$GREEN" "✅ L'agent a été désinstallé avec succès."
        log_message "INFO" "Désinstallation de l'agent réussie."
    else
        display_message "$RED" "⚠️ Une erreur s'est produite lors de la désinstallation de l'agent."
        log_message "ERROR" "Échec de la désinstallation de l'agent."
    fi
}

# Affichage ASCII art pour le menu
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
    echo -e "${YELLOW}        Version v1.0         |   Created by Root3301 (R.V)${NC}"
    draw_separator
}

# Vérifier les permissions et initialiser le fichier log
check_permissions
init_log

# Menu principal
while true; do
    show_header
    echo -e "${YELLOW}Que souhaitez-vous faire ?${NC}"
    echo "1) Installer l'agent (lien prédéfini)"
    echo "2) Installer l'agent (lien personnalisé)"
    echo "3) Vérifier le statut du service"
    echo "4) Désinstaller l'agent"
    echo "5) Quitter"
    draw_separator
    read -p "→ Votre choix : " choice

    case $choice in
        1) install_with_default_url ;;
        2) install_with_custom_url ;;
        3) check_service_status ;;
        4) uninstall_agent ;;
        5)
            display_message "$GREEN" "Merci d'avoir utilisé ce script ! À bientôt."
            log_message "INFO" "Script terminé par l'utilisateur."
            exit 0
            ;;
        *) 
            display_message "$RED" "⚠️ Option invalide. Veuillez sélectionner une option valide."
            log_message "WARN" "Utilisateur a choisi une option invalide."
            ;;
    esac
    read -p "Appuyez sur [Entrée] pour continuer..."
done



