# manage-wazuh-agent.ps1
# Run as Administrator
# Verison 2

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
Write-Host "3. Exit"

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
    # SECTION 4D - FIND LATEST WAZUH WINDOWS AGENT INSTALLER
    # This checks Wazuh's package directory for newest MSI
    # Example match: wazuh-agent-4.14.5-1.msi
    # Future match:  wazuh-agent-5.0.0-1.msi
    # ------------------------------------------------------------
    $PackagePage = "https://packages.wazuh.com/4.x/windows/"
    $DownloadFolder = "$env:TEMP"

    Write-Host "Checking Wazuh package site for latest Windows agent..." -ForegroundColor Yellow

    try {
        $Page = Invoke-WebRequest -Uri $PackagePage -UseBasicParsing
    }
    catch {
        Write-Host "ERROR: Could not reach Wazuh package site." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }

    $LatestInstaller = $Page.Links.href |
        Where-Object { $_ -match '^wazuh-agent-[0-9]+\.[0-9]+\.[0-9]+-\d+\.msi$' } |
        Sort-Object {
            if ($_ -match 'wazuh-agent-(\d+)\.(\d+)\.(\d+)-(\d+)\.msi') {
                [version]"$($Matches[1]).$($Matches[2]).$($Matches[3]).$($Matches[4])"
            }
        } -Descending |
        Select-Object -First 1

    if (-not $LatestInstaller) {
        Write-Host "ERROR: Could not find Wazuh agent MSI on package page." -ForegroundColor Red
        exit 1
    }

    $InstallerUrl = "$PackagePage$LatestInstaller"
    $InstallerPath = Join-Path $DownloadFolder $LatestInstaller

    Write-Host "Latest installer found: $LatestInstaller" -ForegroundColor Green


    # ------------------------------------------------------------
    # SECTION 4E - DOWNLOAD LATEST INSTALLER
    # ------------------------------------------------------------
    Write-Host "Downloading installer..." -ForegroundColor Yellow

    try {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing
    }
    catch {
        Write-Host "ERROR: Installer download failed." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }

    if (!(Test-Path $InstallerPath)) {
        Write-Host "ERROR: Installer was not found after download." -ForegroundColor Red
        Write-Host $InstallerPath
        exit 1
    }


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
# SECTION 6 - EXIT SCRIPT
# ============================================================
else {
    Write-Host "Exiting."
    exit 0
}
