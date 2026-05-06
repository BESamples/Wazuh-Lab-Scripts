#!/bin/bash

REPO_DIR="$HOME/Wazuh-Lab-Scripts"
GITHUB_RULES="$REPO_DIR/wazuh-rules/local_rules.xml"
AUTOENROLL_SNIPPET="$REPO_DIR/wazuh-configs/ossec-auth-autoenroll.xml"

ACTIVE_RULES="/var/ossec/etc/rules/local_rules.xml"
ACTIVE_OSSEC="/var/ossec/etc/ossec.conf"
BACKUP_DIR="$REPO_DIR/backups"

mkdir -p "$BACKUP_DIR"

pause() {
  echo
  read -p "Press Enter to continue..."
}

backup_file() {
  FILE="$1"
  NAME="$2"
  DATE=$(date +"%Y%m%d-%H%M%S")
  sudo cp "$FILE" "$BACKUP_DIR/${NAME}.backup-$DATE"
  echo "Backup saved to: $BACKUP_DIR/${NAME}.backup-$DATE"
}

while true; do
  clear
  echo "======================================"
  echo "        Wazuh Lab Manager Menu"
  echo "======================================"
  echo "1) Edit GitHub local_rules.xml"
  echo "2) Edit active Wazuh local_rules.xml"
  echo "3) Edit active ossec.conf"
  echo "4) Test Wazuh rules"
  echo "5) Restart wazuh-manager"
  echo "6) Backup active local_rules.xml"
  echo "7) Restore active local_rules.xml from latest backup"
  echo "8) Apply GitHub local_rules.xml to active Wazuh"
  echo "9) Apply auto-enroll config to ossec.conf"
  echo "10) Check wazuh-manager status"
  echo "11) Check agent list"
  echo "12) Git pull"
  echo "13) Git add / commit / push"
  echo "14) Test Windows agent connectivity"
  echo "15) Check Wazuh logs live"
  echo "16) Restore ossec.conf backup"
  echo "17) Enable/disable auto-enroll"
  echo "18) Show current Wazuh IP"
  echo "19) Open dashboard URL helper"
  echo "20) Update entire lab from GitHub"
  echo "0) Exit"
  echo "======================================"
  read -p "Choose an option: " choice

  case $choice in

    1)
      nano "$GITHUB_RULES"
      pause
      ;;

    2)
      backup_file "$ACTIVE_RULES" "local_rules.xml"
      sudo nano "$ACTIVE_RULES"
      pause
      ;;

    3)
      backup_file "$ACTIVE_OSSEC" "ossec.conf"
      sudo nano "$ACTIVE_OSSEC"
      pause
      ;;

    4)
      sudo /var/ossec/bin/wazuh-analysisd -t
      pause
      ;;

    5)
      echo "Testing rules before restart..."
      sudo /var/ossec/bin/wazuh-analysisd -t
      if [ $? -eq 0 ]; then
        echo "Rules passed. Restarting wazuh-manager..."
        sudo systemctl restart wazuh-manager
      else
        echo "Rules failed. Restart cancelled."
      fi
      pause
      ;;

    6)
      backup_file "$ACTIVE_RULES" "local_rules.xml"
      pause
      ;;

    7)
      LATEST=$(ls -t "$BACKUP_DIR"/local_rules.xml.backup-* 2>/dev/null | head -n 1)
      if [ -z "$LATEST" ]; then
        echo "No local_rules.xml backup found."
      else
        echo "Restoring: $LATEST"
        sudo cp "$LATEST" "$ACTIVE_RULES"
        sudo /var/ossec/bin/wazuh-analysisd -t
      fi
      pause
      ;;

    8)
      if [ ! -f "$GITHUB_RULES" ]; then
        echo "GitHub rules file not found: $GITHUB_RULES"
      else
        backup_file "$ACTIVE_RULES" "local_rules.xml"
        sudo cp "$GITHUB_RULES" "$ACTIVE_RULES"
        echo "Testing rules..."
        sudo /var/ossec/bin/wazuh-analysisd -t
        if [ $? -eq 0 ]; then
          read -p "Rules passed. Restart wazuh-manager now? (y/n): " restart
          if [ "$restart" = "y" ]; then
            sudo systemctl restart wazuh-manager
          fi
        else
          echo "Rules failed. Restore from backup if needed."
        fi
      fi
      pause
      ;;

        9)
      if [ ! -f "$AUTOENROLL_SNIPPET" ]; then
        echo "Auto-enroll snippet not found: $AUTOENROLL_SNIPPET"
      else
        backup_file "$ACTIVE_OSSEC" "ossec.conf"

        sudo sed -i '/<auth>/,/<\/auth>/d' "$ACTIVE_OSSEC"

        sudo awk -v snippet="$AUTOENROLL_SNIPPET" '
          /<\/ossec_config>/ && inserted==0 {
            while ((getline line < snippet) > 0) print line
            close(snippet)
            inserted=1
          }
          { print }
        ' "$ACTIVE_OSSEC" | sudo tee "$ACTIVE_OSSEC.tmp" >/dev/null

        sudo mv "$ACTIVE_OSSEC.tmp" "$ACTIVE_OSSEC"

        echo "Restarting wazuh-manager..."
        sudo systemctl restart wazuh-manager

        echo "Checking port 1515..."
        sudo ss -tulpn | grep 1515
      fi
      pause
      ;;

    10)
      sudo systemctl status wazuh-manager
      pause
      ;;

    11)
      sudo /var/ossec/bin/agent_control -l
      pause
      ;;

    12)
      cd "$REPO_DIR" || exit
      git pull
      pause
      ;;

    13)
      cd "$REPO_DIR" || exit
      git status
      read -p "Commit message: " msg
      git add .
      git commit -m "$msg"
      git push
      pause
      ;;

       14)
      read -p "Enter Windows Agent IP: " AGENTIP

      echo "Testing connectivity to agent..."
      ping -c 4 "$AGENTIP"

      echo
      echo "Checking Wazuh registration port 1514..."
      nc -zv "$AGENTIP" 1514

      pause
      ;;

    15)
      sudo tail -f /var/ossec/logs/ossec.log
      ;;

    16)
      LATEST=$(ls -t "$BACKUP_DIR"/ossec.conf.backup-* 2>/dev/null | head -n 1)

      if [ -z "$LATEST" ]; then
        echo "No ossec.conf backup found."
      else
        echo "Restoring: $LATEST"

        sudo cp "$LATEST" "$ACTIVE_OSSEC"

        echo "Testing config..."
        sudo /var/ossec/bin/wazuh-analysisd -t

        echo "Restarting wazuh-manager..."
        sudo systemctl restart wazuh-manager
      fi

      pause
      ;;

    17)
      echo "======================================"
      echo "1) Enable auto-enroll"
      echo "2) Disable auto-enroll"
      echo "======================================"

      read -p "Choose: " AUTO

      backup_file "$ACTIVE_OSSEC" "ossec.conf"

      if [ "$AUTO" = "1" ]; then
        sudo sed -i '/<auth>/,/<\/auth>/d' "$ACTIVE_OSSEC"
        sudo sed -i "/<\/ossec_config>/e cat $AUTOENROLL_SNIPPET" "$ACTIVE_OSSEC"

        echo "Auto-enroll ENABLED."

      elif [ "$AUTO" = "2" ]; then
        sudo sed -i '/<auth>/,/<\/auth>/d' "$ACTIVE_OSSEC"

        echo "Auto-enroll DISABLED."

      else
        echo "Invalid selection."
      fi

      sudo systemctl restart wazuh-manager

      pause
      ;;

    18)
      echo "Current Wazuh Manager IP:"
      hostname -I | awk '{print $1}'

      pause
      ;;

    19)
      IP=$(hostname -I | awk '{print $1}')

      echo
      echo "======================================"
      echo "        Wazuh Dashboard URL"
      echo "======================================"
      echo
      echo "https://$IP"
      echo
      echo "Default credentials:"
      echo "Username: admin"
      echo "Password: Check install output"
      echo
      echo "======================================"

      pause
      ;;

    20)
      echo "======================================"
      echo "     Updating Entire Wazuh Lab"
      echo "======================================"

      cd "$REPO_DIR" || exit

      echo "[+] Pulling latest GitHub updates..."
      git pull

      echo
      echo "[+] Reapplying GitHub local_rules.xml..."

      if [ -f "$GITHUB_RULES" ]; then
        backup_file "$ACTIVE_RULES" "local_rules.xml"

        sudo cp "$GITHUB_RULES" "$ACTIVE_RULES"

        sudo /var/ossec/bin/wazuh-analysisd -t

        if [ $? -eq 0 ]; then
          echo "[+] Rules passed."
          sudo systemctl restart wazuh-manager
        else
          echo "[!] Rules failed validation."
        fi
      fi

      echo
      echo "[+] Current wazuh-manager status:"
      sudo systemctl status wazuh-manager --no-pager

      pause
      ;;
     
    0)
      echo "Exiting."
      exit 0
      ;;

    *)
      echo "Invalid option. Choose 0-13."
      pause
      ;;
  esac
done
