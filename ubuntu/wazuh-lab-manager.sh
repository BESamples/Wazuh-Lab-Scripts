#!/usr/bin/env bash

# ============================================================
# Wazuh Lab Manager - Overhauled
# Lab purpose:
#   - Fresh Wazuh Manager bootstrap after VM reset
#   - Deploy GitHub local_rules.xml
#   - Apply YARA decoder + Windows Active Response safely
#   - Validate before restart
#
# Recommended run:
#   cd ~/Wazuh-Lab-Scripts/ubuntu
#   chmod +x wazuh-lab-manager.sh
#   sudo ./wazuh-lab-manager.sh
# ============================================================

# Do not use set -e in a menu script. We want errors to return to menu.
set -o pipefail

# ------------------------------
# PATH / USER DETECTION
# ------------------------------
SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SCRIPT_BASE="$(basename "$SCRIPT_DIR")"

# If script is inside repo/ubuntu, repo root is parent. Otherwise repo root is script folder.
if [ "$SCRIPT_BASE" = "ubuntu" ]; then
  REPO_DIR_DEFAULT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  REPO_DIR_DEFAULT="$SCRIPT_DIR"
fi

REPO_DIR="${REPO_DIR:-$REPO_DIR_DEFAULT}"
REAL_USER="${SUDO_USER:-$(id -un)}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6 2>/dev/null)"

# ------------------------------
# CONFIG
# ------------------------------
WAZUH_VERSION="4.14"

GITHUB_RULES="$REPO_DIR/wazuh-rules/local_rules.xml"
AUTOENROLL_SNIPPET="$REPO_DIR/wazuh-configs/ossec-auth-autoenroll.xml"
YARA_AR_SNIPPET="$REPO_DIR/wazuh-configs/ossec-yara-active-response.xml"
YARA_DECODER_SNIPPET="$REPO_DIR/wazuh-configs/local-yara-decoder.xml"

ACTIVE_RULES="/var/ossec/etc/rules/local_rules.xml"
ACTIVE_OSSEC="/var/ossec/etc/ossec.conf"
ACTIVE_DECODERS="/var/ossec/etc/decoders/local_decoder.xml"

BACKUP_DIR="$REPO_DIR/backups"
LAB_INFO_DIR="$REPO_DIR/wazuh-configs"
LAB_INFO_FILE="$LAB_INFO_DIR/dashboard-admin.txt"
INSTALL_LOG="$REPO_DIR/wazuh-install-output.log"

YARA_DECODER_PRIMARY="yara"
YARA_DECODER_LEGACY="yara_decoder"
YARA_COMMAND_NAME="yara_windows"

# ------------------------------
# BASIC HELPERS
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
  echo "        Wazuh Lab Manager"
  echo "======================================"
}

info() { echo "[+] $*"; }
warn() { echo "[!] $*"; }
fail() { echo "[x] $*"; }

ensure_repo_dirs() {
  run_as_user mkdir -p "$BACKUP_DIR" "$LAB_INFO_DIR" "$(dirname "$GITHUB_RULES")"
}

wazuh_group() {
  if getent group wazuh >/dev/null 2>&1; then
    echo "wazuh"
  elif getent group ossec >/dev/null 2>&1; then
    echo "ossec"
  else
    echo "root"
  fi
}

fix_wazuh_file_perms() {
  local file="$1"
  local group
  group="$(wazuh_group)"

  if [ -e "$file" ]; then
    run_root chown "root:$group" "$file"
    run_root chmod 660 "$file"
  fi
}

backup_file() {
  local file="$1"
  local name="$2"
  local date backup

  date="$(date +"%Y%m%d-%H%M%S")"
  backup="$BACKUP_DIR/${name}.backup-$date"

  ensure_repo_dirs

  if [ -f "$file" ]; then
    run_root cp "$file" "$backup"
    if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
      run_root chown "$REAL_USER:$REAL_USER" "$backup" 2>/dev/null || true
    fi
    info "Backup saved to: $backup"
  else
    warn "File not found for backup: $file"
  fi
}

# ------------------------------
# GIT HELPERS
# ------------------------------
is_git_repo() {
  [ -d "$REPO_DIR/.git" ]
}

