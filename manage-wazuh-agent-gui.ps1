# ============================================================
# WAZUH AGENT MANAGER GUI
# VERSION 2.4
# TABLE OF CONTENTS
# ============================================================
#
# SECTION 1  - ADMIN CHECK
# SECTION 2  - HELPER FUNCTION: WRITE TO OUTPUT BOX
# SECTION 3  - CHECK / INSTALL MICROSOFT VC++ X64 RUNTIME FOR YARA
# SECTION 4  - INSTALL WAZUH AGENT
# SECTION 5  - UNINSTALL WAZUH AGENT
# SECTION 6  - ADD DEFAULT FIM MONITORING
# SECTION 7  - INSTALL SYSMON
# SECTION 8  - GET CUSTOM FIM PATHS
# SECTION 9  - ADD CUSTOM FIM PATH
# SECTION 10 - WAZUH SERVICE / OSSEC CONFIG TOOLS
# SECTION 11 - INSTALL YARA FROM LOCAL ZIP
# SECTION 12 - DOWNLOAD LAB TOOLS
# SECTION 13 - FSRM DLP TOOLS
# SECTION 14 - RUN YARA TROUBLESHOOTER TEST
# SECTION 15 - DOWNLOAD YARA RULES
# SECTION 16 - BROWSE FOR FIM FOLDER
# SECTION 17 - UPDATE WAZUH STATUS DISPLAY
# SECTION 18 - CREATE MAIN GUI WINDOW
# SECTION 19 - TOP INPUT LABELS
# SECTION 20 - TOP INPUT CONTROLS
# SECTION 21 - WAZUH STATUS INDICATOR
# SECTION 22 - MAIN ACTION BUTTONS
# SECTION 23 - FIM PATH MANAGER CONTROLS
# SECTION 24 - OUTPUT BOX
# SECTION 25 - SHOW GUI
#
# ============================================================
# FEATURE MAP
# ============================================================
#
# WAZUH FEATURES
#   - Install Wazuh Agent ............ Section 4
#   - Uninstall Wazuh Agent .......... Section 5
#   - Restart Wazuh Service .......... Section 10
#   - Open ossec.conf ................ Section 10
#   - Agent Status Display ........... Section 16
#
# FIM FEATURES
#   - Add Default FIM Paths .......... Section 6
#   - View Current FIM Paths ......... Section 8
#   - Add Custom FIM Paths ........... Section 9
#   - Browse FIM Folder .............. Section 15
#   - FIM GUI Controls ............... Section 22
#
# SYSMON FEATURES
#   - Install Sysmon ................. Section 7
#
# YARA FEATURES
#   - VC++ Runtime Validation ........ Section 3
#   - Install YARA ................... Section 11
#   - YARA Troubleshooter ............ Section 13
#   - YARA Rule Downloader ........... Section 14
#
# LAB TOOLS
#   - Download Lab Simulator ......... Section 12
#   - Download AD Lab GUI ............ Section 12
#   - Download DLP GUI ............... Section 12
#   - Download FSRM DLP Lab .......... Section 12
#   - Launch Lab Simulator ........... Section 12
#   - Launch AD Lab GUI .............. Section 12
#   - Launch DLP GUI ................. Section 12
#   - Launch FSRM DLP Server 2019 .... Section 12
#
# GUI LAYOUT
#   - Main Window .................... Section 17
#   - Labels ......................... Section 18
#   - Input Controls ................. Section 19
#   - Status Indicators .............. Section 20
#   - Action Buttons ................. Section 21
#   - FIM Controls ................... Section 22
#   - Output Console ................. Section 23
#   - GUI Startup .................... Section 24
#
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# SECTION 1 - ADMIN CHECK
# ============================================================

$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    [System.Windows.Forms.MessageBox]::Show(
        "Run PowerShell as Administrator.",
        "Administrator Required",
        "OK",
        "Error"
    )
    exit
}

# ============================================================
# SECTION 2 - HELPER FUNCTION: WRITE TO OUTPUT BOX
# ============================================================

function Write-OutputBox {
    param(
        [string]$Message
    )

    if ($OutputBox) {
        $OutputBox.AppendText("$Message`r`n")
    }
}

# ============================================================
# SECTION 3 - CHECK / INSTALL MICROSOFT VC++ X64 RUNTIME FOR YARA
# ============================================================

function Get-VcRuntimeEntries {

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Entries = foreach ($RegPath in $RegistryPaths) {
        Get-ItemProperty $RegPath -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -match "Microsoft Visual C\+\+" -and
                $_.DisplayName -match "Redistributable"
            }
    }

    return $Entries
}

function Test-VcRuntime {

    $Vc64 = Get-VcRuntimeEntries |
        Where-Object {
            $_.DisplayName -match "x64" -or
            $_.DisplayName -match "\(64-bit\)"
        }

    if ($Vc64) {
        return $true
    }

    return $false
}

function Show-VcRuntimeStatus {

    Write-OutputBox "Checking Microsoft VC++ Runtime..."

    $VcEntries = Get-VcRuntimeEntries

    $Vc64 = $VcEntries |
        Where-Object {
            $_.DisplayName -match "x64" -or
            $_.DisplayName -match "\(64-bit\)"
        }

    $Vc86 = $VcEntries |
        Where-Object {
            $_.DisplayName -match "x86" -or
            $_.DisplayName -match "\(32-bit\)"
        }

    if ($Vc64) {
        Write-OutputBox "PASS: VC++ x64 Runtime installed."
        foreach ($Item in $Vc64) {
            Write-OutputBox "  x64: $($Item.DisplayName)"
        }
    }
    else {
        Write-OutputBox "FAIL: VC++ x64 Runtime NOT installed."
        Write-OutputBox "YARA 64-bit needs the x64 VC++ Runtime."
    }

    if ($Vc86) {
        Write-OutputBox "INFO: VC++ x86 Runtime installed. This does not replace x64."
        foreach ($Item in $Vc86) {
            Write-OutputBox "  x86: $($Item.DisplayName)"
        }
    }
    else {
        Write-OutputBox "INFO: VC++ x86 Runtime not detected."
    }

    Write-OutputBox "Download x64 installer if needed:"
    Write-OutputBox "https://aka.ms/vs/17/release/vc_redist.x64.exe"
}

function Uninstall-VcX86Runtime {

    $Vc86 = Get-VcRuntimeEntries |
        Where-Object {
            $_.DisplayName -match "x86" -or
            $_.DisplayName -match "\(32-bit\)"
        }

    if (-not $Vc86) {
        Write-OutputBox "No VC++ x86 Runtime found to uninstall."
        return
    }

    Write-OutputBox "VC++ x86 Runtime entries found:"
    foreach ($Item in $Vc86) {
        Write-OutputBox "  $($Item.DisplayName)"
    }

    $Confirm = [System.Windows.Forms.MessageBox]::Show(
        $form,
        "This will uninstall detected Microsoft Visual C++ x86 Redistributable entries.`r`n`r`nOnly do this in the lab VM if you are sure.`r`n`r`nContinue?",
        "Confirm VC++ x86 Uninstall",
        "YesNo",
        "Warning"
    )

    if ($Confirm -ne "Yes") {
        Write-OutputBox "VC++ x86 uninstall cancelled."
        return
    }

    foreach ($Item in $Vc86) {

        if ($Item.UninstallString -match "\{[A-Fa-f0-9\-]+\}") {
            $Guid = $Matches[0]

            Write-OutputBox "Uninstalling x86 runtime: $($Item.DisplayName)"
            Start-Process msiexec.exe -Wait -ArgumentList "/x $Guid /qn /norestart"
        }
        else {
            Write-OutputBox "Could not find MSI GUID for: $($Item.DisplayName)"
        }
    }

    Write-OutputBox "VC++ x86 uninstall attempt complete. Reboot may be required."
}

