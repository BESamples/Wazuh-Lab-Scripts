#!/bin/bash

# ======================================
# Wazuh Lab Manager
# Workflow order:
# 1 = Bootstrap first
# 2 = Uninstall/reset
# 3-5 = Daily rule workflow
# 6-11 = Monitoring / validation
# 12-13 = Utilities
# ======================================

# ------------------------------
# CONFIG
# ------------------------------
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
mkdir -p "$LAB_INFO_DIR"

# ------------------------------
# HELPERS
# ------------------------------
pause() {
  echo
  read -p "Press Enter to continue..."
}

backup_file() {
  local FILE="$1"
  local NAME="$2"
  local DATE
  DATE=$(date +"%Y%m%d-%H%M%S")

  if [ -f "$FILE" ]; then
    sudo cp "$FILE" "$BACKUP_DIR/${NAME}.backup-$DATE"
    echo "[+] Backup saved to: $BACKUP_DIR/${NAME}.backup-$DATE"
  else
    echo "[!] File not found for backup: $FILE"
  fi
}

ensure_git_identity() {
  if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
    echo "[!] Git identity not configured."

    read -p "Enter your name for Git: " git_name
    read -p "Enter your email for Git: " git_email

    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
      echo "[!] Name and email are both required."
      return 1
    fi

    git config --global user.name "$git_name"
    git config --global user.email "$git_email"

    echo "[+] Git identity configured."
  fi

  return 0
}

safe_git_pull() {
  cd "$REPO_DIR" || return 1
  git pull origin main --rebase
}

validate_wazuh_config() {
  sudo /var/ossec/bin/wazuh-analysisd -t
}

show_dashboard_info() {
  local IP
  IP=$(hostname -I | awk '{print $1}')

  echo "======================================"
  echo "   Wazuh Dashboard Info"
  echo "======================================"
  echo "Dashboard URL: https://$IP"

  if [ -f "$LAB_INFO_FILE" ]; then
    echo
    cat "$LAB_INFO_FILE"
  else
    echo "Dashboard credentials file not found."
  fi
}

# ------------------------------
# MENU LOOP
# ------------------------------
while true; do
  clear

  echo "======================================"
  echo "        Wazuh Lab Manager"
  echo "======================================"

  echo "🚀 START / RESET"
  echo "1) Fresh Lab Bootstrap (RUN FIRST)"
  echo "2) Full Wazuh Uninstall (DANGEROUS)"

  echo
  echo "⚙️ DAILY WORKFLOW"
  echo "3) Edit GitHub local_rules.xml"
  echo "4) Git add / commit / push"
  echo "5) Deploy latest rules to Wazuh"

  echo
  echo "🔍 MONITORING / VALIDATION"
  echo "6) Test Wazuh rules"
  echo "7) Restart wazuh-manager (safe)"
  echo "8) Check wazuh-manager status"
  echo "9) Check agent list"
  echo "10) Check Wazuh logs live"
  echo "11) Show Wazuh dashboard info"

  echo
  echo "🧰 UTILITIES"
  echo "12) Edit active ossec.conf"
  echo "13) Git pull (manual sync)"

  echo
  echo "0) Exit"
  echo "======================================"

  read -p "Choose option: " choice

  case $choice in

    # ======================================
    # 1) BOOTSTRAP
    # ======================================
    1)
      echo "======================================"
      echo "     Fresh Lab Bootstrap Starting"
      echo "======================================"

      echo "[+] Ensuring required tools are installed..."
      sudo apt update
      sudo apt install -y curl git

      cd "$REPO_DIR" || exit

      echo "[+] Pulling latest GitHub repo..."
      safe_git_pull || {
        echo "[!] Git pull failed."
        pause
        continue
      }

      mkdir -p "$BACKUP_DIR"
      mkdir -p "$LAB_INFO_DIR"

      INSTALL_RAN=false

      # -----------------------------
      # Install or start Wazuh
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
      # Capture credentials only if install ran
      # -----------------------------
      if [ "$INSTALL_RAN" = true ]; then
        echo "[+] Capturing dashboard credentials..."

        DASHBOARD_USER=$(grep -i "User:" "$INSTALL_LOG" | tail -n 1 | awk '{print $2}')
        DASHBOARD_PASS=$(grep -i "Password:" "$INSTALL_LOG" | tail -n 1 | awk '{print $2}')
        MANAGER_IP=$(hostname -I | awk '{print $1}')

        if [ -z "$DASHBOARD_PASS" ]; then
          echo "[!] WARNING: Password not detected in install log."
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
      # Apply GitHub rules
      # -----------------------------
      if [ -f "$GITHUB_RULES" ]; then
        echo "[+] Applying GitHub local_rules.xml..."
        backup_file "$ACTIVE_RULES" "local_rules.xml"
        sudo cp "$GITHUB_RULES" "$ACTIVE_RULES"
      else
        echo "[!] GitHub rules file not found: $GITHUB_RULES"
      fi

      # -----------------------------
      # Apply auto-enroll snippet if present
      # -----------------------------
      if [ -f "$AUTOENROLL_SNIPPET" ]; then
        echo "[+] Applying auto-enroll config..."
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
      else
        echo "[!] Auto-enroll config not found. Skipping."
      fi

      # -----------------------------
      # Validate + restart
      # -----------------------------
      echo "[+] Validating Wazuh configuration..."
      validate_wazuh_config

      if [ $? -eq 0 ]; then
        echo "[+] Restarting wazuh-manager..."
        sudo systemctl restart wazuh-manager
      else
        echo "[!] Config validation failed."
        pause
        continue
      fi

      echo
      echo "[+] wazuh-manager status:"
      sudo systemctl status wazuh-manager --no-pager

      echo
      echo "[+] Agent list:"
      sudo /var/ossec/bin/agent_control -l

      echo
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

    # ======================================
    # 2) FULL UNINSTALL
    # ======================================
    2)
      echo "======================================"
      echo "   FULL WAZUH UNINSTALL (DANGEROUS)"
      echo "======================================"
      echo "[!] This will completely remove Wazuh."
      echo "[!] All data, rules, and configs will be lost."
      echo

      read -p "Type YES to continue: " confirm

      if [ "$confirm" != "YES" ]; then
        echo "[+] Uninstall cancelled."
        pause
        continue
      fi

     echo "[+] Stopping services..."
