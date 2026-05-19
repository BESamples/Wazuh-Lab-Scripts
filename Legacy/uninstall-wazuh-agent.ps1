# uninstall-wazuh-agent.ps1

# --- Admin check ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "ERROR: Run PowerShell as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "=== Uninstalling Wazuh Agent ===" -ForegroundColor Cyan

# --- Stop service ---
if (Get-Service WazuhSvc -ErrorAction SilentlyContinue) {
    Write-Host "Stopping service..."
    Stop-Service WazuhSvc -Force
}

# --- Uninstall via registry ---
$apps = Get-ItemProperty `
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", `
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
-ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName -like "*Wazuh Agent*" }

if ($apps) {
    foreach ($app in $apps) {
        Write-Host "Uninstalling $($app.DisplayName)..."

        if ($app.UninstallString -match "\{.*\}") {
            $guid = $Matches[0]
            Start-Process msiexec.exe -Wait -ArgumentList "/x $guid /qn"
        }
    }
} else {
    Write-Host "Wazuh uninstall entry not found." -ForegroundColor Yellow
}

# --- Remove leftover folder ---
$path = "C:\Program Files (x86)\ossec-agent"
if (Test-Path $path) {
    Write-Host "Removing leftover files..."
    Remove-Item $path -Recurse -Force
}

# --- Verify ---
if (Get-Service WazuhSvc -ErrorAction SilentlyContinue) {
    Write-Host "WARNING: Service still exists. Reboot required." -ForegroundColor Yellow
} else {
    Write-Host "Uninstall complete." -ForegroundColor Green
}

# --- Reboot ---
$reboot = Read-Host "Reboot now? (y/n)"
if ($reboot -eq "y") {
    Restart-Computer -Force
}
