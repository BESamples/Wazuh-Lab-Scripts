#!/usr/bin/env bash

# ============================================================
# Wazuh Lab Manager - Stable No-YARA Version
# Purpose:
#   - Fresh Wazuh Manager bootstrap after VM reset
#   - Deploy GitHub local_rules.xml
#   - Apply auto-enroll snippet
#   - Validate before restart
#
# YARA is intentionally NOT applied in this version.
# Add YARA only after Wazuh Manager + agents are confirmed working.
# ============================================================

set -o pipefail

# ------------------------------
# USER / PATH DETECTION
# ------------------------------
REAL_USER="${SUDO_USER:-$(id -un)}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6 2>/dev/null)"
[ -z "$REAL_HOME" ] && REAL_HOME="$HOME"

REPO_DIR="${REPO_DIR:-$REAL_HOME/Wazuh-Lab-Scripts}"
GITHUB_RULES="$REPO_DIR/wazuh-rules/local_rules.xml"
AUTOENROLL_SNIPPET="$REPO_DIR/wazuh-configs/ossec-auth-autoenroll.xml"

ACTIVE_RULES="/var/ossec/etc/rules/local_rules.xml"
ACTIVE_OSSEC="/var/ossec/etc/ossec.conf"

BACKUP_DIR="$REPO_DIR/backups"
LAB_INFO_DIR="$REPO_DIR/wazuh-configs"
LAB_INFO_FILE="$LAB_INFO_DIR/dashboard-admin.txt"
INSTALL_LOG="$REPO_DIR/wazuh-install-output.log"

WAZUH_VERSION="4.14"

# ------------------------------
# HELPERS
# ------------------------------
run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

run_as_user() {
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$REAL_USER" != "root" ]; then
    sudo -u "$REAL_USER" -H "$@"
  else
    "$@"
  fi
}

pause() {
  echo
  read -r -p "Press Enter to continue..."
}

header() {
  clear
  echo "======================================"
  echo "   Wazuh Lab Manager - Stable No-YARA"
  echo "======================================"
}

info() { echo "[+] $*"; }
warn() { echo "[!] $*"; }
fail() { echo "[x] $*"; }

ensure_dirs() {
  run_as_user mkdir -p "$BACKUP_DIR" "$LAB_INFO_DIR"
}

backup_file() {
  local file="$1"
  local name="$2"
  local date backup

  date="$(date +"%Y%m%d-%H%M%S")"
  backup="$BACKUP_DIR/${name}.backup-$date"

  ensure_dirs

  if [ -f "$file" ]; then
    run_root cp "$file" "$backup"
    run_root chown "$REAL_USER:$REAL_USER" "$backup" 2>/dev/null || true
    info "Backup saved to: $backup"
  else
    warn "File not found for backup: $file"
  fi
}

safe_git_pull() {
  if [ ! -d "$REPO_DIR/.git" ]; then
    warn "Not a Git repo: $REPO_DIR"
    warn "Skipping Git pull."
    return 0
  fi

  cd "$REPO_DIR" || return 1
  run_as_user git pull origin main --rebase
}

ensure_git_identity() {
  if ! run_as_user git config --global user.name >/dev/null 2>&1 || \
     ! run_as_user git config --global user.email >/dev/null 2>&1; then
    warn "Git identity not configured."

    read -r -p "Enter your name for Git: " git_name
    read -r -p "Enter your email for Git: " git_email

    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
      warn "Name and email are both required."
      return 1
    fi

    run_as_user git config --global user.name "$git_name"
    run_as_user git config --global user.email "$git_email"
    info "Git identity configured."
  fi

  return 0
}

wazuh_base_files_exist() {
  [ -d "/var/ossec" ] && \
  [ -f "$ACTIVE_OSSEC" ] && \
  [ -x "/var/ossec/bin/wazuh-analysisd" ]
}

wait_for_wazuh_base_files() {
  local timeout="${1:-90}"
  local count=0

  info "Checking for Wazuh manager files..."

  while [ "$count" -lt "$timeout" ]; do
    if wazuh_base_files_exist; then
      info "Wazuh manager files found."
      return 0
    fi
    sleep 3
    count=$((count + 3))
    echo "[+] Waiting for /var/ossec and ossec.conf... ${count}s/${timeout}s"
  done

  fail "Wazuh manager files were not found after waiting."
  echo
  echo "Debug checks:"
  run_root ls -ld /var/ossec 2>/dev/null || true
  run_root ls -l /var/ossec/etc/ossec.conf 2>/dev/null || true
  run_root ls -l /var/ossec/bin/wazuh-analysisd 2>/dev/null || true
  echo
  echo "Installed Wazuh packages:"
  dpkg -l | grep -E 'wazuh|filebeat|opensearch' || true
  echo
  echo "Recent installer errors:"
  grep -iE "error|failed|cannot|manager|ossec|dpkg|apt" "$INSTALL_LOG" 2>/dev/null | tail -80 || true
  return 1
}