function Check-VcRuntimeFromGUI {

    Show-VcRuntimeStatus

    if (Test-VcRuntime) {

        [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Microsoft Visual C++ x64 Runtime found.",
            "Runtime Found",
            "OK",
            "Information"
        )

        return
    }

    $VcInstaller = $comboVcInstaller.SelectedItem

    if ($VcInstaller) {

        if ($VcInstaller -match "x86") {
            Write-OutputBox "ERROR: Selected installer appears to be x86:"
            Write-OutputBox $VcInstaller
            Write-OutputBox "YARA 64-bit needs vc_redist.x64.exe."

            [System.Windows.Forms.MessageBox]::Show(
                $form,
                "The selected installer appears to be x86.`r`n`r`nDownload/select vc_redist.x64.exe instead.",
                "Wrong Runtime Installer",
                "OK",
                "Warning"
            )

            return
        }

        $InstallerPath = Join-Path "$env:USERPROFILE\Downloads" $VcInstaller

        if (!(Test-Path $InstallerPath)) {
            Write-OutputBox "ERROR: VC++ installer not found:"
            Write-OutputBox $InstallerPath
            return
        }

        Write-OutputBox "VC++ x64 installer detected:"
        Write-OutputBox $InstallerPath

        $InstallNow = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "VC++ x64 Runtime is missing.`r`n`r`nInstall detected x64 VC++ installer now?",
            "Install VC++ x64 Runtime",
            "YesNo",
            "Question"
        )

        if ($InstallNow -eq "Yes") {

            Write-OutputBox "Launching VC++ x64 installer..."

            Start-Process `
                -FilePath $InstallerPath `
                -Wait `
                -ArgumentList "/install /quiet /norestart"

            Start-Sleep -Seconds 3

            if (Test-VcRuntime) {

                Write-OutputBox "PASS: VC++ x64 Runtime installed successfully."

                [System.Windows.Forms.MessageBox]::Show(
                    $form,
                    "VC++ x64 Runtime installed successfully.",
                    "Install Complete",
                    "OK",
                    "Information"
                )
            }
            else {

                Write-OutputBox "WARNING: x64 Runtime still not detected after install."

                [System.Windows.Forms.MessageBox]::Show(
                    $form,
                    "VC++ installer finished, but x64 runtime was not detected. A reboot may be needed.",
                    "Install Warning",
                    "OK",
                    "Warning"
                )
            }
        }

        return
    }

    Write-OutputBox "No VC++ x64 installer found in Downloads."
    Write-OutputBox "Download x64 installer from:"
    Write-OutputBox "https://aka.ms/vs/17/release/vc_redist.x64.exe"

    [System.Windows.Forms.MessageBox]::Show(
        $form,
        "VC++ x64 Runtime is missing.`r`n`r`nDownload VC++ Redistributable 2015-2022 x64:`r`nhttps://aka.ms/vs/17/release/vc_redist.x64.exe`r`n`r`nSave it to Downloads, then reopen this GUI or run Check VC++ Runtime again.",
        "Runtime Missing",
        "OK",
        "Warning"
    )
}

# ============================================================
# SECTION 4 - INSTALL WAZUH AGENT
# ============================================================

function Install-WazuhAgent {

    $ManagerIP = $txtManagerIP.Text.Trim()
    $AgentName = $txtAgentName.Text.Trim()
    $Installer = $comboInstaller.SelectedItem

    if ([string]::IsNullOrWhiteSpace($ManagerIP)) {
        [System.Windows.Forms.MessageBox]::Show("Enter Wazuh Manager IP.")
        return
    }

    if ([string]::IsNullOrWhiteSpace($AgentName)) {
        $AgentName = $env:COMPUTERNAME
    }

    if (-not $Installer) {
        [System.Windows.Forms.MessageBox]::Show("Select a Wazuh installer.")
        return
    }

    $InstallerPath = Join-Path "$env:USERPROFILE\Downloads" $Installer

    if (!(Test-Path $InstallerPath)) {
        [System.Windows.Forms.MessageBox]::Show("Installer not found: $InstallerPath")
        return
    }

    $ExistingService = Get-Service WazuhSvc -ErrorAction SilentlyContinue

    if ($ExistingService) {
        [System.Windows.Forms.MessageBox]::Show("Wazuh Agent is already installed. Uninstall first if you need to reinstall.")
        return
    }

    Write-OutputBox "Installing Wazuh Agent as [$AgentName]..."

    Start-Process msiexec.exe -Wait -ArgumentList @(
        "/i `"$InstallerPath`"",
        "/qn",
        "WAZUH_MANAGER=`"$ManagerIP`"",
        "WAZUH_REGISTRATION_SERVER=`"$ManagerIP`"",
        "WAZUH_AGENT_NAME=`"$AgentName`""
    )

    Start-Service WazuhSvc -ErrorAction SilentlyContinue

    Write-OutputBox "Enabling Windows logon auditing..."
    auditpol /set /subcategory:"Logon" /failure:enable | Out-Null
    auditpol /set /subcategory:"Logon" /success:enable | Out-Null

    Write-OutputBox "Enabling PowerShell Script Block Logging..."
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
            Write-OutputBox "PowerShell log collection added to ossec.conf."
        }
        else {
            Write-OutputBox "PowerShell log collection already exists."
        }
    }
    else {
        Write-OutputBox "WARNING: ossec.conf not found."
    }

    Restart-Service WazuhSvc -ErrorAction SilentlyContinue

    Write-OutputBox "Wazuh installation complete. Reboot recommended."
    Update-WazuhStatus
}

# ============================================================
# SECTION 5 - UNINSTALL WAZUH AGENT
# ============================================================

function Uninstall-WazuhAgent {

    $ExistingService = Get-Service WazuhSvc -ErrorAction SilentlyContinue

    if (-not $ExistingService) {
        [System.Windows.Forms.MessageBox]::Show("Wazuh Agent is not installed.")
        return
    }

    $Confirm = [System.Windows.Forms.MessageBox]::Show(
        "Are you sure you want to uninstall the Wazuh Agent?",
        "Confirm Uninstall",
        "YesNo",
        "Warning"
    )

    if ($Confirm -ne "Yes") {
        Write-OutputBox "Uninstall cancelled."
        return
    }

    Write-OutputBox "Stopping Wazuh service..."
    Stop-Service WazuhSvc -Force -ErrorAction SilentlyContinue

    $apps = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", `
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Wazuh Agent*" }

    foreach ($app in $apps) {
        if ($app.UninstallString -match "\{.*\}") {
            $guid = $Matches[0]
            Write-OutputBox "Uninstalling Wazuh Agent..."
            Start-Process msiexec.exe -Wait -ArgumentList "/x $guid /qn"
        }
    }

    $WazuhFolder = "C:\Program Files (x86)\ossec-agent"

    if (Test-Path $WazuhFolder) {
        Write-OutputBox "Removing leftover Wazuh folder..."
        Remove-Item $WazuhFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-OutputBox "Wazuh uninstall complete. Reboot recommended."
    Update-WazuhStatus
}

# ============================================================
# SECTION 6 - ADD DEFAULT FIM MONITORING
# ============================================================

function Add-FIMMonitoring {

    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    $FIMEntries = @(
'    <directories realtime="yes">C:\Users</directories>',
'    <directories realtime="yes">C:\Wazuh-Test</directories>'
)

    if (!(Test-Path "C:\Wazuh-Test")) {
        New-Item -Path "C:\Wazuh-Test" -ItemType Directory -Force | Out-Null
        Write-OutputBox "Created folder: C:\Wazuh-Test"
    }

    if (Test-Path $OssecConf) {
        $conf = Get-Content $OssecConf -Raw

        foreach ($Entry in $FIMEntries) {
            if ($conf -notmatch [regex]::Escape($Entry)) {
                $conf = $conf -replace "(?s)(<syscheck>.*?)(</syscheck>)", "`$1`n$Entry`n`$2"
                Write-OutputBox "Added FIM entry: $Entry"
            }
            else {
                Write-OutputBox "FIM entry already exists: $Entry"
            }
        }

        Set-Content -Path $OssecConf -Value $conf
        Restart-Service WazuhSvc -ErrorAction SilentlyContinue
        Write-OutputBox "Default FIM monitoring added."
        Get-FIMPaths
    }
    else {
        Write-OutputBox "ossec.conf not found. Is Wazuh installed?"
    }
}

# ============================================================
# SECTION 7 - INSTALL SYSMON
# ============================================================

function Install-Sysmon {

    $SysmonFolder = "C:\Sysmon"
    $SysmonZip = "$SysmonFolder\Sysmon.zip"
    $SysmonConfig = "$SysmonFolder\sysmonconfig.xml"
    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    if (!(Test-Path $SysmonFolder)) {
        New-Item -Path $SysmonFolder -ItemType Directory -Force | Out-Null
    }

    Write-OutputBox "Downloading Sysmon..."
    Invoke-WebRequest `
        -Uri "https://download.sysinternals.com/files/Sysmon.zip" `
        -OutFile $SysmonZip

    Write-OutputBox "Extracting Sysmon..."
    Expand-Archive `
        -Path $SysmonZip `
        -DestinationPath $SysmonFolder `
        -Force

    Write-OutputBox "Downloading Sysmon config..."
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" `
        -OutFile $SysmonConfig

    Write-OutputBox "Installing Sysmon..."
    Start-Process `
        -FilePath "$SysmonFolder\Sysmon64.exe" `
        -Wait `
        -ArgumentList "-accepteula -i `"$SysmonConfig`""

    $SysmonLogConfig = @"

  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
"@

    if (Test-Path $OssecConf) {
        $conf = Get-Content $OssecConf -Raw

        if ($conf -notmatch "Microsoft-Windows-Sysmon/Operational") {
            $conf = $conf -replace "</ossec_config>", "$SysmonLogConfig`n</ossec_config>"
            Set-Content -Path $OssecConf -Value $conf
            Write-OutputBox "Sysmon log collection added to ossec.conf."
        }
        else {
            Write-OutputBox "Sysmon log collection already exists."
        }

        Restart-Service WazuhSvc -ErrorAction SilentlyContinue
    }
    else {
        Write-OutputBox "WARNING: ossec.conf not found. Wazuh may not be installed yet."
    }

    Write-OutputBox "Sysmon installation complete."
    Update-WazuhStatus
}

# ============================================================
# SECTION 8 - GET CUSTOM FIM PATHS
# ============================================================

function Get-FIMPaths {

    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    if ($listFimPaths) {
        $listFimPaths.Items.Clear()
    }

    if (!(Test-Path $OssecConf)) {
        Write-OutputBox "ossec.conf not found. Is Wazuh installed?"
        return
    }

    $conf = Get-Content $OssecConf -Raw

    $matches = [regex]::Matches(
        $conf,
        '<directories[^>]*>(.*?)</directories>'
    )

    $CustomPathCount = 0

    foreach ($match in $matches) {
        $path = $match.Groups[1].Value.Trim()

        if ($path -match '^%WINDIR%' -or
            $path -match '^%PROGRAMDATA%' -or
            $path -match '^%PROGRAMFILES%' -or
            $path -match '^C:\\Windows' -or
            $path -match '^C:\\Program Files') {
            continue
        }

        $listFimPaths.Items.Add($path) | Out-Null
        $CustomPathCount++
    }

    if ($CustomPathCount -eq 0) {
        Write-OutputBox "Loaded current FIM paths. No custom/lab FIM paths found."
    }
    else {
        Write-OutputBox "Loaded current custom/lab FIM paths."
    }
}

# ============================================================
# SECTION 9 - ADD CUSTOM FIM PATH
# ============================================================

function Add-FIMPathFromGUI {

    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
    $NewPath = $txtFimPath.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($NewPath)) {
        [System.Windows.Forms.MessageBox]::Show("Enter a folder path first.")
        return
    }

    if (!(Test-Path $OssecConf)) {
        Write-OutputBox "ossec.conf not found. Is Wazuh installed?"
        return
    }

    if (!(Test-Path $NewPath)) {
        $CreateFolder = [System.Windows.Forms.MessageBox]::Show(
            "Folder does not exist. Create it?",
            "Create Folder",
            "YesNo",
            "Question"
        )

        if ($CreateFolder -eq "Yes") {
            New-Item -Path $NewPath -ItemType Directory -Force | Out-Null
            Write-OutputBox "Created folder: $NewPath"
        }
        else {
            return
        }
    }

    $conf = Get-Content $OssecConf -Raw

    if ($conf -match [regex]::Escape($NewPath)) {
        Write-OutputBox "FIM path already exists: $NewPath"
        Get-FIMPaths
        return
    }

    $FimEntry = "    <directories realtime=`"yes`">$NewPath</directories>"

    $conf = $conf -replace "(?s)(<syscheck>.*?)(</syscheck>)", "`$1`n$FimEntry`n`$2"

    Set-Content -Path $OssecConf -Value $conf
    Restart-Service WazuhSvc -ErrorAction SilentlyContinue

    Write-OutputBox "Added FIM path: $NewPath"
    Write-OutputBox "Restarted Wazuh service."

    Get-FIMPaths
}

# ============================================================
# SECTION 10 - WAZUH SERVICE / OSSEC CONFIG TOOLS
# ============================================================

function Restart-WazuhService {

    $WazuhService = Get-Service WazuhSvc -ErrorAction SilentlyContinue

    if (-not $WazuhService) {
        [System.Windows.Forms.MessageBox]::Show(
            "Wazuh Agent service not found.",
            "Service Missing",
            "OK",
            "Error"
        )
        return
    }

    Write-OutputBox "Restarting Wazuh service..."

    Restart-Service WazuhSvc -Force -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2

    Update-WazuhStatus

    Write-OutputBox "Wazuh service restarted."
}


function Open-OssecConf {

    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    if (!(Test-Path $OssecConf)) {
        Write-OutputBox "ossec.conf not found. Is Wazuh installed?"
        return
    }

    Write-OutputBox "Opening ossec.conf in Notepad..."
    Start-Process notepad.exe -ArgumentList "`"$OssecConf`""
}

# ============================================================
# SECTION 11 - INSTALL YARA FROM LOCAL ZIP
# ============================================================

function Install-Yara {

    if (-not (Test-VcRuntime)) {
        Write-OutputBox "ERROR: Microsoft Visual C++ Runtime is missing."
        Write-OutputBox "Run Check VC++ Runtime first or install VC++ Redistributable 2015-2022 x64:"
        Write-OutputBox "https://aka.ms/vs/17/release/vc_redist.x64.exe"

        [System.Windows.Forms.MessageBox]::Show(
            "Microsoft Visual C++ Runtime is missing.`r`n`r`nRun Check VC++ Runtime first, or install VC++ Redistributable 2015-2022 x64:`r`nhttps://aka.ms/vs/17/release/vc_redist.x64.exe",
            "Missing Runtime",
            "OK",
            "Warning"
        )

        return
    }

    $YaraFolder = "C:\Program Files (x86)\ossec-agent\active-response\bin\yara"
    $YaraRulesFolder = "$YaraFolder\rules"
    $YaraZipName = $comboYaraZip.SelectedItem

    if (-not $YaraZipName) {

        Write-OutputBox "No YARA ZIP selected."
        Write-OutputBox "Download YARA Windows ZIP first from:"
        Write-OutputBox "https://github.com/VirusTotal/yara/releases"

        [System.Windows.Forms.MessageBox]::Show(
            "Download a YARA Windows ZIP first.`r`n`r`nDownload from:`r`nhttps://github.com/VirusTotal/yara/releases`r`n`r`nSave the ZIP to Downloads, then reopen this GUI.",
            "YARA ZIP Missing",
            "OK",
            "Warning"
        )

        return
    }

    $YaraZip = Join-Path "$env:USERPROFILE\Downloads" $YaraZipName

    if (!(Test-Path $YaraZip)) {
        Write-OutputBox "ERROR: YARA ZIP not found: $YaraZip"
        return
    }

    Write-OutputBox "Creating YARA folders..."

    New-Item -ItemType Directory -Force -Path $YaraFolder | Out-Null
    New-Item -ItemType Directory -Force -Path $YaraRulesFolder | Out-Null

    Write-OutputBox "Extracting YARA from: $YaraZipName"

    Expand-Archive `
        -Path $YaraZip `
        -DestinationPath $YaraFolder `
        -Force

    $YaraExe = Get-ChildItem `
        -Path $YaraFolder `
        -Filter "yara64.exe" `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($YaraExe) {
        Write-OutputBox "YARA installed successfully."
        Write-OutputBox "YARA executable: $($YaraExe.FullName)"
    }
    else {
        Write-OutputBox "WARNING: yara64.exe was not found after extraction."
    }
}

# ============================================================
# # SECTION 12 - DOWNLOAD LAB TOOLS
# ============================================================

function Download-LabSimulator {

    $Url = "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/Powershell-Scripts/wazuh-lab-sim-gui.ps1"

    $Destination = "$PSScriptRoot\wazuh-lab-sim-gui.ps1"

if (Test-Path $Destination) {

    $Overwrite = [System.Windows.Forms.MessageBox]::Show(
        "File already exists. Overwrite?",
        "Confirm Overwrite",
        "YesNo",
        "Question"
    )

    if ($Overwrite -ne "Yes") {
        Write-OutputBox "Download cancelled."
        return
    }
}

    Write-OutputBox "Downloading Wazuh Lab Simulator..."

    try {

        Invoke-WebRequest `
            -Uri $Url `
            -OutFile $Destination

        Write-OutputBox "Download complete:"
        Write-OutputBox $Destination
    }
    catch {

        Write-OutputBox "Download failed."
        Write-OutputBox $_.Exception.Message
    }
}

function Download-ADLabGUI {

    $Url = "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/Powershell-Scripts/create-adlabuser-gui.ps1"

    $Destination = "$PSScriptRoot\create-adlabuser-gui.ps1"

    if (Test-Path $Destination) {

        $Overwrite = [System.Windows.Forms.MessageBox]::Show(
            "File already exists. Overwrite?",
            "Confirm Overwrite",
            "YesNo",
            "Question"
        )

        if ($Overwrite -ne "Yes") {
            Write-OutputBox "Download cancelled."
            return
        }
    }

    Write-OutputBox "Downloading AD Lab GUI..."

    try {

        Invoke-WebRequest `
            -Uri $Url `
            -OutFile $Destination

        Write-OutputBox "Download complete:"
        Write-OutputBox $Destination
    }
    catch {

        Write-OutputBox "Download failed."
        Write-OutputBox $_.Exception.Message
    }
}


function Launch-LabSimulator {

    $ScriptPath = "$PSScriptRoot\wazuh-lab-sim-gui.ps1"

    if (Test-Path $ScriptPath) {

        Write-OutputBox "Launching Wazuh Lab Simulator..."

        Start-Process powershell.exe `
            -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    }
    else {

        Write-OutputBox "Lab Simulator not found."
    }
}

function Launch-ADLabGUI {

    $ScriptPath = "$PSScriptRoot\create-adlabuser-gui.ps1"

    if (Test-Path $ScriptPath) {

        Write-OutputBox "Launching AD Lab GUI..."

        Start-Process powershell.exe `
            -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    }
    else {

        Write-OutputBox "AD Lab GUI not found."
    }
}


function Download-DlpLabGUI {

   $Url = "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/windows-dlp/windows_dlp-gui.ps1"
$Destination = "$PSScriptRoot\windows-dlp-lab-gui.ps1"

    if (Test-Path $Destination) {
        $Overwrite = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "DLP Lab GUI already exists. Overwrite?",
            "Confirm Overwrite",
            "YesNo",
            "Question"
        )

        if ($Overwrite -ne "Yes") {
            Write-OutputBox "DLP Lab GUI download cancelled."
            return
        }
    }

    Write-OutputBox "Downloading DLP Lab GUI..."

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        Write-OutputBox "Download complete:"
        Write-OutputBox $Destination
    }
    catch {
        Write-OutputBox "DLP Lab GUI download failed."
        Write-OutputBox $_.Exception.Message
    }
}

