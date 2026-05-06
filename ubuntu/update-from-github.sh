#!/bin/bash

echo "======================================"
echo " Wazuh Lab - Pull Latest GitHub Files"
echo "======================================"

REPO_DIR="/home/labadmin/Wazuh-Lab-Scripts"

if [ ! -d "$REPO_DIR" ]; then
    echo "[+] Repo not found. Cloning now..."
    cd /home/labadmin || exit
    git clone git@github.com:BESamples/Wazuh-Lab-Scripts.git
else
    echo "[+] Repo found. Pulling latest changes..."
    cd "$REPO_DIR" || exit
    git pull
fi

echo "[+] Done."