validate_wazuh_config() {
  if [ ! -x "/var/ossec/bin/wazuh-analysisd" ]; then
    fail "Cannot validate. /var/ossec/bin/wazuh-analysisd not found."
    return 1
  fi

  run_root /var/ossec/bin/wazuh-analysisd -t
}

restart_wazuh_if_valid() {
  info "Validating Wazuh configuration..."
  if validate_wazuh_config; then
    info "Validation passed. Restarting wazuh-manager..."
    run_root systemctl restart wazuh-manager
  else
    fail "Config validation failed. Restart cancelled."
    return 1
  fi
}

capture_dashboard_credentials() {
  local dashboard_user dashboard_pass manager_ip

  if [ ! -f "$INSTALL_LOG" ]; then
    warn "Install log not found. Cannot capture dashboard password."
    return 0
  fi

  dashboard_user="$(grep -i "User:" "$INSTALL_LOG" | tail -n 1 | awk '{print $2}')"
  dashboard_pass="$(grep -i "Password:" "$INSTALL_LOG" | tail -n 1 | awk '{print $2}')"
  manager_ip="$(hostname -I | awk '{print $1}')"

  if [ -z "$dashboard_pass" ]; then
    dashboard_pass="NOT FOUND - CHECK $INSTALL_LOG"
  fi

  ensure_dirs

  cat > "$LAB_INFO_FILE" <<EOF_INFO
Dashboard URL: https://$manager_ip
User: ${dashboard_user:-admin}
Password: $dashboard_pass
EOF_INFO

  chmod 600 "$LAB_INFO_FILE"
  run_root chown "$REAL_USER:$REAL_USER" "$LAB_INFO_FILE" 2>/dev/null || true

  info "Dashboard credentials saved to: $LAB_INFO_FILE"
  cat "$LAB_INFO_FILE"
}

show_dashboard_info() {
  local ip
  ip="$(hostname -I | awk '{print $1}')"

  echo "======================================"
  echo "   Wazuh Dashboard Info"
  echo "======================================"
  echo "Dashboard URL: https://$ip"

  if [ -f "$LAB_INFO_FILE" ]; then
    echo
    cat "$LAB_INFO_FILE"
  else
    echo
    warn "Dashboard credentials file not found: $LAB_INFO_FILE"
    warn "Check installer output or $INSTALL_LOG"
  fi
}

show_services_status() {
  echo "======================================"
  echo "   Wazuh Service Status"
  echo "======================================"
  run_root systemctl status wazuh-manager --no-pager 2>/dev/null || true
  echo
  run_root systemctl status wazuh-indexer --no-pager 2>/dev/null || true
  echo
  run_root systemctl status wazuh-dashboard --no-pager 2>/dev/null || true
  echo
  run_root systemctl status filebeat --no-pager 2>/dev/null || true
}

install_required_tools() {
  info "Ensuring required tools are installed..."
  run_root apt update
  run_root apt install -y curl git nano
}

install_wazuh_stack() {
  local install_mode install_exit installer

  installer="$REAL_HOME/wazuh-install.sh"

  info "Downloading Wazuh installer..."
  run_as_user bash -c "cd '$REAL_HOME' && curl -sO https://packages.wazuh.com/${WAZUH_VERSION}/wazuh-install.sh"

  echo
  echo "Choose Wazuh install mode:"
  echo "1) Normal install - use this on a fresh VM reset"
  echo "2) Overwrite existing Wazuh install (-o) - erases existing Wazuh config/data"
  echo
  read -r -p "Choose install mode: " install_mode

  if [ "$install_mode" = "2" ]; then
    warn "Running Wazuh installer with overwrite option..."
    run_root bash "$installer" -a -o 2>&1 | tee "$INSTALL_LOG"
  else
    info "Running normal Wazuh installer..."
    run_root bash "$installer" -a 2>&1 | tee "$INSTALL_LOG"
  fi

  install_exit=${PIPESTATUS[0]}

  run_root chown "$REAL_USER:$REAL_USER" "$INSTALL_LOG" 2>/dev/null || true

  if [ "$install_exit" -ne 0 ]; then
    fail "Wazuh installer returned a failure code."
    return 1
  fi

  wait_for_wazuh_base_files 90
}

