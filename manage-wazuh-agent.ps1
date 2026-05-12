# manage-wazuh-agent.ps1
# Run as Administrator
# Version 1.06
# Added FIM to menu and will add FIM capibilites to osssec configuration file.

# ============================================================
# Wazuh Agent Manager
# ============================================================

# ============================================================
# SECTION 1 - ADMIN CHECK
# ============================================================
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "ERROR: Run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "=== Wazuh Agent Manager ===" -ForegroundColor Cyan


# ============================================================
# SECTION 2 - CHECK CURRENT WAZUH INSTALL STATE
# ============================================================
$WazuhService = Get-Service WazuhSvc -ErrorAction SilentlyContinue

if ($WazuhService) {
    Write-Host "Wazuh Agent is currently installed." -ForegroundColor Yellow
    Write-Host "Service status: $($WazuhService.Status)"
} else {
    Write-Host "Wazuh Agent is currently NOT installed." -ForegroundColor Yellow
}


# ============================================================
# SECTION 3 - MAIN MENU
# ============================================================
Write-Host ""
Write-Host "Choose an option:"
Write-Host "1. Install Wazuh Agent"
Write-Host "2. Uninstall Wazuh Agent"
Write-Host "3. Add Fim Monitoring"
Write-Host "4. Exit"

$Choice = Read-Host "Enter choice"


