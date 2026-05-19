#!/bin/bash

echo "======================================"
echo " Wazuh 4.14.5 Install - Ubuntu 18.04"
echo "======================================"

LAB_INFO_DIR="$HOME/Wazuh-Lab-Scripts/wazuh-configs"
LAB_INFO_FILE="$LAB_INFO_DIR/dashboard-admin.txt"
INSTALL_LOG="$HOME/Wazuh-Lab-Scripts/wazuh-install-output.log"

mkdir -p "$LAB_INFO_DIR"

# Ignore local-only credential/log files
grep -qxF "wazuh-configs/dashboard-admin.txt" .gitignore || \
echo "wazuh-configs/dashboard-admin.txt" >> .gitignore

grep -qxF "wazuh-install-output.log" .gitignore || \
echo "wazuh-install-output.log" >> .gitignore

cd /home/labadmin || exit

echo "[+] Updating Ubuntu packages..."
sudo apt update

echo "[+] Installing required tools..."
sudo apt install -y curl git gnupg apt-transport-https

echo "[+] Downloading Wazuh installer..."
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh

echo "[+] Running Wazuh all-in-one install..."
sudo bash ./wazuh-install.sh -a 2>&1 | tee "$INSTALL_LOG"

echo "Saving Wazuh dashboard login info..."

DASHBOARD_USER=$(grep -i "User:" "$INSTALL_LOG" | tail -n 1 | awk '{print $2}')
DASHBOARD_PASS=$(grep -i "Password:" "$INSTALL_LOG" | tail -n 1 | awk '{print $2}')
MANAGER_IP=$(hostname -I | awk '{print $1}')

cat > "$LAB_INFO_FILE" <<EOF
Dashboard URL: https://$MANAGER_IP
User: ${DASHBOARD_USER:-admin}
Password: $DASHBOARD_PASS
EOF

chmod 600 "$LAB_INFO_FILE"

echo "Dashboard info saved to:"
echo "$LAB_INFO_FILE"

echo "[+] Wazuh install complete."
echo "[+] Manager IP:"
hostname -I | awk '{print $1}'