apply_github_rules() {
  if [ ! -f "$GITHUB_RULES" ]; then
    warn "GitHub rules file not found: $GITHUB_RULES"
    return 0
  fi

  if [ ! -f "$ACTIVE_OSSEC" ]; then
    fail "Wazuh ossec.conf missing. Cannot deploy rules."
    return 1
  fi

  run_root mkdir -p /var/ossec/etc/rules

  info "Applying GitHub local_rules.xml..."
  backup_file "$ACTIVE_RULES" "local_rules.xml"
  run_root cp "$GITHUB_RULES" "$ACTIVE_RULES"
}

apply_auto_enroll() {
  local tmp

  if [ ! -f "$AUTOENROLL_SNIPPET" ]; then
    warn "Auto-enroll config not found. Skipping: $AUTOENROLL_SNIPPET"
    return 0
  fi

  if [ ! -f "$ACTIVE_OSSEC" ]; then
    fail "Active ossec.conf not found: $ACTIVE_OSSEC"
    return 1
  fi

  if ! run_root grep -q "</ossec_config>" "$ACTIVE_OSSEC"; then
    fail "Cannot find closing </ossec_config> in $ACTIVE_OSSEC"
    return 1
  fi

  info "Applying auto-enroll config..."
  backup_file "$ACTIVE_OSSEC" "ossec.conf"

  tmp="$(mktemp)"

  run_root sed '/<auth>/,/<\/auth>/d' "$ACTIVE_OSSEC" | awk -v snippet="$AUTOENROLL_SNIPPET" '
    /<\/ossec_config>/ && inserted==0 {
      while ((getline line < snippet) > 0) print line
      close(snippet)
      inserted=1
    }
    { print }
  ' > "$tmp"

  run_root cp "$tmp" "$ACTIVE_OSSEC"
  rm -f "$tmp"
}

deploy_base_lab_config() {
  wait_for_wazuh_base_files 10 || return 1
  apply_github_rules || return 1
  apply_auto_enroll || return 1
  restart_wazuh_if_valid
}

fresh_lab_bootstrap() {
  local install_ran=false

  echo "======================================"
  echo "     Fresh Lab Bootstrap Starting"
  echo "======================================"

  ensure_dirs
  install_required_tools

  info "Repo path: $REPO_DIR"
  info "Syncing GitHub repo..."
  safe_git_pull || warn "Git pull failed. Continuing with local files."

  if ! wazuh_base_files_exist; then
    install_wazuh_stack || return 1
    install_ran=true
  elif ! systemctl is-active --quiet wazuh-manager; then
    info "Wazuh files exist but wazuh-manager is not active. Starting services..."
    run_root systemctl start wazuh-manager 2>/dev/null || true
    run_root systemctl start wazuh-indexer 2>/dev/null || true
    run_root systemctl start wazuh-dashboard 2>/dev/null || true
  else
    info "Wazuh already installed and running."
  fi

  if [ "$install_ran" = true ]; then
    capture_dashboard_credentials
  fi

  deploy_base_lab_config || return 1

  echo
  echo "======================================"
  echo "     Bootstrap Complete"
  echo "======================================"
  show_dashboard_info
  echo
  echo "Agent list:"
  run_root /var/ossec/bin/agent_control -l 2>/dev/null || true
}

full_uninstall_cleanup() {
  echo "======================================"
  echo "   FULL WAZUH UNINSTALL / CLEANUP"
  echo "======================================"
  warn "This completely removes Wazuh."
  warn "All Wazuh data/config/dashboard/indexer data will be lost."
  echo

  read -r -p "Type YES to continue: " confirm
  if [ "$confirm" != "YES" ]; then
    info "Uninstall cancelled."
    return 0
  fi

  info "Stopping services..."
  run_root systemctl stop wazuh-manager 2>/dev/null || true
  run_root systemctl stop wazuh-indexer 2>/dev/null || true
  run_root systemctl stop wazuh-dashboard 2>/dev/null || true
  run_root systemctl stop filebeat 2>/dev/null || true

  info "Disabling services..."
  run_root systemctl disable wazuh-manager 2>/dev/null || true
  run_root systemctl disable wazuh-indexer 2>/dev/null || true
  run_root systemctl disable wazuh-dashboard 2>/dev/null || true
  run_root systemctl disable filebeat 2>/dev/null || true

  info "Removing packages..."
  run_root apt remove --purge -y wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>/dev/null || true
  run_root apt autoremove -y

  info "Removing directories..."
  run_root rm -rf /var/ossec
  run_root rm -rf /var/lib/wazuh*
  run_root rm -rf /usr/share/wazuh*
  run_root rm -rf /etc/wazuh*
  run_root rm -rf /var/lib/opensearch
  run_root rm -rf /usr/share/opensearch-dashboards
  run_root rm -rf /etc/filebeat
  run_root rm -rf /var/lib/filebeat
  run_root rm -rf /var/log/filebeat
  run_root rm -rf /var/log/wazuh*

  info "Reloading systemd..."
  run_root systemctl daemon-reload

  info "Wazuh fully removed."
}