function Launch-DlpLabGUI {

    $ScriptPath = "$PSScriptRoot\windows-dlp-lab-gui.ps1"

    if (Test-Path $ScriptPath) {
        Write-OutputBox "Launching DLP Lab GUI..."

        Start-Process powershell.exe `
            -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    }
    else {
        Write-OutputBox "DLP Lab GUI not found. Download it first."
    }
}

function Test-IsWindowsServer2019 {

    $Os = Get-CimInstance Win32_OperatingSystem

    Write-OutputBox "Detected OS: $($Os.Caption)"

    if ($Os.Caption -match "Windows Server 2019") {
        return $true
    }

    return $false
  }

# ============================================================
# SECTION 13 - FSRM DLP TOOLS
# ============================================================

function Download-FsrmDlpLab {

    $Url = "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/Powershell-Scripts/setup-fsrm-dlp-lab.ps1"
    $Destination = "$PSScriptRoot\setup-fsrm-dlp-lab.ps1"

    if (Test-Path $Destination) {
        $Overwrite = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "FSRM DLP lab script already exists. Overwrite?",
            "Confirm Overwrite",
            "YesNo",
            "Question"
        )

        if ($Overwrite -ne "Yes") {
            Write-OutputBox "FSRM DLP download cancelled."
            return
        }
    }

    Write-OutputBox "Downloading FSRM DLP lab script..."

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        Write-OutputBox "Download complete:"
        Write-OutputBox $Destination
    }
    catch {
        Write-OutputBox "FSRM DLP script download failed."
        Write-OutputBox $_.Exception.Message
    }
}

   function Launch-FsrmDlpLab {

    if (-not (Test-IsWindowsServer2019)) {
        Write-OutputBox "BLOCKED: FSRM DLP lab can only run on Windows Server 2019."

        [System.Windows.Forms.MessageBox]::Show(
            $form,
            "This FSRM DLP lab script can only run on Windows Server 2019.",
            "Wrong Operating System",
            "OK",
            "Warning"
        )

        return
    }

    $ScriptPath = "$PSScriptRoot\setup-fsrm-dlp-lab.ps1"

    if (!(Test-Path $ScriptPath)) {
        Write-OutputBox "FSRM DLP script not found. Download it first."
        return
    }

    Write-OutputBox "Launching FSRM DLP lab script on Server 2019..."

    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`" -RunNow"
}

function Run-FsrmClassificationNow {

    if (-not (Test-IsWindowsServer2019)) {
        Write-OutputBox "BLOCKED: FSRM Classification only runs on Windows Server 2019."
        return
    }

    Import-Module FileServerResourceManager -ErrorAction SilentlyContinue

    Write-OutputBox "Starting FSRM classification..."

    Start-FsrmClassification -Confirm:$false
    Start-Sleep -Seconds 5

    $Status = Get-FsrmClassification
    Write-OutputBox "FSRM Classification Status: $($Status.Status)"

    if ($Status.LastError) {
        Write-OutputBox "LastError: $($Status.LastError)"
    }
}

function Run-FsrmQuarantineNow {

    if (-not (Test-IsWindowsServer2019)) {
        Write-OutputBox "BLOCKED: FSRM Quarantine only runs on Windows Server 2019."
        return
    }

    Import-Module FileServerResourceManager -ErrorAction SilentlyContinue

    $Jobs = @(
        "Quarantine PII Files",
        "Quarantine PCI Files",
        "Quarantine Confidential Files"
    )

    foreach ($Job in $Jobs) {
        Write-OutputBox "Starting FSRM job: $Job"

        try {
            Start-FsrmFileManagementJob -Name $Job -Confirm:$false
            Write-OutputBox "Started: $Job"
        }
        catch {
            Write-OutputBox "FAILED: $Job"
            Write-OutputBox $_.Exception.Message
        }
    }
}


# ============================================================
# SECTION 14 - RUN YARA TROUBLESHOOTER TEST
# ============================================================

function Test-YaraInstall {

    $YaraFolder = "C:\Program Files (x86)\ossec-agent\active-response\bin\yara"
    $RulesFolder = "C:\Yara-Rules"
    $TestFolder = "C:\Wazuh-Test"
    $TestFile = "$TestFolder\evil.txt"
    $AlwaysRule = "$RulesFolder\always-match.yar"
    $TestRule = "$RulesFolder\test-malware.yar"

    Write-OutputBox "=== YARA Wazuh Troubleshooter ==="

    if (-not (Test-VcRuntime)) {
        Write-OutputBox "FAIL: Microsoft Visual C++ Runtime is missing."
        Write-OutputBox "Run Check VC++ Runtime first or install VC++ Redistributable 2015-2022 x64:"
        Write-OutputBox "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        return
    }
    else {
        Write-OutputBox "PASS: Microsoft Visual C++ Runtime found."
    }

    if (!(Test-Path $YaraFolder)) {
        Write-OutputBox "FAIL: YARA folder missing: $YaraFolder"
        return
    }

    if (!(Test-Path $RulesFolder)) {
        Write-OutputBox "Creating rules folder..."
        New-Item -ItemType Directory -Force -Path $RulesFolder | Out-Null
    }

    $YaraExeItem = Get-ChildItem `
        -Path $YaraFolder `
        -Filter "yara64.exe" `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $YaraExeItem) {
        Write-OutputBox "FAIL: yara64.exe missing under: $YaraFolder"
        return
    }

    $YaraExe = $YaraExeItem.FullName
    Write-OutputBox "Testing YARA version..."

    $VersionResult = & $YaraExe --version

    Write-OutputBox "Version: [$VersionResult]"
    Write-OutputBox "Version ExitCode: $LASTEXITCODE"
    

    if (!(Test-Path $TestFolder)) {
        Write-OutputBox "Creating C:\Wazuh-Test..."
        New-Item -ItemType Directory -Force -Path $TestFolder | Out-Null
    }

    Write-OutputBox "Creating test file..."
    Set-Content -Path $TestFile -Value "MALWARE_TEST_STRING" -Encoding ASCII

    Write-OutputBox "Creating Always_Match rule..."
    Set-Content -Path $AlwaysRule -Encoding ASCII -Value @'
rule Always_Match
{
    condition:
        true
}
'@

    Write-OutputBox "Creating Test_Malware_String rule..."
    Set-Content -Path $TestRule -Encoding ASCII -Value @'
rule Test_Malware_String
{
    strings:
        $a = "MALWARE_TEST_STRING"

    condition:
        $a
}
'@

    Write-OutputBox "Testing Always_Match rule..."
    $AlwaysResult = & $YaraExe $AlwaysRule $TestFile
    Write-OutputBox "AlwaysResult: [$AlwaysResult]"
    Write-OutputBox "ExitCode: $LASTEXITCODE"

    if ($AlwaysResult -match "Always_Match") {
        Write-OutputBox "PASS: Always_Match rule worked."
    }
    else {
        Write-OutputBox "FAIL: Always_Match did not return a match."
    }

    Write-OutputBox "Testing malware string rule..."
    $TestResult = & $YaraExe $TestRule $TestFile
    Write-OutputBox "TestResult: [$TestResult]"
    Write-OutputBox "ExitCode: $LASTEXITCODE"

    if ($TestResult -match "Test_Malware_String") {
        Write-OutputBox "PASS: Test_Malware_String rule worked."
    }
    else {
        Write-OutputBox "FAIL: Test_Malware_String did not return a match."
    }

    Write-OutputBox "YARA executable: $YaraExe"
    Write-OutputBox "Rules folder: $RulesFolder"
    Write-OutputBox "Test file: $TestFile"
}

# ============================================================
# SECTION 15 - DOWNLOAD YARA RULES
# ============================================================

function Download-YaraRules {

    $RulesFolder = "C:\Yara-Rules"

    if (!(Test-Path $RulesFolder)) {
        New-Item -ItemType Directory -Force -Path $RulesFolder | Out-Null
    }

    $Rules = @{
        "lab-pii.yar" = "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/Yara-Rules/lab-pii.yar"
        "lab-malware-test.yar" = "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/Yara-Rules/lab-malware-test.yar"
        "lab-ransomware-test.yar" = "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/Yara-Rules/lab-ransomware-test.yar"
    }

    foreach ($Rule in $Rules.GetEnumerator()) {
        $OutFile = Join-Path $RulesFolder $Rule.Key

        Write-OutputBox "Downloading YARA rule: $($Rule.Key)"

        try {
            Invoke-WebRequest `
                -Uri $Rule.Value `
                -OutFile $OutFile `
                -UseBasicParsing

            Write-OutputBox "Downloaded: $($Rule.Key)"
        }
        catch {
            Write-OutputBox "FAILED: $($Rule.Key)"
            Write-OutputBox $_.Exception.Message
        }
    }

    Write-OutputBox "YARA rules downloaded to C:\Yara-Rules"
    Write-OutputBox "Ready for YARA-Wazuh testing."
}