# ============================================================
# SECTION 4 - INSTALL WAZUH AGENT
# ============================================================
if ($Choice -eq "1") {

    # ------------------------------------------------------------
    # SECTION 4A - BLOCK INSTALL IF ALREADY INSTALLED
    # ------------------------------------------------------------
    if ($WazuhService) {
        Write-Host "ERROR: Wazuh Agent is already installed. Install aborted." -ForegroundColor Red
        Write-Host "Run uninstall first, reboot, then install again."
        exit 1
    }


    # ------------------------------------------------------------
    # SECTION 4B - ENTER WAZUH MANAGER IP
    # ------------------------------------------------------------
    $WazuhManager = Read-Host "Enter Wazuh Manager IP address"


    # ------------------------------------------------------------
    # SECTION 4C - AGENT NAME OPTION
    # Default = Windows computer name
    # Press Enter to accept default, or type a custom name
    # ------------------------------------------------------------
    $DefaultAgentName = $env:COMPUTERNAME
    $AgentName = Read-Host "Enter Wazuh Agent name or press Enter to use [$DefaultAgentName]"

    if ([string]::IsNullOrWhiteSpace($AgentName)) {
        $AgentName = $DefaultAgentName
    }


# ------------------------------------------------------------
# SECTION 4D - SELECT INSTALLER FROM DOWNLOADS
# ------------------------------------------------------------

$DownloadPath = "$env:USERPROFILE\Downloads"

$DetectedInstallers = Get-ChildItem -Path $DownloadPath -Filter "wazuh-agent-*.msi" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if ($DetectedInstallers) {

    Write-Host ""
    Write-Host "Wazuh installers found in Downloads:" -ForegroundColor Green

    for ($i = 0; $i -lt $DetectedInstallers.Count; $i++) {
        Write-Host "$($i + 1). $($DetectedInstallers[$i].Name)"
    }

    Write-Host ""
    Write-Host "Press Enter to use the newest installer:"
    Write-Host "$($DetectedInstallers[0].Name)" -ForegroundColor Yellow

    $InstallerChoice = Read-Host "Enter number, press Enter, or type a filename manually"

    if ([string]::IsNullOrWhiteSpace($InstallerChoice)) {
        $Installer = $DetectedInstallers[0].Name
    }
    elseif ($InstallerChoice -match '^\d+$' -and [int]$InstallerChoice -ge 1 -and [int]$InstallerChoice -le $DetectedInstallers.Count) {
        $Installer = $DetectedInstallers[[int]$InstallerChoice - 1].Name
    }
    else {
        $Installer = $InstallerChoice
    }

} else {

    Write-Host "No Wazuh installer found in Downloads." -ForegroundColor Yellow
    $Installer = Read-Host "Enter installer filename manually, example wazuh-agent-4.14.5-1.msi"
}

$InstallerPath = Join-Path $DownloadPath $Installer

if (!(Test-Path $InstallerPath)) {
    Write-Host "ERROR: Installer not found:" -ForegroundColor Red
    Write-Host $InstallerPath
    exit 1
}

Write-Host "Using installer: $InstallerPath" -ForegroundColor Green

    # ------------------------------------------------------------
    # SECTION 4E - CONFIRM INSTALL SETTINGS / ALLOW CORRECTIONS
    # ------------------------------------------------------------
    do {
        Write-Host ""
        Write-Host "===== INSTALL SUMMARY =====" -ForegroundColor Cyan
        Write-Host "1. Wazuh Manager IP : $WazuhManager"
        Write-Host "2. Agent Name       : $AgentName"
        Write-Host "3. Installer        : $Installer"
        Write-Host "4. Proceed with install"
        Write-Host "5. Cancel install"
        Write-Host ""

        $ConfirmChoice = Read-Host "Enter 1-3 to correct, 4 to install, or 5 to cancel"

        switch ($ConfirmChoice) {
            "1" {
                $WazuhManager = Read-Host "Enter corrected Wazuh Manager IP address"
            }

            "2" {
                $DefaultAgentName = $env:COMPUTERNAME
                $NewAgentName = Read-Host "Enter corrected Agent Name or press Enter to use [$DefaultAgentName]"

                if ([string]::IsNullOrWhiteSpace($NewAgentName)) {
                    $AgentName = $DefaultAgentName
                } else {
                    $AgentName = $NewAgentName
                }
            }

            "3" {
                $Installer = Read-Host "Enter corrected installer filename from Downloads"
                $InstallerPath = Join-Path $DownloadPath $Installer

                if (!(Test-Path $InstallerPath)) {
                    Write-Host "ERROR: Installer not found:" -ForegroundColor Red
                    Write-Host $InstallerPath
                } else {
                    Write-Host "Installer updated: $InstallerPath" -ForegroundColor Green
                }
            }

            "4" {
                if (!(Test-Path $InstallerPath)) {
                    Write-Host "ERROR: Installer path is invalid. Correct option 3 before installing." -ForegroundColor Red
                } else {
                    $ProceedInstall = $true
                }
            }

            "5" {
                Write-Host "Install cancelled." -ForegroundColor Yellow
                exit 0
            }

            default {
                Write-Host "Invalid choice. Please enter 1, 2, 3, 4, or 5." -ForegroundColor Yellow
            }
        }

    } until ($ProceedInstall -eq $true)



    # ------------------------------------------------------------
    # SECTION 4F - INSTALL WAZUH AGENT
    # ------------------------------------------------------------
    Write-Host "Installing Wazuh Agent as [$AgentName]..." -ForegroundColor Yellow

    Start-Process msiexec.exe -Wait -ArgumentList @(
        "/i `"$InstallerPath`"",
        "/qn",
        "WAZUH_MANAGER=`"$WazuhManager`"",
        "WAZUH_REGISTRATION_SERVER=`"$WazuhManager`"",
        "WAZUH_AGENT_NAME=`"$AgentName`""
    )


    # ------------------------------------------------------------
    # SECTION 4G - START WAZUH SERVICE
    # ------------------------------------------------------------
    Write-Host "Starting Wazuh service..."
    Start-Service WazuhSvc -ErrorAction SilentlyContinue


    # ------------------------------------------------------------
    # SECTION 4H - ENABLE WINDOWS LOGON AUDITING
    # ------------------------------------------------------------
    Write-Host "Enabling Windows logon auditing..."
    auditpol /set /subcategory:"Logon" /failure:enable
    auditpol /set /subcategory:"Logon" /success:enable


    # ------------------------------------------------------------
    # SECTION 4I - ENABLE POWERSHELL SCRIPT BLOCK LOGGING
    # ------------------------------------------------------------
    Write-Host "Enabling PowerShell Script Block Logging..."
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null

    Set-ItemProperty `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
        -Name EnableScriptBlockLogging `
        -Value 1


    # ------------------------------------------------------------
    # SECTION 4J - ADD POWERSHELL EVENT LOG COLLECTION TO OSSEC.CONF
    # ------------------------------------------------------------
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


    # ------------------------------------------------------------
    # SECTION 4K - RESTART WAZUH SERVICE
    # ------------------------------------------------------------
    Write-Host "Restarting Wazuh service..."
    Restart-Service WazuhSvc -ErrorAction SilentlyContinue


    # ------------------------------------------------------------
    # SECTION 4L - INSTALL COMPLETE / REBOOT OPTION
    # ------------------------------------------------------------
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


# ============================================================
# SECTION 5 - UNINSTALL WAZUH AGENT
# ============================================================
elseif ($Choice -eq "2") {

    # ------------------------------------------------------------
    # SECTION 5A - BLOCK UNINSTALL IF NOT INSTALLED
    # ------------------------------------------------------------
    if (-not $WazuhService) {
        Write-Host "ERROR: Wazuh Agent is not installed. Uninstall aborted." -ForegroundColor Red
        exit 1
    }


    # ------------------------------------------------------------
    # SECTION 5B - STOP WAZUH SERVICE
    # ------------------------------------------------------------
    Write-Host "Stopping Wazuh service..."
    Stop-Service WazuhSvc -Force -ErrorAction SilentlyContinue


    # ------------------------------------------------------------
    # SECTION 5C - FIND WAZUH UNINSTALL ENTRY
    # ------------------------------------------------------------
    $apps = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", `
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Wazuh Agent*" }


    # ------------------------------------------------------------
    # SECTION 5D - UNINSTALL WAZUH AGENT
    # ------------------------------------------------------------
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


    # ------------------------------------------------------------
    # SECTION 5E - REMOVE LEFTOVER WAZUH FOLDER
    # ------------------------------------------------------------
    $WazuhFolder = "C:\Program Files (x86)\ossec-agent"

    if (Test-Path $WazuhFolder) {
        Write-Host "Removing leftover folder..."
        Remove-Item $WazuhFolder -Recurse -Force -ErrorAction SilentlyContinue
    }


    # ------------------------------------------------------------
    # SECTION 5F - UNINSTALL COMPLETE / SERVICE CHECK / REBOOT OPTION
    # ------------------------------------------------------------
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

# ============================================================
# SECTION 6 - ADD FIM MONITORING
# ============================================================

elseif ($Choice -eq "3") {

    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
    $TestFolder = "C:\Wazuh-Test"

    $FIMEntries = @(
'    <directories realtime="yes" report_changes="yes">C:\Users</directories>',
'    <directories realtime="yes" report_changes="yes">C:\Wazuh-Test</directories>'
)

    if (-not (Test-Path $TestFolder)) {
        New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
        Write-Host "Created folder: $TestFolder" -ForegroundColor Green
    }

    if (Test-Path $OssecConf) {
        $conf = Get-Content $OssecConf -Raw

        Write-Host ""
        Write-Host "This option will add recommended FIM monitoring for:" -ForegroundColor Cyan
        Write-Host " - C:\Users"
        Write-Host " - C:\Wazuh-Test"
        Write-Host ""

        $Answer = Read-Host "Do you want to update ossec.conf now? (Y/N)"

        if ($Answer -notmatch "^[Yy]$") {
            Write-Host "FIM configuration update cancelled." -ForegroundColor Yellow
            exit 0
        }

        foreach ($Entry in $FIMEntries) {
            if ($conf -notmatch [regex]::Escape($Entry)) {
                $conf = $conf -replace "(?s)(<syscheck>.*?)(</syscheck>)", "`$1`n$Entry`n`$2"
                Write-Host "Added FIM monitoring entry: $Entry" -ForegroundColor Green
            }
            else {
                Write-Host "FIM monitoring entry already exists: $Entry" -ForegroundColor Yellow
            }
        }

        Set-Content -Path $OssecConf -Value $conf

        Write-Host "Restarting Wazuh service..."
        Restart-Service WazuhSvc -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "ERROR: ossec.conf not found. Is the Wazuh Agent installed?" -ForegroundColor Red
        exit 1
    }

    exit 0
}


# ============================================================
# SECTION 6 - INVALID OPTION / EXIT
# ============================================================

elseif ($Choice -eq "4") {
    Write-Host "Exiting."
    exit 0
}

else {
    Write-Host "Invalid option selected." -ForegroundColor Yellow
    exit 1
}