edit_github_rules() {
  run_as_user nano "$GITHUB_RULES"
}

git_add_commit_push() {
  local msg

  if [ ! -d "$REPO_DIR/.git" ]; then
    warn "Not a Git repo: $REPO_DIR"
    return 1
  fi

  cd "$REPO_DIR" || return 1

  ensure_git_identity || return 1

  run_as_user git status

  read -r -p "Commit message: " msg
  if [ -z "$msg" ]; then
    warn "Commit message cannot be empty."
    return 1
  fi

  info "Staging changes..."
  run_as_user git add .

  info "Committing..."
  run_as_user git commit -m "$msg" || warn "Nothing to commit or commit failed."

  info "Syncing with GitHub..."
  safe_git_pull || return 1

  info "Pushing to GitHub..."
  run_as_user git push
}

show_install_debug() {
  echo "======================================"
  echo "   Wazuh Install Debug"
  echo "======================================"
  echo
  echo "Files:"
  run_root ls -ld /var/ossec 2>/dev/null || true
  run_root ls -l /var/ossec/etc/ossec.conf 2>/dev/null || true
  run_root ls -l /var/ossec/bin/wazuh-analysisd 2>/dev/null || true

  echo
  echo "Packages:"
  dpkg -l | grep -E 'wazuh|filebeat|opensearch' || true

  echo
  echo "Services active?"
  systemctl is-active wazuh-manager 2>/dev/null || true
  systemctl is-active wazuh-indexer 2>/dev/null || true
  systemctl is-active wazuh-dashboard 2>/dev/null || true
  systemctl is-active filebeat 2>/dev/null || true

  echo
  echo "Recent install log errors:"
  grep -iE "error|failed|cannot|manager|ossec|dpkg|apt" "$INSTALL_LOG" 2>/dev/null | tail -80 || true
}

# ------------------------------
# MAIN MENU
# ------------------------------
while true; do
  header

  echo "START / RESET"
  echo "1) Fresh Lab Bootstrap (RUN FIRST after lab reset)"
  echo "2) Full Wazuh Uninstall / Cleanup (DANGEROUS)"

  echo
  echo "DAILY WORKFLOW"
  echo "3) Edit GitHub local_rules.xml"
  echo "4) Git add / commit / push"
  echo "5) Deploy latest rules + auto-enroll only"

  echo
  echo "MONITORING / VALIDATION"
  echo "6) Test Wazuh rules/config"
  echo "7) Restart wazuh-manager safely"
  echo "8) Check Wazuh services status"
  echo "9) Check agent list"
  echo "10) Watch Wazuh logs live"
  echo "11) Show Wazuh dashboard info"

  echo
  echo "UTILITIES"
  echo "12) Edit active ossec.conf"
  echo "13) Git pull manual sync"
  echo "14) Show install debug"

  echo
  echo "0) Exit"
  echo "======================================"

  read -r -p "Choose option: " choice

  case "$choice" in
    1)
      fresh_lab_bootstrap
      pause
      ;;
    2)
      full_uninstall_cleanup
      pause
      ;;
    3)
      edit_github_rules
      pause
      ;;
    4)
      git_add_commit_push
      pause
      ;;
    5)
      safe_git_pull || warn "Git pull failed. Continuing with local files."
      deploy_base_lab_config
      pause
      ;;
    6)
      validate_wazuh_config
      pause
      ;;
    7)
      restart_wazuh_if_valid
      pause
      ;;
    8)
      show_services_status
      pause
      ;;
    9)
      run_root /var/ossec/bin/agent_control -l 2>/dev/null || warn "agent_control not available. Is Wazuh installed?"
      pause
      ;;
    10)
      run_root tail -f /var/ossec/logs/ossec.log
      ;;
    11)
      show_dashboard_info
      pause
      ;;
    12)
      backup_file "$ACTIVE_OSSEC" "ossec.conf"
      run_root nano "$ACTIVE_OSSEC"
      pause
      ;;
    13)
      safe_git_pull
      pause
      ;;
    14)
      show_install_debug
      pause
      ;;
    0)
      echo "Exiting."
      exit 0
      ;;
    *)
      warn "Invalid option. Choose 0-14."
      pause
      ;;
  esac
done
