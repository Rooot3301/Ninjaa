# Crée par Romain 
#
# Le 13/11/2024
#


#!/bin/bash

# Variables
DOWNLOAD_DIR="/tmp"
AGENT_URL="https://example.com/path/to/ninjarmm-agent.rpm"  # Remplacez par l'URL réelle de l'agent
SERVICE_NAME="ninjarmm-agent.service"

# Fonctions
function download_and_install() {
    echo "Téléchargement de l'agent dans $DOWNLOAD_DIR..."
    FILENAME=$(basename "$AGENT_URL")
    curl -o "$DOWNLOAD_DIR/$FILENAME" "$AGENT_URL"

    # Vérifier si le téléchargement a réussi
    if [ $? -eq 0 ]; then
        echo "Téléchargement réussi."
        # Installer le fichier RPM avec sudo
        sudo rpm -i "$DOWNLOAD_DIR/$FILENAME" && echo "Agent installé avec succès."
    else
        echo "Erreur lors du téléchargement. Veuillez vérifier l'URL et réessayer."
    fi
}

function check_service_status() {
    echo "Vérification du statut du service $SERVICE_NAME..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "Le service $SERVICE_NAME est actif et fonctionne correctement."
    else
        echo "Le service $SERVICE_NAME n'est pas actif."
    fi
}

function uninstall_agent() {
    echo "Désinstallation de l'agent..."
    sudo rpm -e "ninjarmm-agent" && echo "Agent désinstallé avec succès."
}

# Affichage ASCII art pour le menu
clear
echo -e "\n\033[1;32m"  # Couleur verte pour le texte
echo "███╗   ██╗██╗███╗   ██╗     ██╗ █████╗  █████╗     ██╗"
echo "████╗  ██║██║████╗  ██║     ██║██╔══██╗██╔══██╗    ██║"
echo "██╔██╗ ██║██║██╔██╗ ██║     ██║███████║███████║    ██║"
echo "██║╚██╗██║██║██║╚██╗██║██   ██║██╔══██║██╔══██║    ╚═╝"
echo "██║ ╚████║██║██║ ╚████║╚█████╔╝██║  ██║██║  ██║    ██╗"
echo "╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝    ╚═╝"
echo -e "\033[0m\n"  # Réinitialiser la couleur

# Menu principal
while true; do
    echo "Sélectionnez une option :"
    echo "1) Installer l'agent"
    echo "2) Vérifier le statut du service"
    echo "3) Désinstaller l'agent"
    echo "4) Quitter"
    read -p "Votre choix : " choice

    case $choice in
        1) download_and_install ;;
        2) check_service_status ;;
        3) uninstall_agent ;;
        4) echo "Au revoir !"; exit 0 ;;
        *) echo "Option invalide. Veuillez réessayer." ;;
    esac
done