# ============================================================
# SECTION 16 - BROWSE FOR FIM FOLDER
# ============================================================

# ============================================================

function Browse-FIMFolder {

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select folder to monitor with Wazuh FIM"

    if ($folderBrowser.ShowDialog() -eq "OK") {
        $txtFimPath.Text = $folderBrowser.SelectedPath
    }
}

# ============================================================
# SECTION 17 - UPDATE WAZUH STATUS DISPLAY
# ============================================================

function Update-WazuhStatus {

    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
    $ClientKeys = "C:\Program Files (x86)\ossec-agent\client.keys"
    $WazuhService = Get-Service WazuhSvc -ErrorAction SilentlyContinue

    if ($WazuhService) {
        $lblInstallStatusValue.Text = "Installed / $($WazuhService.Status)"
        $lblInstallStatusValue.ForeColor = [System.Drawing.Color]::Green
    }
    else {
        $lblInstallStatusValue.Text = "Not Installed"
        $lblInstallStatusValue.ForeColor = [System.Drawing.Color]::Red
        $lblManagerStatusValue.Text = "N/A"
        $lblAgentStatusValue.Text = $env:COMPUTERNAME
        $lblRegistrationStatusValue.Text = "Not Installed"
        $lblRegistrationStatusValue.ForeColor = [System.Drawing.Color]::Red
        return
    }

    if (Test-Path $OssecConf) {
        $conf = Get-Content $OssecConf -Raw
        $managerMatch = [regex]::Match($conf, '<address>(.*?)</address>')

        if ($managerMatch.Success) {
            $ManagerIP = $managerMatch.Groups[1].Value.Trim()
            $lblManagerStatusValue.Text = $ManagerIP

            if ([string]::IsNullOrWhiteSpace($txtManagerIP.Text)) {
                $txtManagerIP.Text = $ManagerIP
            }
        }
        else {
            $lblManagerStatusValue.Text = "Not found"
        }
    }
    else {
        $lblManagerStatusValue.Text = "ossec.conf missing"
    }

    $FallbackAgentName = $txtAgentName.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($FallbackAgentName)) {
        $FallbackAgentName = $env:COMPUTERNAME
    }

    $lblAgentStatusValue.Text = $FallbackAgentName

    if (Test-Path $ClientKeys) {
        $keyLine = Get-Content $ClientKeys -ErrorAction SilentlyContinue | Select-Object -First 1

        if (-not [string]::IsNullOrWhiteSpace($keyLine)) {
            $parts = $keyLine -split ' '

            if ($parts.Count -ge 2) {
                $AgentName = $parts[1]
                $lblAgentStatusValue.Text = $AgentName
                $txtAgentName.Text = $AgentName
            }

            $lblRegistrationStatusValue.Text = "Registered"
            $lblRegistrationStatusValue.ForeColor = [System.Drawing.Color]::Green
        }
        else {
            $lblRegistrationStatusValue.Text = "Not Registered / Check Manager"
            $lblRegistrationStatusValue.ForeColor = [System.Drawing.Color]::Red
        }
    }
    else {
        $lblRegistrationStatusValue.Text = "Not Registered / client.keys missing"
        $lblRegistrationStatusValue.ForeColor = [System.Drawing.Color]::Red
    }
}

