#!/bin/bash

# Variables
DOWNLOAD_DIR="/tmp"
LOG_DIR="/log"
LOG_FILE="$LOG_DIR/log.txt"  # Modifié pour écrire dans /log/log.txt
SERVICE_NAME="ninjarmm-agent.service"

# Créer le dossier de logs s'il n'existe pas
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Dossier $LOG_DIR créé." >> "$LOG_FILE"
fi

# Fonctions
function log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

function download_and_install() {
    # Demander à l'utilisateur d'entrer l'URL
    read -p "Veuillez entrer l'URL de l'agent à télécharger : " AGENT_URL
    FILENAME=$(basename "$AGENT_URL")
    
    # Télécharger l'agent
    log "Téléchargement de l'agent depuis $AGENT_URL vers $DOWNLOAD_DIR..."
    curl -o "$DOWNLOAD_DIR/$FILENAME" "$AGENT_URL" &>> "$LOG_FILE"

    # Vérifier si le téléchargement a réussi
    if [ $? -eq 0 ]; then
        log "Téléchargement réussi."
        log "Installation de l'agent..."
        sudo rpm -i "$DOWNLOAD_DIR/$FILENAME" &>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log "Agent installé avec succès."
        else
            log "Erreur lors de l'installation de l'agent."
        fi
    else
        log "Erreur lors du téléchargement. Veuillez vérifier l'URL et réessayer."
    fi
}

function check_service_status() {
    log "Vérification du statut du service $SERVICE_NAME..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Le service $SERVICE_NAME est actif et fonctionne correctement."
    else
        log "Le service $SERVICE_NAME n'est pas actif."
    fi
}

function uninstall_agent() {
    log "Désinstallation de l'agent..."
    sudo rpm -e "ninjarmm-agent" &>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        log "Agent désinstallé avec succès."
    else
        log "Erreur lors de la désinstallation de l'agent."
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
        4) log "Script terminé par l'utilisateur."; echo "Au revoir !"; exit 0 ;;
        *) log "Option invalide sélectionnée."; echo "Option invalide. Veuillez réessayer." ;;
    esac
done
