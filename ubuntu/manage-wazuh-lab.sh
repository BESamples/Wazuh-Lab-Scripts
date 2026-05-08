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
  echo "2) Edit active ossec.conf"
  echo "3) Test Wazuh rules"
  echo "4) Restart wazuh-manager (safe)"
  echo "5) Check wazuh-manager status"
  echo "6) Check agent list"
  echo "7) Git pull (safe)"
  echo "8) Git add / commit / push (safe)"
  echo "9) Check Wazuh logs live"
  echo "10) Show Wazuh dashboard info"
  echo "11) Deploy latest rules (Git → Apply → Restart)"
  echo "12) Fresh Lab Bootstrap ⭐"
  echo "0) Exit"
  echo "======================================"
  read -p "Choose an option: " choice

  case $choice in

    1)
      nano "$GITHUB_RULES"
      pause
      ;;

    2)
      backup_file "$ACTIVE_OSSEC" "ossec.conf"
      sudo nano "$ACTIVE_OSSEC"
      pause
      ;;

    3)
      sudo /var/ossec/bin/wazuh-analysisd -t
      pause
      ;;

    4)
      echo "[+] Testing rules before restart..."
      sudo /var/ossec/bin/wazuh-analysisd -t
      if [ $? -eq 0 ]; then
        echo "[+] Restarting wazuh-manager..."
        sudo systemctl restart wazuh-manager
      else
        echo "[!] Rules failed. Restart cancelled."
      fi
      pause
      ;;

    5)
      sudo systemctl status wazuh-manager
      pause
      ;;

    6)
      sudo /var/ossec/bin/agent_control -l
      pause
      ;;

    7)
      cd "$REPO_DIR" || exit
      git pull origin main --rebase
      pause
      ;;

    8)
      cd "$REPO_DIR" || exit

      echo "[+] Syncing with GitHub..."
      git pull origin main --rebase || { echo "[!] Pull failed"; pause; continue; }

      git status

      read -p "Commit message: " msg

      git add .
      git commit -m "$msg"

      echo "[+] Pushing to GitHub..."
      git push

      pause
      ;;

    9)
      sudo tail -f /var/ossec/logs/ossec.log
      ;;

    10)
      IP=$(hostname -I | awk '{print $1}')

      echo "======================================"
      echo "   Wazuh Dashboard Info"
      echo "======================================"
      echo "Dashboard URL: https://$IP"
      echo "Username: admin"

      if [ -f "$REPO_DIR/wazuh-configs/dashboard-admin.txt" ]; then
        echo -n "Password: "
        cat "$REPO_DIR/wazuh-configs/dashboard-admin.txt"
      else
        echo "Password file not found."
      fi

      pause
      ;;

    11)
      echo "======================================"
      echo "   Deploying Latest Wazuh Rules"
      echo "======================================"

      cd "$REPO_DIR" || exit

      git pull origin main --rebase || { echo "[!] Git pull failed"; pause; continue; }

      if [ ! -f "$GITHUB_RULES" ]; then
        echo "[!] Rules file not found."
        pause
        continue
      fi

      backup_file "$ACTIVE_RULES" "local_rules.xml"

      sudo cp "$GITHUB_RULES" "$ACTIVE_RULES"

      echo "[+] Testing rules..."
      sudo /var/ossec/bin/wazuh-analysisd -t

      if [ $? -eq 0 ]; then
        echo "[+] Restarting wazuh-manager..."
        sudo systemctl restart wazuh-manager
      else
        echo "[!] Rules failed validation."
      fi

      pause
      ;;

    12)
      echo "======================================"
      echo "     Fresh Lab Bootstrap Starting"
      echo "======================================"

      cd "$REPO_DIR" || exit

      git pull origin main --rebase || { echo "[!] Git pull failed"; pause; continue; }

      mkdir -p "$BACKUP_DIR"

      if [ -f "$GITHUB_RULES" ]; then
        backup_file "$ACTIVE_RULES" "local_rules.xml"
        sudo cp "$GITHUB_RULES" "$ACTIVE_RULES"
      fi

      if [ -f "$AUTOENROLL_SNIPPET" ]; then
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
      fi

      echo "[+] Validating configuration..."
      sudo /var/ossec/bin/wazuh-analysisd -t

      if [ $? -eq 0 ]; then
        sudo systemctl restart wazuh-manager
      else
        echo "[!] Config failed validation."
        pause
        continue
      fi

      echo "[+] wazuh-manager status:"
      sudo systemctl status wazuh-manager --no-pager

      echo "[+] Agent list:"
      sudo /var/ossec/bin/agent_control -l

      echo "======================================"
      echo "     Bootstrap Complete"
      echo "======================================"

      pause
      ;;

    0)
      echo "Exiting."
      exit 0
      ;;

    *)
      echo "Invalid option. Choose 0-12."
      pause
      ;;
  esac
done
