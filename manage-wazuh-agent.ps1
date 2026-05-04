# manage-wazuh-agent.ps1
# Run as Administrator

# -----------------------------
# Admin check
# -----------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "=== Wazuh Agent Manager ===" -ForegroundColor Cyan

# -----------------------------
# Check current install state
# -----------------------------
$WazuhService = Get-Service WazuhSvc -ErrorAction SilentlyContinue

if ($WazuhService) {
    Write-Host "Wazuh Agent is currently installed." -ForegroundColor Yellow
    Write-Host "Service status: $($WazuhService.Status)"
} else {
    Write-Host "Wazuh Agent is currently NOT installed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Choose an option:"
Write-Host "1. Install Wazuh Agent"
Write-Host "2. Uninstall Wazuh Agent"
Write-Host "3. Exit"

$Choice = Read-Host "Enter choice"

# -----------------------------
# INSTALL
# -----------------------------
if ($Choice -eq "1") {

    if ($WazuhService) {
        Write-Host "ERROR: Wazuh Agent is already installed. Install aborted." -ForegroundColor Red
        Write-Host "Run uninstall first, reboot, then install again."
        exit 1
    }

    $WazuhManager = Read-Host "Enter Wazuh Manager IP address"
    $AgentName = Read-Host "Enter Wazuh Agent name"
    $Installer = Read-Host "Enter installer filename, example wazuh-agent-4.14.5-1.msi"

    $InstallerPath = "$env:USERPROFILE\Downloads\$Installer"

    if (!(Test-Path $InstallerPath)) {
        Write-Host "ERROR: Installer not found:" -ForegroundColor Red
        Write-Host $InstallerPath
        exit 1
    }

    Write-Host "Installing Wazuh Agent..." -ForegroundColor Yellow

    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$InstallerPath`" /qn WAZUH_MANAGER=`"$WazuhManager`" WAZUH_AGENT_NAME=`"$AgentName`""

    Write-Host "Starting Wazuh service..."
    Start-Service WazuhSvc -ErrorAction SilentlyContinue

    Write-Host "Enabling Windows logon auditing..."
    auditpol /set /subcategory:"Logon" /failure:enable
    auditpol /set /subcategory:"Logon" /success:enable

    Write-Host "Enabling PowerShell Script Block Logging..."
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
    Set-ItemProperty `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
        -Name EnableScriptBlockLogging `
        -Value 1

    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    $PowerShellLogConfig = @"

  <localfile>
    <location>Microsoft-Windows-PowerShell/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
"@

    if (Test-Path $OssecConf) {
        $conf = Get-Content $OssecConf -Raw

        if ($conf -notmatch "Microsoft-Windows-PowerShell/Operational") {
            $conf = $conf -replace "</ossec_config>", "$PowerShellLogConfig`n</ossec_config>"
            Set-Content -Path $OssecConf -Value $conf
            Write-Host "PowerShell log collection added." -ForegroundColor Green
        } else {
            Write-Host "PowerShell log collection already exists." -ForegroundColor Yellow
        }
    } else {
        Write-Host "WARNING: ossec.conf not found." -ForegroundColor Yellow
    }

    Write-Host "Restarting Wazuh service..."
    Restart-Service WazuhSvc -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Install complete." -ForegroundColor Green
    Get-Service WazuhSvc -ErrorAction SilentlyContinue

    $Reboot = Read-Host "Reboot now? (y/n)"
    if ($Reboot -eq "y") {
        Restart-Computer -Force
    } else {
        Write-Host "Reboot skipped. Reboot later before testing PowerShell logging."
    }

    exit 0
}

# -----------------------------
# UNINSTALL
# -----------------------------
elseif ($Choice -eq "2") {

    if (-not $WazuhService) {
        Write-Host "ERROR: Wazuh Agent is not installed. Uninstall aborted." -ForegroundColor Red
        exit 1
    }

    Write-Host "Stopping Wazuh service..."
    Stop-Service WazuhSvc -Force -ErrorAction SilentlyContinue

    $apps = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", `
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Wazuh Agent*" }

    if ($apps) {
        foreach ($app in $apps) {
            Write-Host "Found: $($app.DisplayName)"
            Write-Host "Uninstalling..."

            if ($app.UninstallString -match "\{.*\}") {
                $guid = $Matches[0]
                Start-Process msiexec.exe -Wait -ArgumentList "/x $guid /qn"
            } else {
                Write-Host "WARNING: Could not detect MSI product code." -ForegroundColor Yellow
                Write-Host $app.UninstallString
            }
        }
    } else {
        Write-Host "WARNING: Wazuh uninstall entry not found." -ForegroundColor Yellow
    }

    $WazuhFolder = "C:\Program Files (x86)\ossec-agent"

    if (Test-Path $WazuhFolder) {
        Write-Host "Removing leftover folder..."
        Remove-Item $WazuhFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "Uninstall complete." -ForegroundColor Green

    $CheckService = Get-Service WazuhSvc -ErrorAction SilentlyContinue
    if ($CheckService) {
        Write-Host "WARNING: Wazuh service still exists. Reboot required." -ForegroundColor Yellow
    } else {
        Write-Host "Wazuh service removed or not present." -ForegroundColor Green
    }

    $Reboot = Read-Host "Reboot now? (y/n)"
    if ($Reboot -eq "y") {
        Restart-Computer -Force
    } else {
        Write-Host "Reboot skipped. Reboot before reinstalling."
    }

    exit 0
}

# -----------------------------
# EXIT
# -----------------------------
else {
    Write-Host "Exiting."
    exit 0
}