safe_git_pull() {
  if ! is_git_repo; then
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
    warn "Git identity is not configured."

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

repo_has_uncommitted_changes() {
  if ! is_git_repo; then
    return 1
  fi

  cd "$REPO_DIR" || return 1
  ! run_as_user git diff --quiet || ! run_as_user git diff --cached --quiet
}

# ------------------------------
# WAZUH CHECKS / INSTALL
# ------------------------------
wazuh_is_installed() {
  [ -d "/var/ossec" ] && [ -f "$ACTIVE_OSSEC" ]
}

wazuh_manager_active() {
  systemctl is-active --quiet wazuh-manager 2>/dev/null
}

install_required_tools() {
  info "Ensuring required tools are installed..."
  run_root apt update
  run_root apt install -y curl git nano
}

start_wazuh_services() {
  info "Starting Wazuh services if present..."
  run_root systemctl start wazuh-manager 2>/dev/null || true
  run_root systemctl start wazuh-indexer 2>/dev/null || true
  run_root systemctl start wazuh-dashboard 2>/dev/null || true
}

install_wazuh_stack() {
  local install_mode install_exit installer

  installer="${REAL_HOME:-$HOME}/wazuh-install.sh"

  info "Wazuh is not installed or install is incomplete."
  info "Downloading Wazuh installer..."
  run_as_user bash -c "cd '${REAL_HOME:-$HOME}' && curl -sO https://packages.wazuh.com/${WAZUH_VERSION}/wazuh-install.sh"

  echo
  echo "Choose Wazuh install mode:"
  echo "1) Normal install"
  echo "2) Overwrite existing Wazuh install (-o) - ERASES existing Wazuh config/data"
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

  if [ "$install_exit" -ne 0 ]; then
    fail "Wazuh install failed."
    return 1
  fi

  if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    run_root chown "$REAL_USER:$REAL_USER" "$INSTALL_LOG" 2>/dev/null || true
  fi

  return 0
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

  ensure_repo_dirs

  cat > "$LAB_INFO_FILE" <<EOF_INNER
Dashboard URL: https://$manager_ip
User: ${dashboard_user:-admin}
Password: $dashboard_pass
EOF_INNER

  chmod 600 "$LAB_INFO_FILE"

  if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    run_root chown "$REAL_USER:$REAL_USER" "$LAB_INFO_FILE" 2>/dev/null || true
  fi

  info "Dashboard credentials saved to: $LAB_INFO_FILE"
  cat "$LAB_INFO_FILE"
}

check_wazuh_manager_ready() {
  local ready=0

  info "Checking Wazuh manager files..."

  if [ ! -d "/var/ossec" ]; then
    warn "/var/ossec was not found. Wazuh Manager is not installed here."
    ready=1
  fi

  if [ ! -x "/var/ossec/bin/wazuh-analysisd" ]; then
    warn "Wazuh analysis test tool not found: /var/ossec/bin/wazuh-analysisd"
    ready=1
  fi

  if [ ! -f "$ACTIVE_OSSEC" ]; then
    warn "Active ossec.conf not found: $ACTIVE_OSSEC"
    ready=1
  fi

  if [ ! -d "/var/ossec/etc/rules" ]; then
    warn "Rules directory not found: /var/ossec/etc/rules"
    ready=1
  fi

  if [ ! -d "/var/ossec/etc/decoders" ]; then
    warn "Decoders directory not found: /var/ossec/etc/decoders"
    ready=1
  fi

  if [ "$ready" -ne 0 ]; then
    echo
    warn "Wazuh Manager files are missing."
    warn "Run Option 1 first, or make sure this is the Wazuh Manager VM."
    return 1
  fi

  info "Wazuh manager files found."
  return 0
}

prepare_wazuh_local_files() {
  info "Preparing Wazuh local rules and decoder files..."

  if [ ! -f "$ACTIVE_OSSEC" ]; then
    warn "Wazuh manager ossec.conf not found: $ACTIVE_OSSEC"
    warn "Install/start Wazuh Manager before deploying rules."
    return 1
  fi

  run_root mkdir -p /var/ossec/etc/rules /var/ossec/etc/decoders

  if [ ! -f "$ACTIVE_RULES" ]; then
    info "Creating missing local_rules.xml skeleton..."
    run_root tee "$ACTIVE_RULES" >/dev/null <<'EOF_RULES'
<group name="local,">
</group>
EOF_RULES
  fi

  if [ ! -f "$ACTIVE_DECODERS" ]; then
    info "Creating missing local_decoder.xml..."
    run_root tee "$ACTIVE_DECODERS" >/dev/null <<'EOF_DECODER'
<!-- Local Wazuh decoders managed by lab script -->
EOF_DECODER
  fi

  fix_wazuh_file_perms "$ACTIVE_RULES"
  fix_wazuh_file_perms "$ACTIVE_DECODERS"

  info "Wazuh local files are ready."
}

validate_wazuh_config() {
  if [ ! -x "/var/ossec/bin/wazuh-analysisd" ]; then
    fail "Cannot validate. wazuh-analysisd not found."
    return 1
  fi

  run_root /var/ossec/bin/wazuh-analysisd -t
}

restart_wazuh_if_valid() {
  info "Validating Wazuh configuration..."

  if validate_wazuh_config; then
    info "Validation passed. Restarting wazuh-manager..."
    run_root systemctl restart wazuh-manager
    return $?
  else
    fail "Config validation failed. Restart cancelled."
    return 1
  fi
}

# ------------------------------
# RULE / DECODER DEPLOYMENT
# ------------------------------
create_default_github_rules_if_missing() {
  if [ -f "$GITHUB_RULES" ]; then
    return 0
  fi

  warn "GitHub rules file not found: $GITHUB_RULES"
  read -r -p "Create a safe starter local_rules.xml? Type YES: " confirm

  if [ "$confirm" != "YES" ]; then
    return 1
  fi

  run_as_user mkdir -p "$(dirname "$GITHUB_RULES")"
  run_as_user tee "$GITHUB_RULES" >/dev/null <<'EOF_RULES'
<group name="local,syscheck,windows,powershell,custom_fim,pii,sysmon,lab_attack_simulation,yara,dlp,windows_dlp,credit_card">

  <rule id="100103" level="10">
    <if_sid>554</if_sid>
    <field name="file" type="pcre2">(?i).*(ssn|social|pii|password|payroll|confidential|secret).*</field>
    <description>Custom: Sensitive-looking file created or modified</description>
  </rule>

  <rule id="100302" level="12">
    <decoded_as>yara</decoded_as>
    <description>Custom: YARA malware scan result detected</description>
  </rule>

</group>
EOF_RULES

  info "Created starter rules file: $GITHUB_RULES"
}

apply_github_rules() {
  create_default_github_rules_if_missing || {
    warn "Rules file missing. Skipping rules copy."
    return 1
  }

  prepare_wazuh_local_files || return 1

  info "Applying GitHub local_rules.xml..."
  backup_file "$ACTIVE_RULES" "local_rules.xml"
  run_root cp "$GITHUB_RULES" "$ACTIVE_RULES"
  fix_wazuh_file_perms "$ACTIVE_RULES"
}

create_yara_decoder_snippet() {
  ensure_repo_dirs

  cat > "$YARA_DECODER_SNIPPET" <<EOF_DECODER
<!-- BEGIN WAZUH LAB YARA DECODER -->
<decoder name="$YARA_DECODER_PRIMARY">
  <prematch>wazuh-yara:</prematch>
</decoder>

<decoder name="yara_child">
  <parent>$YARA_DECODER_PRIMARY</parent>
  <regex>wazuh-yara: (\\S+) - Scan result: (.+)</regex>
  <order>yara_rule,yara_scanned_file</order>
</decoder>

<!-- Legacy decoder name kept so older local_rules.xml using decoded_as=yara_decoder still validates. -->
<decoder name="$YARA_DECODER_LEGACY">
  <prematch>wazuh-yara:</prematch>
</decoder>

<decoder name="yara_decoder_child">
  <parent>$YARA_DECODER_LEGACY</parent>
  <regex>wazuh-yara: (\\S+) - Scan result: (.+)</regex>
  <order>yara_rule,yara_scanned_file</order>
</decoder>
<!-- END WAZUH LAB YARA DECODER -->
EOF_DECODER

  if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    run_root chown "$REAL_USER:$REAL_USER" "$YARA_DECODER_SNIPPET" 2>/dev/null || true
  fi

  info "YARA decoder snippet ready: $YARA_DECODER_SNIPPET"
}

apply_yara_decoder() {
  local tmp

  prepare_wazuh_local_files || return 1
  create_yara_decoder_snippet
  backup_file "$ACTIVE_DECODERS" "local_decoder.xml"

  tmp="$(mktemp)"

  # Remove old managed block, then append fresh block.
  run_root awk '
    /<!-- BEGIN WAZUH LAB YARA DECODER -->/ { skip=1; next }
    /<!-- END WAZUH LAB YARA DECODER -->/ { skip=0; next }
    skip != 1 { print }
  ' "$ACTIVE_DECODERS" > "$tmp"

  cat "$YARA_DECODER_SNIPPET" >> "$tmp"

  run_root cp "$tmp" "$ACTIVE_DECODERS"
  rm -f "$tmp"
  fix_wazuh_file_perms "$ACTIVE_DECODERS"

  info "YARA decoder config applied."
}

create_yara_ar_snippet() {
  ensure_repo_dirs

  cat > "$YARA_AR_SNIPPET" <<EOF_AR
  <command>
    <name>$YARA_COMMAND_NAME</name>
    <executable>yara.bat</executable>
    <timeout_allowed>no</timeout_allowed>
  </command>

  <active-response>
    <disabled>no</disabled>
    <command>$YARA_COMMAND_NAME</command>
    <location>local</location>
    <rules_id>100103,100104,100107,100108</rules_id>
  </active-response>
EOF_AR

  if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    run_root chown "$REAL_USER:$REAL_USER" "$YARA_AR_SNIPPET" 2>/dev/null || true
  fi

  info "YARA Active Response snippet ready: $YARA_AR_SNIPPET"
}

apply_yara_active_response() {
  local tmp1 tmp2

  if [ ! -f "$ACTIVE_OSSEC" ]; then
    warn "Active ossec.conf not found: $ACTIVE_OSSEC"
    return 1
  fi

  create_yara_ar_snippet
  backup_file "$ACTIVE_OSSEC" "ossec.conf"

  if ! run_root grep -q "</ossec_config>" "$ACTIVE_OSSEC"; then
    fail "Cannot find closing </ossec_config> in $ACTIVE_OSSEC"
    return 1
  fi

  tmp1="$(mktemp)"
  tmp2="$(mktemp)"

  # Remove previous managed block.
  run_root awk '
    /<!-- BEGIN WAZUH LAB YARA ACTIVE RESPONSE -->/ { skip=1; next }
    /<!-- END WAZUH LAB YARA ACTIVE RESPONSE -->/ { skip=0; next }
    skip != 1 { print }
  ' "$ACTIVE_OSSEC" > "$tmp1"

  # Insert fresh managed block before closing ossec_config.
  awk -v snippet="$YARA_AR_SNIPPET" '
    /<\/ossec_config>/ && inserted==0 {
      print "  <!-- BEGIN WAZUH LAB YARA ACTIVE RESPONSE -->"
      while ((getline line < snippet) > 0) print line
      close(snippet)
      print "  <!-- END WAZUH LAB YARA ACTIVE RESPONSE -->"
      inserted=1
    }
    { print }
  ' "$tmp1" > "$tmp2"

  run_root cp "$tmp2" "$ACTIVE_OSSEC"
  rm -f "$tmp1" "$tmp2"

  info "YARA Active Response config applied."
}

apply_auto_enroll() {
  local tmp

  if [ ! -f "$AUTOENROLL_SNIPPET" ]; then
    warn "Auto-enroll config not found. Skipping: $AUTOENROLL_SNIPPET"
    return 0
  fi

  if [ ! -f "$ACTIVE_OSSEC" ]; then
    warn "Active ossec.conf not found: $ACTIVE_OSSEC"
    return 1
  fi

  if ! run_root grep -q "</ossec_config>" "$ACTIVE_OSSEC"; then
    fail "Cannot find closing </ossec_config> in $ACTIVE_OSSEC"
    return 1
  fi

  info "Applying auto-enroll config..."
  backup_file "$ACTIVE_OSSEC" "ossec.conf"

  tmp="$(mktemp)"

  # Remove existing auth block and insert repo snippet before closing ossec_config.
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

  info "Auto-enroll config applied."
}

deploy_all_lab_config() {
  check_wazuh_manager_ready || return 1
  prepare_wazuh_local_files || return 1
  apply_github_rules || return 1
  apply_auto_enroll || return 1
  apply_yara_decoder || return 1
  apply_yara_active_response || return 1
  restart_wazuh_if_valid
}

# ------------------------------
# STATUS / DISPLAY
# ------------------------------
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
    warn "If Wazuh was installed outside this script, check the installer output or password file."
  fi
}

