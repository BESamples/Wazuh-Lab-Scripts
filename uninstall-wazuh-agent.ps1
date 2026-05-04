if (Get-Service WazuhSvc -ErrorAction SilentlyContinue) {
    Write-Host "ERROR: Wazuh Agent is already installed." -ForegroundColor Red
    Write-Host "Run uninstall-wazuh-agent.ps1 first, reboot, then run setup again."
    exit 1
}

# uninstall-wazuh-agent.ps1
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

Write-Host "=== Wazuh Agent Uninstall / Cleanup ===" -ForegroundColor Cyan

# -----------------------------
# Stop Wazuh service
# -----------------------------
$service = Get-Service WazuhSvc -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "Stopping Wazuh service..."
    Stop-Service WazuhSvc -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "Wazuh service not found. Continuing cleanup..."
}

# -----------------------------
# Find Wazuh Agent uninstall entry
# -----------------------------
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$wazuhApps = foreach ($path in $uninstallPaths) {
    Get-ItemProperty $path -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*Wazuh Agent*" }
}

if ($wazuhApps) {
    foreach ($app in $wazuhApps) {
        Write-Host "Found: $($app.DisplayName)"

        if ($app.UninstallString -match "\{[A-Fa-f0-9\-]+\}") {
            $productCode = $Matches[0]
            Write-Host "Uninstalling Wazuh Agent..."
            Start-Process msiexec.exe -Wait -ArgumentList "/x $productCode /qn"
        } else {
            Write-Host "Uninstall string found, but MSI product code was not detected." -ForegroundColor Yellow
            Write-Host $app.UninstallString
        }
    }
} else {
    Write-Host "No Wazuh Agent uninstall entry found."
}

# -----------------------------
# Remove leftover folder
# -----------------------------
$wazuhFolder = "C:\Program Files (x86)\ossec-agent"

if (Test-Path $wazuhFolder) {
    Write-Host "Removing leftover Wazuh folder..."
    Remove-Item $wazuhFolder -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "No leftover Wazuh folder found."
}

# -----------------------------
# Verify removal
# -----------------------------
$serviceCheck = Get-Service WazuhSvc -ErrorAction SilentlyContinue

if ($serviceCheck) {
    Write-Host "WARNING: Wazuh service still exists. A reboot may be required." -ForegroundColor Yellow
} else {
    Write-Host "Wazuh service removed or not present." -ForegroundColor Green
}

Write-Host ""
Write-Host "Cleanup complete." -ForegroundColor Green

# -----------------------------
# Reboot prompt
# -----------------------------
$reboot = Read-Host "Reboot now? (y/n)"

if ($reboot -eq "y") {
    Restart-Computer -Force
} else {
    Write-Host "Reboot skipped. Please reboot before reinstalling the Wazuh Agent."
}