# ============================================================
# SECTION 18 - CREATE MAIN GUI WINDOW
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.AutoScroll = $true
$form.Text = "Wazuh Agent Manager GUI"
$form.Size = New-Object System.Drawing.Size(850,650)
$form.StartPosition = "CenterScreen"

# ============================================================
# SECTION 19 - TOP INPUT LABELS
# ============================================================

$lblManagerIP = New-Object System.Windows.Forms.Label
$lblManagerIP.Text = "Wazuh Manager IP"
$lblManagerIP.Location = New-Object System.Drawing.Point(20,20)
$lblManagerIP.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblManagerIP)

$lblAgentName = New-Object System.Windows.Forms.Label
$lblAgentName.Text = "Agent Name"
$lblAgentName.Location = New-Object System.Drawing.Point(20,60)
$lblAgentName.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblAgentName)

$lblInstaller = New-Object System.Windows.Forms.Label
$lblInstaller.Text = "Wazuh Installer"
$lblInstaller.Location = New-Object System.Drawing.Point(20,100)
$lblInstaller.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblInstaller)

$lblYaraZip = New-Object System.Windows.Forms.Label
$lblYaraZip.Text = "YARA ZIP"
$lblYaraZip.Location = New-Object System.Drawing.Point(20,140)
$lblYaraZip.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblYaraZip)

