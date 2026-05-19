#!/bin/bash

echo "======================================"
echo "   Wazuh Full Uninstall (Lab Reset)"
echo "======================================"

echo "[+] Stopping Wazuh services..."
sudo systemctl stop wazuh-manager 2>/dev/null
sudo systemctl stop wazuh-indexer 2>/dev/null
sudo systemctl stop wazuh-dashboard 2>/dev/null

echo "[+] Disabling services..."
sudo systemctl disable wazuh-manager 2>/dev/null
sudo systemctl disable wazuh-indexer 2>/dev/null
sudo systemctl disable wazuh-dashboard 2>/dev/null

echo "[+] Removing Wazuh packages..."
sudo apt remove --purge -y wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>/dev/null

echo "[+] Cleaning dependencies..."
sudo apt autoremove -y

echo "[+] Removing Wazuh directories..."
sudo rm -rf /var/ossec
sudo rm -rf /var/lib/wazuh*
sudo rm -rf /usr/share/wazuh*
sudo rm -rf /etc/wazuh*

echo "[+] Removing indexer data..."
sudo rm -rf /var/lib/opensearch

echo "[+] Removing dashboard data..."
sudo rm -rf /usr/share/opensearch-dashboards

echo "[+] Cleaning logs..."
sudo rm -rf /var/log/wazuh*

echo "[+] Removing installer files..."
rm -f ~/wazuh-install.sh

echo "[+] Resetting complete."

echo "======================================"
echo " Wazuh has been fully removed"
echo "======================================"
