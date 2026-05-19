#!/bin/bash

echo "======================================"
echo " Apply GitHub local_rules.xml to Wazuh"
echo "======================================"

REPO_RULES="/home/labadmin/Wazuh-Lab-Scripts/wazuh-rules/local_rules.xml"
WAZUH_RULES="/var/ossec/etc/rules/local_rules.xml"
BACKUP="/var/ossec/etc/rules/local_rules_backup_$(date +%F_%H%M%S).xml"

if [ ! -f "$REPO_RULES" ]; then
    echo "[!] Could not find:"
    echo "$REPO_RULES"
    exit 1
fi

echo "[+] Backing up current Wazuh local_rules.xml..."
sudo cp "$WAZUH_RULES" "$BACKUP"

echo "[+] Copying GitHub rules into Wazuh..."
sudo cp "$REPO_RULES" "$WAZUH_RULES"

echo "[+] Testing Wazuh rules..."
sudo /var/ossec/bin/wazuh-analysisd -t

if [ $? -eq 0 ]; then
    echo "[+] Rule test passed."
    echo "[+] Restarting Wazuh manager..."
    sudo systemctl restart wazuh-manager
    echo "[+] Done."
else
    echo "[!] Rule test failed."
    echo "[!] Restoring backup..."
    sudo cp "$BACKUP" "$WAZUH_RULES"
    sudo systemctl restart wazuh-manager
    echo "[!] Restored previous rules."
fi