$lblVcInstaller = New-Object System.Windows.Forms.Label
$lblVcInstaller.Text = "VC++ Installer"
$lblVcInstaller.Location = New-Object System.Drawing.Point(20,180)
$lblVcInstaller.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblVcInstaller)

# ============================================================
# SECTION 20 - TOP INPUT CONTROLS
# ============================================================

$txtManagerIP = New-Object System.Windows.Forms.TextBox
$txtManagerIP.Location = New-Object System.Drawing.Point(160,20)
$txtManagerIP.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($txtManagerIP)

$txtAgentName = New-Object System.Windows.Forms.TextBox
$txtAgentName.Location = New-Object System.Drawing.Point(160,60)
$txtAgentName.Size = New-Object System.Drawing.Size(200,20)
$txtAgentName.Text = $env:COMPUTERNAME
$form.Controls.Add($txtAgentName)

$comboInstaller = New-Object System.Windows.Forms.ComboBox
$comboInstaller.Location = New-Object System.Drawing.Point(160,100)
$comboInstaller.Size = New-Object System.Drawing.Size(400,20)
$comboInstaller.DropDownStyle = "DropDownList"

$Installers = Get-ChildItem `
    -Path "$env:USERPROFILE\Downloads" `
    -Filter "wazuh-agent-*.msi" `
    -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

foreach ($item in $Installers) {
    $comboInstaller.Items.Add($item.Name) | Out-Null
}

if ($comboInstaller.Items.Count -gt 0) {
    $comboInstaller.SelectedIndex = 0
}

$form.Controls.Add($comboInstaller)

$comboYaraZip = New-Object System.Windows.Forms.ComboBox
$comboYaraZip.Location = New-Object System.Drawing.Point(160,140)
$comboYaraZip.Size = New-Object System.Drawing.Size(400,20)
$comboYaraZip.DropDownStyle = "DropDownList"

$YaraZips = Get-ChildItem `
    -Path "$env:USERPROFILE\Downloads" `
    -Filter "*yara*win64*.zip" `
    -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

foreach ($item in $YaraZips) {
    $comboYaraZip.Items.Add($item.Name) | Out-Null
}

if ($comboYaraZip.Items.Count -gt 0) {
    $comboYaraZip.SelectedIndex = 0
}

$form.Controls.Add($comboYaraZip)

$comboVcInstaller = New-Object System.Windows.Forms.ComboBox
$comboVcInstaller.Location = New-Object System.Drawing.Point(160,180)
$comboVcInstaller.Size = New-Object System.Drawing.Size(400,20)
$comboVcInstaller.DropDownStyle = "DropDownList"