show_yara_status() {
  echo "======================================"
  echo "   YARA Decoder / Active Response Status"
  echo "======================================"

  echo
  echo "Decoder file: $ACTIVE_DECODERS"
  if [ -f "$ACTIVE_DECODERS" ]; then
    run_root grep -n "decoder name=\|WAZUH LAB YARA" "$ACTIVE_DECODERS" || true
  else
    warn "Decoder file missing."
  fi

  echo
  echo "ossec.conf YARA block: $ACTIVE_OSSEC"
  if [ -f "$ACTIVE_OSSEC" ]; then
    run_root grep -n "WAZUH LAB YARA ACTIVE RESPONSE\|$YARA_COMMAND_NAME\|yara.bat" "$ACTIVE_OSSEC" || true
  else
    warn "ossec.conf missing."
  fi

  echo
  echo "Rules decoded_as references: $ACTIVE_RULES"
  if [ -f "$ACTIVE_RULES" ]; then
    run_root grep -n "decoded_as.*yara\|decoded_as.*yara_decoder" "$ACTIVE_RULES" || true
  else
    warn "local_rules.xml missing."
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
}

# ------------------------------
# MENU ACTIONS
# ------------------------------
fresh_lab_bootstrap() {
  local install_ran=false

  echo "======================================"
  echo "     Fresh Lab Bootstrap Starting"
  echo "======================================"

  ensure_repo_dirs
  install_required_tools

  info "Repo path: $REPO_DIR"
  info "Syncing GitHub repo..."
  safe_git_pull || {
    warn "Git pull failed. Continuing with local files."
  }

  if ! wazuh_is_installed; then
    install_wazuh_stack || return 1
    install_ran=true
  elif ! wazuh_manager_active; then
    info "Wazuh is installed but wazuh-manager is not active. Starting services..."
    start_wazuh_services
  else
    info "Wazuh already installed and running."
  fi

  if ! wazuh_is_installed; then
    fail "Wazuh install did not complete successfully. /var/ossec or ossec.conf missing."
    return 1
  fi

  if [ "$install_ran" = true ]; then
    capture_dashboard_credentials
  fi

  deploy_all_lab_config || return 1

  echo
  echo "======================================"
  echo "     Bootstrap Complete"
  echo "======================================"
  echo
  show_dashboard_info
  echo
  echo "Agent list:"
  run_root /var/ossec/bin/agent_control -l 2>/dev/null || true
}

