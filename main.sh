#!/bin/bash

# Variables
DOWNLOAD_DIR="/tmp"
SERVICE_NAME="ninjarmm-agent.service"

# Fonctions
function download_and_install() {
    # Demander à l'utilisateur d'entrer l'URL
    read -p "Veuillez entrer l'URL de l'agent à télécharger : " AGENT_URL
    FILENAME=$(basename "$AGENT_URL")
    
    # Télécharger l'agent
    echo "Téléchargement de l'agent depuis $AGENT_URL vers $DOWNLOAD_DIR..."
    curl -o "$DOWNLOAD_DIR/$FILENAME" "$AGENT_URL"

    # Vérifier si le téléchargement a réussi
    if [ $? -eq 0 ]; then
        echo "Téléchargement réussi."
        echo "Installation de l'agent..."
        sudo rpm -i "$DOWNLOAD_DIR/$FILENAME"
        if [ $? -eq 0 ]; then
            echo "Agent installé avec succès."
        else
            echo "Erreur lors de l'installation de l'agent."
        fi
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
    sudo rpm -e "ninjarmm-agent"
    if [ $? -eq 0 ]; then
        echo "Agent désinstallé avec succès."
    else
        echo "Erreur lors de la désinstallation de l'agent."
    fi
}

# Affichage ASCII art pour le menu
clear
echo -e "\n\033[1;32m"
echo "███╗   ██╗██╗███╗   ██╗     ██╗ █████╗  █████╗     ██╗"
echo "████╗  ██║██║████╗  ██║     ██║██╔══██╗██╔══██╗    ██║"
echo "██╔██╗ ██║██║██╔██╗ ██║     ██║███████║███████║    ██║"
echo "██║╚██╗██║██║██║╚██╗██║██   ██║██╔══██║██╔══██║    ╚═╝"
echo "██║ ╚████║██║██║ ╚████║╚█████╔╝██║  ██║██║  ██║    ██╗"
echo "╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝    ╚═╝"
echo -e "\033[0m\n"

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

