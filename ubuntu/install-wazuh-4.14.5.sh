#!/bin/bash

echo "======================================"
echo " Wazuh 4.14.5 Install - Ubuntu 18.04"
echo "======================================"

cd /home/labadmin || exit

echo "[+] Updating Ubuntu packages..."
sudo apt update

echo "[+] Installing required tools..."
sudo apt install -y curl git gnupg apt-transport-https

echo "[+] Downloading Wazuh installer..."
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh

echo "[+] Running Wazuh all-in-one install..."
sudo bash ./wazuh-install.sh -a

echo "[+] Wazuh install complete."
echo "[+] Manager IP:"
hostname -I | awk '{print $1}'