$VcInstallers = Get-ChildItem `
    -Path "$env:USERPROFILE\Downloads" `
    -Filter "vc_redist*.exe" `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "x64" } |
    Sort-Object LastWriteTime -Descending

foreach ($item in $VcInstallers) {
    $comboVcInstaller.Items.Add($item.Name) | Out-Null
}

if ($comboVcInstaller.Items.Count -gt 0) {
    $comboVcInstaller.SelectedIndex = 0
}

$form.Controls.Add($comboVcInstaller)

# ============================================================
# SECTION 21 - WAZUH STATUS INDICATOR
# ============================================================

$lblInstallStatus = New-Object System.Windows.Forms.Label
$lblInstallStatus.Text = "Wazuh Status"
$lblInstallStatus.Location = New-Object System.Drawing.Point(20,220)
$lblInstallStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblInstallStatus)

$lblInstallStatusValue = New-Object System.Windows.Forms.Label
$lblInstallStatusValue.Text = "Checking..."
$lblInstallStatusValue.Location = New-Object System.Drawing.Point(160,220)
$lblInstallStatusValue.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblInstallStatusValue)

$lblManagerStatus = New-Object System.Windows.Forms.Label
$lblManagerStatus.Text = "Current Manager"
$lblManagerStatus.Location = New-Object System.Drawing.Point(350,220)
$lblManagerStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblManagerStatus)

$lblManagerStatusValue = New-Object System.Windows.Forms.Label
$lblManagerStatusValue.Text = "Checking..."
$lblManagerStatusValue.Location = New-Object System.Drawing.Point(470,220)
$lblManagerStatusValue.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($lblManagerStatusValue)

$lblAgentStatus = New-Object System.Windows.Forms.Label
$lblAgentStatus.Text = "Current Agent"
$lblAgentStatus.Location = New-Object System.Drawing.Point(20,245)
$lblAgentStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblAgentStatus)

$lblAgentStatusValue = New-Object System.Windows.Forms.Label
$lblAgentStatusValue.Text = "Checking..."
$lblAgentStatusValue.Location = New-Object System.Drawing.Point(160,245)
$lblAgentStatusValue.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblAgentStatusValue)

$lblRegistrationStatus = New-Object System.Windows.Forms.Label
$lblRegistrationStatus.Text = "Agent Registration"
$lblRegistrationStatus.Location = New-Object System.Drawing.Point(350,245)
$lblRegistrationStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblRegistrationStatus)

$lblRegistrationStatusValue = New-Object System.Windows.Forms.Label
$lblRegistrationStatusValue.Text = "Checking..."
$lblRegistrationStatusValue.Location = New-Object System.Drawing.Point(470,245)
$lblRegistrationStatusValue.Size = New-Object System.Drawing.Size(220,20)
$form.Controls.Add($lblRegistrationStatusValue)

# ============================================================
# SECTION 22 - MAIN ACTION BUTTONS
# ============================================================

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install Wazuh Agent"
$btnInstall.Location = New-Object System.Drawing.Point(20,285)
$btnInstall.Size = New-Object System.Drawing.Size(180,40)
$btnInstall.Add_Click({ Install-WazuhAgent })
$form.Controls.Add($btnInstall)

$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Text = "Uninstall Wazuh Agent"
$btnUninstall.Location = New-Object System.Drawing.Point(220,285)
$btnUninstall.Size = New-Object System.Drawing.Size(180,40)
$btnUninstall.Add_Click({ Uninstall-WazuhAgent })
$form.Controls.Add($btnUninstall)

$btnFIM = New-Object System.Windows.Forms.Button
$btnFIM.Text = "Add Default FIM"
$btnFIM.Location = New-Object System.Drawing.Point(420,285)
$btnFIM.Size = New-Object System.Drawing.Size(180,40)
$btnFIM.Add_Click({ Add-FIMMonitoring })
$form.Controls.Add($btnFIM)

$btnVcStatus = New-Object System.Windows.Forms.Button
$btnVcStatus.Text = "VC++ Status"
$btnVcStatus.Location = New-Object System.Drawing.Point(620,285)
$btnVcStatus.Size = New-Object System.Drawing.Size(160,40)
$btnVcStatus.Add_Click({ Show-VcRuntimeStatus })
$form.Controls.Add($btnVcStatus)

$btnSysmon = New-Object System.Windows.Forms.Button
$btnSysmon.Text = "Install Sysmon"
$btnSysmon.Location = New-Object System.Drawing.Point(20,345)
$btnSysmon.Size = New-Object System.Drawing.Size(180,40)
$btnSysmon.Add_Click({ Install-Sysmon })
$form.Controls.Add($btnSysmon)

$btnRestartWazuh = New-Object System.Windows.Forms.Button
$btnRestartWazuh.Text = "Restart Wazuh"
$btnRestartWazuh.Location = New-Object System.Drawing.Point(220,345)
$btnRestartWazuh.Size = New-Object System.Drawing.Size(180,40)
$btnRestartWazuh.Add_Click({ Restart-WazuhService })
$form.Controls.Add($btnRestartWazuh)

$btnRestart = New-Object System.Windows.Forms.Button
$btnRestart.Text = "Restart Computer"
$btnRestart.Location = New-Object System.Drawing.Point(420,345)
$btnRestart.Size = New-Object System.Drawing.Size(180,40)
$btnRestart.Add_Click({
    $ConfirmRestart = [System.Windows.Forms.MessageBox]::Show(
        $form,
        "Restart this computer now?",
        "Confirm Restart",
        "YesNo",
        "Warning"
    )

    if ($ConfirmRestart -eq "Yes") {
        Write-OutputBox "Restarting computer..."
        Restart-Computer -Force
    }
})
$form.Controls.Add($btnRestart)

$btnOpenOssec = New-Object System.Windows.Forms.Button
$btnOpenOssec.Text = "Open ossec.conf"
$btnOpenOssec.Location = New-Object System.Drawing.Point(620,345)
$btnOpenOssec.Size = New-Object System.Drawing.Size(160,40)
$btnOpenOssec.Add_Click({ Open-OssecConf })
$form.Controls.Add($btnOpenOssec)

$btnCheckRuntime = New-Object System.Windows.Forms.Button
$btnCheckRuntime.Text = "Check VC++ Runtime"
$btnCheckRuntime.Location = New-Object System.Drawing.Point(20,405)
$btnCheckRuntime.Size = New-Object System.Drawing.Size(180,40)
$btnCheckRuntime.Add_Click({ Check-VcRuntimeFromGUI })
$form.Controls.Add($btnCheckRuntime)

$btnYara = New-Object System.Windows.Forms.Button
$btnYara.Text = "Install YARA"
$btnYara.Location = New-Object System.Drawing.Point(220,405)
$btnYara.Size = New-Object System.Drawing.Size(180,40)
$btnYara.Add_Click({ Install-Yara })
$form.Controls.Add($btnYara)

$btnTestYara = New-Object System.Windows.Forms.Button
$btnTestYara.Text = "Run YARA Test"
$btnTestYara.Location = New-Object System.Drawing.Point(420,405)
$btnTestYara.Size = New-Object System.Drawing.Size(180,40)
$btnTestYara.Add_Click({ Test-YaraInstall })
$form.Controls.Add($btnTestYara)

$btnDownloadYaraRules = New-Object System.Windows.Forms.Button
$btnDownloadYaraRules.Text = "Download YARA Rules"
$btnDownloadYaraRules.Location = New-Object System.Drawing.Point(620,405)
$btnDownloadYaraRules.Size = New-Object System.Drawing.Size(160,40)
$btnDownloadYaraRules.Add_Click({ Download-YaraRules })
$form.Controls.Add($btnDownloadYaraRules)

$btnDownloadLabSim = New-Object System.Windows.Forms.Button
$btnDownloadLabSim.Text = "Download Lab Simulator"
$btnDownloadLabSim.Location = New-Object System.Drawing.Point(20,465)
$btnDownloadLabSim.Size = New-Object System.Drawing.Size(180,40)
$btnDownloadLabSim.Add_Click({ Download-LabSimulator })
$form.Controls.Add($btnDownloadLabSim)

$btnDownloadADLab = New-Object System.Windows.Forms.Button
$btnDownloadADLab.Text = "Download AD Lab GUI"
$btnDownloadADLab.Location = New-Object System.Drawing.Point(220,465)
$btnDownloadADLab.Size = New-Object System.Drawing.Size(180,40)
$btnDownloadADLab.Add_Click({ Download-ADLabGUI })
$form.Controls.Add($btnDownloadADLab)

$btnOpenLabSim = New-Object System.Windows.Forms.Button
$btnOpenLabSim.Text = "Open Lab Simulator"
$btnOpenLabSim.Location = New-Object System.Drawing.Point(420,465)
$btnOpenLabSim.Size = New-Object System.Drawing.Size(180,40)
$btnOpenLabSim.Add_Click({ Launch-LabSimulator })
$form.Controls.Add($btnOpenLabSim)

$btnOpenADLab = New-Object System.Windows.Forms.Button
$btnOpenADLab.Text = "Open AD Lab GUI"
$btnOpenADLab.Location = New-Object System.Drawing.Point(620,465)
$btnOpenADLab.Size = New-Object System.Drawing.Size(160,40)
$btnOpenADLab.Add_Click({ Launch-ADLabGUI })
$form.Controls.Add($btnOpenADLab)

$btnDownloadDlp = New-Object System.Windows.Forms.Button
$btnDownloadDlp.Text = "Download DLP GUI"
$btnDownloadDlp.Location = New-Object System.Drawing.Point(20,525)
$btnDownloadDlp.Size = New-Object System.Drawing.Size(180,40)
$btnDownloadDlp.Add_Click({ Download-DlpLabGUI })
$form.Controls.Add($btnDownloadDlp)

$btnOpenDlp = New-Object System.Windows.Forms.Button
$btnOpenDlp.Text = "Open DLP GUI"
$btnOpenDlp.Location = New-Object System.Drawing.Point(220,525)
$btnOpenDlp.Size = New-Object System.Drawing.Size(180,40)
$btnOpenDlp.Add_Click({ Launch-DlpLabGUI })
$form.Controls.Add($btnOpenDlp)

$btnDownloadFsrmDlp = New-Object System.Windows.Forms.Button
$btnDownloadFsrmDlp.Text = "Download FSRM DLP"
$btnDownloadFsrmDlp.Location = New-Object System.Drawing.Point(420,525)
$btnDownloadFsrmDlp.Size = New-Object System.Drawing.Size(180,40)
$btnDownloadFsrmDlp.Add_Click({ Download-FsrmDlpLab })
$form.Controls.Add($btnDownloadFsrmDlp)

$btnRunFsrmDlp = New-Object System.Windows.Forms.Button
$btnRunFsrmDlp.Text = "Run FSRM DLP"
$btnRunFsrmDlp.Location = New-Object System.Drawing.Point(620,525)
$btnRunFsrmDlp.Size = New-Object System.Drawing.Size(160,40)
$btnRunFsrmDlp.Add_Click({ Launch-FsrmDlpLab })
$form.Controls.Add($btnRunFsrmDlp)

$btnFsrmClassifyNow = New-Object System.Windows.Forms.Button
$btnFsrmClassifyNow.Text = "FSRM Classify Now"
$btnFsrmClassifyNow.Location = New-Object System.Drawing.Point(20,585)
$btnFsrmClassifyNow.Size = New-Object System.Drawing.Size(180,40)
$btnFsrmClassifyNow.Add_Click({ Run-FsrmClassificationNow })
$form.Controls.Add($btnFsrmClassifyNow)

$btnFsrmQuarantineNow = New-Object System.Windows.Forms.Button
$btnFsrmQuarantineNow.Text = "FSRM Quarantine Now"
$btnFsrmQuarantineNow.Location = New-Object System.Drawing.Point(220,585)
$btnFsrmQuarantineNow.Size = New-Object System.Drawing.Size(180,40)
$btnFsrmQuarantineNow.Add_Click({ Run-FsrmQuarantineNow })
$form.Controls.Add($btnFsrmQuarantineNow)


$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Location = New-Object System.Drawing.Point(620,585)
$btnExit.Size = New-Object System.Drawing.Size(160,40)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ============================================================
# SECTION 23 - FIM PATH MANAGER CONTROLS
# ============================================================

$lblFimPath = New-Object System.Windows.Forms.Label
$lblFimPath.Text = "FIM Folder Path"
$lblFimPath.Location = New-Object System.Drawing.Point(20,650)
$lblFimPath.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblFimPath)

$txtFimPath = New-Object System.Windows.Forms.TextBox
$txtFimPath.Location = New-Object System.Drawing.Point(160,650)
$txtFimPath.Size = New-Object System.Drawing.Size(320,20)
$form.Controls.Add($txtFimPath)

$btnBrowseFim = New-Object System.Windows.Forms.Button
$btnBrowseFim.Text = "Browse"
$btnBrowseFim.Location = New-Object System.Drawing.Point(500,645)
$btnBrowseFim.Size = New-Object System.Drawing.Size(90,30)
$btnBrowseFim.Add_Click({ Browse-FIMFolder })
$form.Controls.Add($btnBrowseFim)

$btnAddFimPath = New-Object System.Windows.Forms.Button
$btnAddFimPath.Text = "Add FIM Path"
$btnAddFimPath.Location = New-Object System.Drawing.Point(20,690)
$btnAddFimPath.Size = New-Object System.Drawing.Size(140,35)
$btnAddFimPath.Add_Click({ Add-FIMPathFromGUI })
$form.Controls.Add($btnAddFimPath)

$btnRefreshFim = New-Object System.Windows.Forms.Button
$btnRefreshFim.Text = "Refresh FIM Paths"
$btnRefreshFim.Location = New-Object System.Drawing.Point(180,690)
$btnRefreshFim.Size = New-Object System.Drawing.Size(150,35)
$btnRefreshFim.Add_Click({ Get-FIMPaths })
$form.Controls.Add($btnRefreshFim)

$lblFimList = New-Object System.Windows.Forms.Label
$lblFimList.Text = "Custom / Lab FIM Paths"
$lblFimList.Location = New-Object System.Drawing.Point(20,735)
$lblFimList.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblFimList)

$listFimPaths = New-Object System.Windows.Forms.ListBox
$listFimPaths.Location = New-Object System.Drawing.Point(20,760)
$listFimPaths.Size = New-Object System.Drawing.Size(570,80)
$form.Controls.Add($listFimPaths)

# ============================================================
# SECTION 24 - OUTPUT BOX
# ============================================================

$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Location = New-Object System.Drawing.Point(20,860)
$OutputBox.Size = New-Object System.Drawing.Size(660,140)
$OutputBox.Multiline = $true
$OutputBox.ScrollBars = "Vertical"
$OutputBox.ReadOnly = $true
$form.Controls.Add($OutputBox)

# ============================================================
# SECTION 25 - SHOW GUI
# ============================================================

$form.Topmost = $false
$form.Add_Shown({
    $form.Activate()
    Update-WazuhStatus
    Get-FIMPaths
})

[void]$form.ShowDialog()
