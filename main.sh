#!/bin/bash

# =====================================
#      RMM Agent Manager v1.0
#      Created by Root3301 (R.V)
# =====================================

# Variables
DOWNLOAD_DIR="/tmp"                            # Répertoire temporaire pour le téléchargement
SERVICE_NAME="ninjarmm-agent.service"          # Nom du service pour vérifier son état
PREDEFINED_AGENT_URL="http://example.com/agent.rpm"  # Lien prédéfini pour l'installation de l'agent

# Couleurs pour le style
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m" # Pas de couleur

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
    display_message "$YELLOW" "Téléchargement et installation depuis le lien prédéfini"
    draw_separator

    FILENAME=$(basename "$PREDEFINED_AGENT_URL")

    # Télécharger et installer l'agent
    echo -e "Téléchargement de l'agent depuis ${GREEN}$PREDEFINED_AGENT_URL${NC} vers ${YELLOW}$DOWNLOAD_DIR${NC}..."
    curl -o "$DOWNLOAD_DIR/$FILENAME" "$PREDEFINED_AGENT_URL" --progress-bar

    if [ $? -eq 0 ]; then
        display_message "$GREEN" "Téléchargement réussi. Installation en cours..."
        sudo rpm -i "$DOWNLOAD_DIR/$FILENAME"
        if [ $? -eq 0 ]; then
            display_message "$GREEN" "L'installation de l'agent a été effectuée avec succès."
        else
            display_message "$RED" "⚠️ Erreur lors de l'installation de l'agent."
        fi
    else
        display_message "$RED" "⚠️ Échec du téléchargement. Vérifiez le lien prédéfini et réessayez."
    fi
}

# Fonction : Installer l'agent à partir d'une URL fournie par l'utilisateur
function install_with_custom_url() {
    clear
    draw_separator
    display_message "$YELLOW" "Téléchargement et installation depuis un lien personnalisé"
    draw_separator

    while true; do
        read -p "Veuillez entrer l'URL de l'agent que vous souhaitez télécharger : " CUSTOM_AGENT_URL
        if [[ -n $CUSTOM_AGENT_URL ]]; then
            break
        else
            display_message "$RED" "⚠️ L'URL ne peut pas être vide. Veuillez réessayer."
        fi
    done

    FILENAME=$(basename "$CUSTOM_AGENT_URL")

    # Télécharger et installer l'agent
    echo -e "Téléchargement de l'agent depuis ${GREEN}$CUSTOM_AGENT_URL${NC} vers ${YELLOW}$DOWNLOAD_DIR${NC}..."
    curl -o "$DOWNLOAD_DIR/$FILENAME" "$CUSTOM_AGENT_URL" --progress-bar

    if [ $? -eq 0 ]; then
        display_message "$GREEN" "Téléchargement réussi. Installation en cours..."
        sudo rpm -i "$DOWNLOAD_DIR/$FILENAME"
        if [ $? -eq 0 ]; then
            display_message "$GREEN" "L'installation de l'agent a été effectuée avec succès."
        else
            display_message "$RED" "⚠️ Erreur lors de l'installation de l'agent."
        fi
    else
        display_message "$RED" "⚠️ Échec du téléchargement. Vérifiez le lien entré et réessayez."
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
    else
        display_message "$RED" "❌ Le service $SERVICE_NAME n'est pas actif."
        echo -e "💡 Essayez de démarrer le service avec :${BLUE} sudo systemctl start $SERVICE_NAME${NC}"
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
    else
        display_message "$RED" "⚠️ Une erreur s'est produite lors de la désinstallation de l'agent."
    fi
}

# Affichage ASCII art pour le menu (v1.0 et credits ajoutés)
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
            exit 0 
            ;;
        *) 
            display_message "$RED" "⚠️ Option invalide. Veuillez sélectionner une option valide."
            ;;
    esac
    # Pause avant de retourner au menu principal
    read -p "Appuyez sur [Entrée] pour continuer..."
done