full_uninstall_cleanup() {
  echo "======================================"
  echo "   FULL WAZUH UNINSTALL / CLEANUP"
  echo "======================================"
  warn "This will completely remove Wazuh."
  warn "All data, rules, configs, indexer data, and dashboard data will be lost."
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
  create_default_github_rules_if_missing || return 1
  run_as_user nano "$GITHUB_RULES"
}

git_add_commit_push() {
  local msg

  if ! is_git_repo; then
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

deploy_latest_rules() {
  echo "======================================"
  echo "   Deploying Latest Wazuh Rules"
  echo "======================================"

  if ! check_wazuh_manager_ready; then
    return 1
  fi

  prepare_wazuh_local_files || return 1

  if repo_has_uncommitted_changes; then
    warn "You have uncommitted repo changes."
    warn "Run Option 4 first, or deploy may not match GitHub."
    read -r -p "Continue anyway? Type YES: " confirm
    if [ "$confirm" != "YES" ]; then
      return 1
    fi
  fi

  safe_git_pull || {
    warn "Git pull failed. Continuing with local files."
  }

  deploy_all_lab_config
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
  echo "5) Deploy latest rules + decoder + active response"

  echo
  echo "MONITORING / VALIDATION"
  echo "6) Test Wazuh rules/config"
  echo "7) Restart wazuh-manager safely"
  echo "8) Check Wazuh services status"
  echo "9) Check agent list"
  echo "10) Watch Wazuh logs live"
  echo "11) Show Wazuh dashboard info"
  echo "12) Show YARA decoder / active response status"

  echo
  echo "UTILITIES"
  echo "13) Edit active ossec.conf"
  echo "14) Git pull manual sync"
  echo "15) Repair Wazuh local rules/decoder files only"

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
      deploy_latest_rules
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
      show_yara_status
      pause
      ;;
    13)
      check_wazuh_manager_ready && backup_file "$ACTIVE_OSSEC" "ossec.conf" && run_root nano "$ACTIVE_OSSEC"
      pause
      ;;
    14)
      safe_git_pull
      pause
      ;;
    15)
      check_wazuh_manager_ready && prepare_wazuh_local_files
      pause
      ;;
    0)
      echo "Exiting."
      exit 0
      ;;
    *)
      warn "Invalid option. Choose 0-15."
      pause
      ;;
  esac
done
