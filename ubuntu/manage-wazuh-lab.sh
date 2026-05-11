#!/bin/bash

REPO_DIR="$HOME/Wazuh-Lab-Scripts"
GITHUB_RULES="$REPO_DIR/wazuh-rules/local_rules.xml"
AUTOENROLL_SNIPPET="$REPO_DIR/wazuh-configs/ossec-auth-autoenroll.xml"

ACTIVE_RULES="/var/ossec/etc/rules/local_rules.xml"
ACTIVE_OSSEC="/var/ossec/etc/ossec.conf"
BACKUP_DIR="$REPO_DIR/backups"
LAB_INFO_DIR="$REPO_DIR/wazuh-configs"
LAB_INFO_FILE="$LAB_INFO_DIR/dashboard-admin.txt"
INSTALL_LOG="$REPO_DIR/wazuh-install-output.log"

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
      git pull origin main --rebase || { echo "[!] Pull failed"; pause; continue; }
      pause
      ;;

    8)
      cd "$REPO_DIR" || exit

      # Git identity check
      if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
        echo "[!] Git identity not configured."

        read -p "Enter your name for Git: " git_name
        read -p "Enter your email for Git: " git_email

        git config --global user.name "$git_name"
        git config --global user.email "$git_email"

        echo "[+] Git identity configured."
      fi

      git status

      read -p "Commit message: " msg
      if [ -z "$msg" ]; then
        echo "[!] Commit message cannot be empty."
        pause
        continue
      fi

      echo "[+] Staging changes..."
      git add .

      echo "[+] Committing..."
      git commit -m "$msg" || {
        echo "[!] Nothing to commit."
      }

      echo "[+] Syncing with GitHub..."
      git pull origin main --rebase || { echo "[!] Pull failed"; pause; continue; }

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

      if [ -f "$LAB_INFO_FILE" ]; then
        cat "$LAB_INFO_FILE"
      else
        echo "Dashboard credentials file not found."
      fi

      pause
      ;;

    11)
      echo "======================================"
      echo "   Deploying Latest Wazuh Rules"
      echo "======================================"

      cd "$REPO_DIR" || exit

      if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "[!] You have uncommitted changes."
        echo "[!] Please run Option 8 or discard changes."
        pause
        continue
      fi

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

  echo "[+] Ensuring required tools are installed..."
  sudo apt update
  sudo apt install -y curl

  cd "$REPO_DIR" || exit
  git pull origin main --rebase || { echo "[!] Git pull failed"; pause; continue; }

  mkdir -p "$BACKUP_DIR"
  mkdir -p "$LAB_INFO_DIR"

  INSTALL_RAN=false

  # -----------------------------
  # Install or Start Wazuh
  # -----------------------------
  if [ ! -d "/var/ossec" ]; then
    echo "[+] Wazuh not installed. Installing..."

    cd "$HOME" || exit

    curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
    sudo bash ./wazuh-install.sh -a 2>&1 | tee "$INSTALL_LOG" || {
      echo "[!] Wazuh install failed. Aborting bootstrap."
      pause
      continue
    }

    INSTALL_RAN=true

  elif ! systemctl is-active --quiet wazuh-manager; then
    echo "[+] Wazuh installed but not running. Starting..."
    sudo systemctl start wazuh-manager

  else
    echo "[+] Wazuh already installed and running."
  fi

  # -----------------------------
  # Capture Credentials ONLY if installed
  # -----------------------------
  if [ "$INSTALL_RAN" = true ]; then
    echo "[+] Capturing dashboard credentials..."

    DASHBOARD_USER=$(grep -i "User:" "$INSTALL_LOG" | tail -n 1 | awk '{print $2}')
    DASHBOARD_PASS=$(grep -i "Password:" "$INSTALL_LOG" | tail -n 1 | awk '{print $2}')
    MANAGER_IP=$(hostname -I | awk '{print $1}')

    if [ -z "$DASHBOARD_PASS" ]; then
      echo "[!] WARNING: Password not detected."
      DASHBOARD_PASS="NOT FOUND - CHECK LOG"
    fi

    cat > "$LAB_INFO_FILE" <<EOF
Dashboard URL: https://$MANAGER_IP
User: ${DASHBOARD_USER:-admin}
Password: $DASHBOARD_PASS
EOF

    chmod 600 "$LAB_INFO_FILE"

    echo "[+] Dashboard credentials saved:"
    cat "$LAB_INFO_FILE"
  fi

  cd "$REPO_DIR" || exit

  # -----------------------------
  # Apply Rules
  # -----------------------------
  if [ -f "$GITHUB_RULES" ]; then
    backup_file "$ACTIVE_RULES" "local_rules.xml"
    sudo cp "$GITHUB_RULES" "$ACTIVE_RULES"
  fi

  # -----------------------------
  # Apply Config
  # -----------------------------
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

  # -----------------------------
  # Validate + Restart
  # -----------------------------
  echo "[+] Validating configuration..."
  sudo /var/ossec/bin/wazuh-analysisd -t

  if [ $? -eq 0 ]; then
    sudo systemctl restart wazuh-manager
  else
    echo "[!] Config validation failed."
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

  if [ -f "$LAB_INFO_FILE" ]; then
    echo
    echo "Dashboard Credentials:"
    cat "$LAB_INFO_FILE"
  fi

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
