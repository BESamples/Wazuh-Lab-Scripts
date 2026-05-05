#!/bin/bash

echo "======================================"
echo " Wazuh Config Editor"
echo "======================================"
echo "1) Edit Wazuh local_rules.xml"
echo "2) Edit ossec.conf"
echo "3) Edit GitHub local_rules.xml"
echo "4) Test rules"
echo "5) Restart wazuh-manager"
echo "6) Exit"
echo "======================================"

read -p "Choose an option: " choice

case $choice in
    1)
        sudo nano /var/ossec/etc/rules/local_rules.xml
        ;;
    2)
        sudo nano /var/ossec/etc/ossec.conf
        ;;
    3)
        nano /home/labadmin/Wazuh-Lab-Scripts/wazuh-rules/local_rules.xml
        ;;
    4)
        sudo /var/ossec/bin/wazuh-analysisd -t
        ;;
    5)
        sudo systemctl restart wazuh-manager
        ;;
    6)
        exit 0
        ;;
    *)
        echo "[!] Invalid option."
        ;;
esac