sudo systemctl stop wazuh-manager 2>/dev/null
sudo systemctl stop wazuh-indexer 2>/dev/null
sudo systemctl stop wazuh-dashboard 2>/dev/null
sudo systemctl stop filebeat 2>/dev/null

echo "[+] Disabling services..."
sudo systemctl disable wazuh-manager 2>/dev/null
sudo systemctl disable wazuh-indexer 2>/dev/null
sudo systemctl disable wazuh-dashboard 2>/dev/null
sudo systemctl disable filebeat 2>/dev/null

echo "[+] Removing packages..."
sudo apt remove --purge -y wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>/dev/null
sudo apt autoremove -y

echo "[+] Removing directories..."
sudo rm -rf /var/ossec
sudo rm -rf /var/lib/wazuh*
sudo rm -rf /usr/share/wazuh*
sudo rm -rf /etc/wazuh*
sudo rm -rf /var/lib/opensearch
sudo rm -rf /usr/share/opensearch-dashboards
sudo rm -rf /etc/filebeat
sudo rm -rf /var/lib/filebeat
sudo rm -rf /var/log/filebeat

      echo "[+] Cleaning logs..."
      sudo rm -rf /var/log/wazuh*

      echo
      echo "======================================"
      echo "   Wazuh fully removed"
      echo "======================================"

      pause
      ;;

    # ======================================
    # 3) EDIT RULES
    # ======================================
    3)
      nano "$GITHUB_RULES"
      pause
      ;;

    # ======================================
    # 4) GIT ADD / COMMIT / PUSH
    # ======================================
    4)
      cd "$REPO_DIR" || exit

      ensure_git_identity || {
        pause
        continue
      }

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
      safe_git_pull || {
        echo "[!] Pull failed."
        pause
        continue
      }

      echo "[+] Pushing to GitHub..."
      git push

      pause
      ;;

    # ======================================
    # 5) DEPLOY RULES
    # ======================================
    5)
      echo "======================================"
      echo "   Deploying Latest Wazuh Rules"
      echo "======================================"

      cd "$REPO_DIR" || exit

      if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "[!] You have uncommitted changes."
        echo "[!] Please run Option 4 or discard changes."
        pause
        continue
      fi

      safe_git_pull || {
        echo "[!] Git pull failed."
        pause
        continue
      }

      if [ ! -f "$GITHUB_RULES" ]; then
        echo "[!] Rules file not found."
        pause
        continue
      fi

      backup_file "$ACTIVE_RULES" "local_rules.xml"
      sudo cp "$GITHUB_RULES" "$ACTIVE_RULES"

      echo "[+] Testing rules..."
      validate_wazuh_config

      if [ $? -eq 0 ]; then
        echo "[+] Restarting wazuh-manager..."
        sudo systemctl restart wazuh-manager
      else
        echo "[!] Rules failed validation."
      fi

      pause
      ;;

    # ======================================
    # 6) TEST RULES
    # ======================================
    6)
      validate_wazuh_config
      pause
      ;;

    # ======================================
    # 7) RESTART WAZUH
    # ======================================
    7)
      echo "[+] Testing rules before restart..."
      validate_wazuh_config

      if [ $? -eq 0 ]; then
        echo "[+] Restarting wazuh-manager..."
        sudo systemctl restart wazuh-manager
      else
        echo "[!] Rules failed. Restart cancelled."
      fi

      pause
      ;;

    # ======================================
    # 8) SERVICE STATUS
    # ======================================
    8)
      sudo systemctl status wazuh-manager
      pause
      ;;

    # ======================================
    # 9) AGENT LIST
    # ======================================
    9)
      sudo /var/ossec/bin/agent_control -l
      pause
      ;;

    # ======================================
    # 10) LIVE LOGS
    # ======================================
    10)
      sudo tail -f /var/ossec/logs/ossec.log
      ;;

    # ======================================
    # 11) DASHBOARD INFO
    # ======================================
    11)
      show_dashboard_info
      pause
      ;;

    # ======================================
    # 12) EDIT ACTIVE OSSEC.CONF
    # ======================================
    12)
      backup_file "$ACTIVE_OSSEC" "ossec.conf"
      sudo nano "$ACTIVE_OSSEC"
      pause
      ;;

    # ======================================
    # 13) MANUAL GIT PULL
    # ======================================
    13)
      cd "$REPO_DIR" || exit
      safe_git_pull || echo "[!] Pull failed."
      pause
      ;;

    # ======================================
    # 0) EXIT
    # ======================================
    0)
      echo "Exiting."
      exit 0
      ;;

    # ======================================
    # INVALID
    # ======================================
    *)
      echo "Invalid option. Choose 0-13."
      pause
      ;;
  esac
done
