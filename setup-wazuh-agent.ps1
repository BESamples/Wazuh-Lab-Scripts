# setup-wazuh-agent.ps1
# Run as Administrator

# -----------------------------
# Safety check: Run as Admin
# -----------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "ERROR: Please run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

# -----------------------------
# Safety check: Existing install
# -----------------------------
if (Get-Service WazuhSvc -ErrorAction SilentlyContinue) {
    Write-Host "ERROR: Wazuh Agent is already installed." -ForegroundColor Red
    Write-Host "Run uninstall-wazuh-agent.ps1 first, reboot, then run setup again."
    exit 1
}

Write-Host "=== Wazuh Windows Agent Setup ===" -ForegroundColor Cyan

# -----------------------------
# User prompts
# -----------------------------
$WazuhManager = Read-Host "Enter Wazuh Manager IP address"
$AgentName = Read-Host "Enter Wazuh Agent name"
$Installer = Read-Host "Enter Wazuh installer filename, example wazuh-agent-4.14.5-1.msi"

$DownloadPath = "$env:USERPROFILE\Downloads\$Installer"

# -----------------------------
# Verify installer exists
# -----------------------------
if (!(Test-Path $DownloadPath)) {
    Write-Host "ERROR: Installer not found at:" -ForegroundColor Red
    Write-Host $DownloadPath
    Write-Host "Place the MSI in your Downloads folder and run the script again."
    exit 1
}

# -----------------------------
# Install Wazuh Agent
# -----------------------------
Write-Host "Installing Wazuh Agent..." -ForegroundColor Yellow

Start-Process msiexec.exe -Wait -ArgumentList "/i `"$DownloadPath`" /qn WAZUH_MANAGER=`"$WazuhManager`" WAZUH_AGENT_NAME=`"$AgentName`""

# -----------------------------
# Start Wazuh service
# -----------------------------
Write-Host "Starting Wazuh service..." -ForegroundColor Yellow
Start-Service WazuhSvc -ErrorAction SilentlyContinue

# -----------------------------
# Enable Windows logon auditing
# -----------------------------
Write-Host "Enabling Windows logon auditing..." -ForegroundColor Yellow
auditpol /set /subcategory:"Logon" /failure:enable
auditpol /set /subcategory:"Logon" /success:enable

# -----------------------------
# Enable PowerShell Script Block Logging
# -----------------------------
Write-Host "Enabling PowerShell Script Block Logging..." -ForegroundColor Yellow

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null

Set-ItemProperty `
    -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
    -Name EnableScriptBlockLogging `
    -Value 1

# -----------------------------
# Add PowerShell Operational log collection
# -----------------------------
$OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

$PowerShellLogConfig = @"

  <localfile>
    <location>Microsoft-Windows-PowerShell/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
"@

if (Test-Path $OssecConf) {
    Write-Host "Configuring PowerShell log collection..." -ForegroundColor Yellow

    $conf = Get-Content $OssecConf -Raw

    if ($conf -notmatch "Microsoft-Windows-PowerShell/Operational") {
        $conf = $conf -replace "</ossec_config>", "$PowerShellLogConfig`n</ossec_config>"
        Set-Content -Path $OssecConf -Value $conf
        Write-Host "PowerShell log collection added." -ForegroundColor Green
    } else {
        Write-Host "PowerShell log collection already exists." -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR: ossec.conf not found." -ForegroundColor Red
}

# -----------------------------
# Restart Wazuh service
# -----------------------------
Write-Host "Restarting Wazuh service..." -ForegroundColor Yellow
Restart-Service WazuhSvc -ErrorAction SilentlyContinue

# -----------------------------
# Show status
# -----------------------------
Write-Host ""
Write-Host "=== Wazuh Agent Status ===" -ForegroundColor Cyan
Get-Service WazuhSvc

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host "A reboot is recommended before testing PowerShell logging." -ForegroundColor Yellow

# -----------------------------
# Reboot prompt
# -----------------------------
$reboot = Read-Host "Reboot now? (y/n)"

if ($reboot -eq "y") {
    Restart-Computer -Force
} else {
    Write-Host "Reboot skipped. Please reboot later."
}
