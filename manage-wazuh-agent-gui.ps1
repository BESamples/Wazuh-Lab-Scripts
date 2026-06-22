# ============================================================
# WAZUH AGENT MANAGER GUI
# VERSION 3.0 - TABBED MENU
# ============================================================
#
# MENU PAGE LOCATIONS
# ============================================================
# Tab 1 - Wazuh Agent
# Tab 2 - Sysmon / YARA
# Tab 3 - Lab Tools
# Tab 4 - FSRM DLP
# Tab 5 - FIM Paths
# Tab 6 - Attack Simulation
#
# ============================================================
# SECTION MAP
# ============================================================
# SECTION 1   - ADMIN CHECK
# SECTION 2   - HELPER FUNCTION: WRITE TO OUTPUT BOX
# SECTION 3   - CHECK / INSTALL MICROSOFT VC++ X64 RUNTIME FOR YARA
# SECTION 4   - INSTALL WAZUH AGENT
# SECTION 5   - UNINSTALL WAZUH AGENT
# SECTION 6   - ADD DEFAULT FIM MONITORING
# SECTION 7   - INSTALL SYSMON
# SECTION 8   - GET CUSTOM FIM PATHS
# SECTION 9   - ADD CUSTOM FIM PATH
# SECTION 10  - WAZUH SERVICE / OSSEC CONFIG TOOLS
# SECTION 11  - INSTALL YARA FROM LOCAL ZIP
# SECTION 12  - DOWNLOAD / LAUNCH LAB TOOLS
# SECTION 13  - FSRM DLP TOOLS
# SECTION 14  - RUN YARA TROUBLESHOOTER TEST
# SECTION 15  - DOWNLOAD YARA RULES
# SECTION 16  - BROWSE FOR FIM FOLDER
# SECTION 17  - UPDATE WAZUH STATUS DISPLAY
# SECTION 17A - ATTACK SIMULATION FUNCTIONS
# SECTION 18  - CREATE MAIN GUI WINDOW
# SECTION 19  - CREATE TAB MENU
# SECTION 20  - HELPER FUNCTION: CREATE TAB BUTTON
# SECTION 20A - WAZUH AGENT TAB
# SECTION 20B - SYSMON / YARA TAB
# SECTION 20C - LAB TOOLS TAB
# SECTION 20D - FSRM DLP TAB
# SECTION 20E - FIM PATHS TAB
# SECTION 20F - ATTACK SIMULATION TAB
# SECTION 21  - OUTPUT BOX
# SECTION 22  - EXIT BUTTON
# SECTION 23  - SHOW GUI
#
# ============================================================
# FEATURE MAP
# ============================================================
#
# WAZUH FEATURES
#   - Install Wazuh Agent ............ Section 4 / Tab 1
#   - Uninstall Wazuh Agent .......... Section 5 / Tab 1
#   - Restart Wazuh Service .......... Section 10 / Tab 1
#   - Open ossec.conf ................ Section 10 / Tab 1
#   - Agent Status Display ........... Section 17 / Tab 1
#
# SYSMON / YARA FEATURES
#   - Install Sysmon ................. Section 7 / Tab 2
#   - VC++ Runtime Validation ........ Section 3 / Tab 2
#   - Install YARA ................... Section 11 / Tab 2
#   - YARA Troubleshooter ............ Section 14 / Tab 2
#   - YARA Rule Downloader ........... Section 15 / Tab 2
#
# LAB TOOLS
#   - Download Lab Simulator ......... Section 12 / Tab 3
#   - Download AD Lab GUI ............ Section 12 / Tab 3
#   - Download DLP GUI ............... Section 12 / Tab 3
#   - Launch Lab Simulator ........... Section 12 / Tab 3
#   - Launch AD Lab GUI .............. Section 12 / Tab 3
#   - Launch DLP GUI ................. Section 12 / Tab 3
#
# FSRM DLP FEATURES
#   - Download FSRM DLP Lab .......... Section 13 / Tab 4
#   - Run FSRM DLP Setup ............. Section 13 / Tab 4
#   - Run Classification Now ......... Section 13 / Tab 4
#   - Run Quarantine Now ............. Section 13 / Tab 4
#   - Open FSRM Quarantine ........... Section 13 / Tab 4
#   - Open FSRM Reports .............. Section 13 / Tab 4
#
# FIM FEATURES
#   - Add Default FIM Paths .......... Section 6 / Tab 1
#   - View Current FIM Paths ......... Section 8 / Tab 5
#   - Add Custom FIM Paths ........... Section 9 / Tab 5
#   - Browse FIM Folder .............. Section 16 / Tab 5
#
# ============================================================
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

    Write-OutputBox "Downloading FSRM DLP lab script..."

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        Write-OutputBox "Download complete: $Destination"
    }
    catch {
        Write-OutputBox "FSRM DLP script download failed."
        Write-OutputBox $_.Exception.Message
    }
}

function Launch-FsrmDlpLab {
    if (-not (Test-IsWindowsServer2019)) {
        Write-OutputBox "BLOCKED: FSRM DLP lab can only run on Windows Server 2019."
        return
    }

    $ScriptPath = "$PSScriptRoot\setup-fsrm-dlp-lab.ps1"

    if (!(Test-Path $ScriptPath)) {
        Write-OutputBox "FSRM DLP script not found. Download it first."
        return
    }

    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`" -RunNow"
}

function Run-FsrmClassificationNow {
    if (-not (Test-IsWindowsServer2019)) { return }

    Import-Module FileServerResourceManager -ErrorAction SilentlyContinue
    Write-OutputBox "Starting FSRM classification..."
    Start-FsrmClassification -Confirm:$false
}

function Run-FsrmQuarantineNow {
    if (-not (Test-IsWindowsServer2019)) { return }

    Import-Module FileServerResourceManager -ErrorAction SilentlyContinue

    $Jobs = @(
        "Quarantine PII Files",
        "Quarantine PCI Files",
        "Quarantine Confidential Files"
    )

    foreach ($Job in $Jobs) {
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

function Open-FsrmQuarantine {
    $QuarantinePath = "C:\SensitiveData\Quarantine"

    if (!(Test-Path $QuarantinePath)) {
        Write-OutputBox "FSRM quarantine folder not found: $QuarantinePath"
        return
    }

    Start-Process explorer.exe $QuarantinePath
}
function Open-FsrmReports {
    $ReportPath = "C:\StorageReports"

    if (!(Test-Path $ReportPath)) {
        Write-OutputBox "FSRM report folder not found: $ReportPath"
        return
    }

    Write-OutputBox "Opening FSRM report folder..."
    Start-Process explorer.exe $ReportPath
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
        $lblWazuhStatus.Text = "Status: Installed / $($WazuhService.Status)"
        $lblWazuhStatus.ForeColor = [System.Drawing.Color]::Green
    }
    else {
        $lblWazuhStatus.Text = "Status: Not Installed"
        $lblWazuhStatus.ForeColor = [System.Drawing.Color]::Red
        $lblManager.Text = "Manager: N/A"
        $lblRegistration.Text = "Registration: Not Installed"
        $lblRegistration.ForeColor = [System.Drawing.Color]::Red
        return
    }

    if (Test-Path $OssecConf) {
        $conf = Get-Content $OssecConf -Raw
        $managerMatch = [regex]::Match($conf, '<address>(.*?)</address>')

        if ($managerMatch.Success) {
            $ManagerIP = $managerMatch.Groups[1].Value.Trim()
            $lblManager.Text = "Manager: $ManagerIP"

            if ([string]::IsNullOrWhiteSpace($txtManagerIP.Text)) {
                $txtManagerIP.Text = $ManagerIP
            }
        }
        else {
            $lblManager.Text = "Manager: Not found in ossec.conf"
        }
    }
    else {
        $lblManager.Text = "Manager: ossec.conf missing"
    }

    if (Test-Path $ClientKeys) {
        $keyLine = Get-Content $ClientKeys -ErrorAction SilentlyContinue | Select-Object -First 1

        if (-not [string]::IsNullOrWhiteSpace($keyLine)) {
            $lblRegistration.Text = "Registration: Registered / client.keys present"
            $lblRegistration.ForeColor = [System.Drawing.Color]::Green
        }
        else {
            $lblRegistration.Text = "Registration: Not Registered / client.keys empty"
            $lblRegistration.ForeColor = [System.Drawing.Color]::Red
        }
    }
    else {
        $lblRegistration.Text = "Registration: client.keys missing"
        $lblRegistration.ForeColor = [System.Drawing.Color]::Red
    }
}

# ============================================================
# SECTION 17A - ATTACK SIMULATION FUNCTIONS
# ============================================================

function Simulate-MalwareDrop {
    $Path = "C:\Wazuh-Test\fake-malware.txt"

    New-Item -ItemType Directory -Path "C:\Wazuh-Test" -Force | Out-Null
    Set-Content -Path $Path -Value "MALWARE_TEST_STRING" -Encoding ASCII

    Write-OutputBox "Created malware-like file for FIM testing:"
    Write-OutputBox $Path
    Write-OutputBox "Check Wazuh for FIM file created/modified alerts."
}

function Simulate-CredentialFile {
    $Path = "C:\Wazuh-Test\fake-passwords.txt"
    New-Item -ItemType Directory -Path "C:\Wazuh-Test" -Force | Out-Null
    Set-Content -Path $Path -Value "username=admin`npassword=Password123!"
    Write-OutputBox "Created fake credential file: $Path"
}

function Simulate-RansomNote {
    $Path = "C:\Wazuh-Test\README_RESTORE_FILES.txt"
    New-Item -ItemType Directory -Path "C:\Wazuh-Test" -Force | Out-Null
    Set-Content -Path $Path -Value "Your files have been encrypted. Lab simulation only."
    Write-OutputBox "Created fake ransomware note: $Path"
}

function Simulate-SuspiciousPowerShell {
    Write-OutputBox "Running safe suspicious PowerShell activity..."

    powershell.exe -ExecutionPolicy Bypass -Command "Get-Process | Out-File C:\Wazuh-Test\process-list.txt"

    Write-OutputBox "Suspicious PowerShell simulation complete."
}

function Simulate-SysmonProcessActivity {
    Write-OutputBox "Launching safe process activity..."

    Start-Process notepad.exe
    Start-Process cmd.exe -ArgumentList "/c whoami > C:\Wazuh-Test\whoami.txt"
    Start-Process cmd.exe -ArgumentList "/c ipconfig > C:\Wazuh-Test\ipconfig.txt"

    Write-OutputBox "Sysmon process simulation complete."
}

function Enable-ICMPPingLab {

    $Rule = Get-NetFirewallRule `
        -DisplayName "Allow ICMPv4 Ping Lab" `
        -ErrorAction SilentlyContinue

    if ($Rule) {
        Write-OutputBox "ICMP lab firewall rule already exists."
        return
    }

    New-NetFirewallRule `
        -DisplayName "Allow ICMPv4 Ping Lab" `
        -Protocol ICMPv4 `
        -IcmpType 8 `
        -Direction Inbound `
        -Action Allow

    Write-OutputBox "ICMPv4 Ping Lab rule created."
}

# ============================================================
# SECTION 18 - CREATE MAIN GUI WINDOW
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Wazuh Agent Manager GUI - Menu 3.0"
$form.Size = New-Object System.Drawing.Size(900,700)
$form.StartPosition = "CenterScreen"

# ============================================================
# SECTION 19 - CREATE TAB MENU
# ============================================================

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10,10)
$tabs.Size = New-Object System.Drawing.Size(860,480)
$form.Controls.Add($tabs)

$tabWazuh = New-Object System.Windows.Forms.TabPage
$tabWazuh.Text = "Wazuh Agent"
$tabs.TabPages.Add($tabWazuh)

$tabYara = New-Object System.Windows.Forms.TabPage
$tabYara.Text = "Sysmon / YARA"
$tabs.TabPages.Add($tabYara)

$tabLab = New-Object System.Windows.Forms.TabPage
$tabLab.Text = "Lab Tools"
$tabs.TabPages.Add($tabLab)

$tabFsrm = New-Object System.Windows.Forms.TabPage
$tabFsrm.Text = "FSRM DLP"
$tabs.TabPages.Add($tabFsrm)

$tabFim = New-Object System.Windows.Forms.TabPage
$tabFim.Text = "FIM Paths"
$tabs.TabPages.Add($tabFim)

$tabAttack = New-Object System.Windows.Forms.TabPage
$tabAttack.Text = "Attack Simulation"
$tabs.TabPages.Add($tabAttack)

# ============================================================
# SECTION 20 - HELPER FUNCTION: CREATE TAB BUTTON
# ============================================================

function New-TabButton {
    param(
        [System.Windows.Forms.Control]$Parent,
        [string]$Text,
        [int]$X,
        [int]$Y,
        [scriptblock]$Action
    )

    $Button = New-Object System.Windows.Forms.Button
    $Button.Text = $Text
    $Button.Location = New-Object System.Drawing.Point($X,$Y)
    $Button.Size = New-Object System.Drawing.Size(190,40)
    $Button.Add_Click($Action)
    $Parent.Controls.Add($Button)

    return $Button
}

# ============================================================
# SECTION 20A - WAZUH TAB
# ============================================================

# Manager IP
$lblManagerIP = New-Object System.Windows.Forms.Label
$lblManagerIP.Text = "Wazuh Manager IP"
$lblManagerIP.Location = New-Object System.Drawing.Point(20,20)
$lblManagerIP.Size = New-Object System.Drawing.Size(120,20)
$tabWazuh.Controls.Add($lblManagerIP)

$txtManagerIP = New-Object System.Windows.Forms.TextBox
$txtManagerIP.Location = New-Object System.Drawing.Point(150,20)
$txtManagerIP.Size = New-Object System.Drawing.Size(200,20)
$txtManagerIP.Text = "192.168.1.50"
$tabWazuh.Controls.Add($txtManagerIP)

# Agent Name
$lblAgentName = New-Object System.Windows.Forms.Label
$lblAgentName.Text = "Agent Name"
$lblAgentName.Location = New-Object System.Drawing.Point(20,55)
$tabWazuh.Controls.Add($lblAgentName)

# Wazuh Installer dropdown
$lblInstaller = New-Object System.Windows.Forms.Label
$lblInstaller.Text = "Wazuh Installer"
$lblInstaller.Location = New-Object System.Drawing.Point(20,90)
$lblInstaller.Size = New-Object System.Drawing.Size(120,20)
$tabWazuh.Controls.Add($lblInstaller)

$comboInstaller = New-Object System.Windows.Forms.ComboBox
$comboInstaller.Location = New-Object System.Drawing.Point(150,90)
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

$tabWazuh.Controls.Add($comboInstaller)

$txtAgentName = New-Object System.Windows.Forms.TextBox
$txtAgentName.Location = New-Object System.Drawing.Point(150,55)
$txtAgentName.Size = New-Object System.Drawing.Size(200,20)
$txtAgentName.Text = $env:COMPUTERNAME
$tabWazuh.Controls.Add($txtAgentName)

# Status Labels
$lblWazuhStatus = New-Object System.Windows.Forms.Label
$lblWazuhStatus.Text = "Status: Unknown"
$lblWazuhStatus.Location = New-Object System.Drawing.Point(20,130)
$lblWazuhStatus.Size = New-Object System.Drawing.Size(500,20)
$tabWazuh.Controls.Add($lblWazuhStatus)

$lblManager = New-Object System.Windows.Forms.Label
$lblManager.Text = "Manager: Unknown"
$lblManager.Location = New-Object System.Drawing.Point(20,155)
$lblManager.Size = New-Object System.Drawing.Size(500,20)
$tabWazuh.Controls.Add($lblManager)

$lblRegistration = New-Object System.Windows.Forms.Label
$lblRegistration.Text = "Registration: Unknown"
$lblRegistration.Location = New-Object System.Drawing.Point(20,180)
$lblRegistration.Size = New-Object System.Drawing.Size(500,20)
$tabWazuh.Controls.Add($lblRegistration)

#Buttons
New-TabButton $tabWazuh "Install Wazuh Agent" 20 230 { Install-WazuhAgent }

New-TabButton $tabWazuh "Uninstall Wazuh Agent" 230 230 { Uninstall-WazuhAgent }

New-TabButton $tabWazuh "Add Default FIM" 440 230 { Add-FIMMonitoring }

New-TabButton $tabWazuh "Restart Wazuh" 20 290 { Restart-WazuhService }

New-TabButton $tabWazuh "Restart Computer" 230 290 {
    Restart-Computer -Force
}

New-TabButton $tabWazuh "Open ossec.conf" 440 290 {
    Open-OssecConf
}

New-TabButton $tabWazuh "Refresh Status" 20 350 {
    Update-WazuhStatus
}

# ============================================================
# SECTION 20B - SYSMON / YARA TAB
# ============================================================

# YARA ZIP dropdown
$lblYaraZip = New-Object System.Windows.Forms.Label
$lblYaraZip.Text = "YARA ZIP"
$lblYaraZip.Location = New-Object System.Drawing.Point(20,20)
$lblYaraZip.Size = New-Object System.Drawing.Size(120,20)
$tabYara.Controls.Add($lblYaraZip)

$comboYaraZip = New-Object System.Windows.Forms.ComboBox
$comboYaraZip.Location = New-Object System.Drawing.Point(150,20)
$comboYaraZip.Size = New-Object System.Drawing.Size(420,20)
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

$tabYara.Controls.Add($comboYaraZip)

# VC++ Installer dropdown
$lblVcInstaller = New-Object System.Windows.Forms.Label
$lblVcInstaller.Text = "VC++ Installer"
$lblVcInstaller.Location = New-Object System.Drawing.Point(20,60)
$lblVcInstaller.Size = New-Object System.Drawing.Size(120,20)
$tabYara.Controls.Add($lblVcInstaller)

$comboVcInstaller = New-Object System.Windows.Forms.ComboBox
$comboVcInstaller.Location = New-Object System.Drawing.Point(150,60)
$comboVcInstaller.Size = New-Object System.Drawing.Size(420,20)
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

$tabYara.Controls.Add($comboVcInstaller)

# Buttons
New-TabButton $tabYara "Install Sysmon" 20 120 { Install-Sysmon }

New-TabButton $tabYara "VC++ Status" 230 120 { Show-VcRuntimeStatus }

New-TabButton $tabYara "Install / Check VC++" 440 120 { Check-VcRuntimeFromGUI }

New-TabButton $tabYara "Install YARA" 20 180 { Install-Yara }

New-TabButton $tabYara "Run YARA Test" 230 180 { Test-YaraInstall }

New-TabButton $tabYara "Download YARA Rules" 440 180 { Download-YaraRules }

# ============================================================
# SECTION 20C - LAB TOOLS TAB
# ============================================================

New-TabButton $tabLab "Download Lab Simulator" 20 20 {
    Download-LabSimulator
}

New-TabButton $tabLab "Download AD Lab GUI" 230 20 {
    Download-ADLabGUI
}

New-TabButton $tabLab "Download DLP GUI" 440 20 {
    Download-DlpLabGUI
}

New-TabButton $tabLab "Open Lab Simulator" 20 80 {
    Launch-LabSimulator
}

New-TabButton $tabLab "Open AD Lab GUI" 230 80 {
    Launch-ADLabGUI
}

New-TabButton $tabLab "Open DLP GUI" 440 80 {
    Launch-DlpLabGUI
}

New-TabButton $tabLab "Open Script Folder" 20 140 {
    Start-Process explorer.exe $PSScriptRoot
}

New-TabButton $tabLab "Open Downloads Folder" 230 140 {
    Start-Process explorer.exe "$env:USERPROFILE\Downloads"
}

# ============================================================
# SECTION 20D - FSRM DLP TAB
# Server 2019 only
# ============================================================

$lblFsrmInfo = New-Object System.Windows.Forms.Label
$lblFsrmInfo.Text = "FSRM DLP tools are for Windows Server 2019 only."
$lblFsrmInfo.Location = New-Object System.Drawing.Point(20,20)
$lblFsrmInfo.Size = New-Object System.Drawing.Size(500,20)
$tabFsrm.Controls.Add($lblFsrmInfo)

New-TabButton $tabFsrm "Download FSRM DLP" 20 70 {
    Download-FsrmDlpLab
}

New-TabButton $tabFsrm "Run FSRM DLP Setup" 230 70 {
    Launch-FsrmDlpLab
}

New-TabButton $tabFsrm "FSRM Classify Now" 20 130 {
    Run-FsrmClassificationNow
}

New-TabButton $tabFsrm "FSRM Quarantine Now" 230 130 {
    Run-FsrmQuarantineNow
}

New-TabButton $tabFsrm "Open FSRM Quarantine" 20 190 {
    Open-FsrmQuarantine
}

New-TabButton $tabFsrm "Open FSRM Reports" 230 190 {
    Open-FsrmReports
}

# ============================================================
# SECTION 20E - FIM PATHS TAB
# ============================================================

$lblFimInfo = New-Object System.Windows.Forms.Label
$lblFimInfo.Text = "Manage custom Wazuh FIM monitored folders."
$lblFimInfo.Location = New-Object System.Drawing.Point(20,20)
$lblFimInfo.Size = New-Object System.Drawing.Size(500,20)
$tabFim.Controls.Add($lblFimInfo)

$lblFimPath = New-Object System.Windows.Forms.Label
$lblFimPath.Text = "FIM Folder Path"
$lblFimPath.Location = New-Object System.Drawing.Point(20,60)
$lblFimPath.Size = New-Object System.Drawing.Size(120,20)
$tabFim.Controls.Add($lblFimPath)

$txtFimPath = New-Object System.Windows.Forms.TextBox
$txtFimPath.Location = New-Object System.Drawing.Point(150,60)
$txtFimPath.Size = New-Object System.Drawing.Size(420,20)
$tabFim.Controls.Add($txtFimPath)

New-TabButton $tabFim "Browse Folder" 20 110 {
    Browse-FIMFolder
}

New-TabButton $tabFim "Add FIM Path" 230 110 {
    Add-FIMPathFromGUI
}

New-TabButton $tabFim "Refresh FIM Paths" 440 110 {
    Get-FIMPaths
}

$lblFimList = New-Object System.Windows.Forms.Label
$lblFimList.Text = "Current Custom / Lab FIM Paths"
$lblFimList.Location = New-Object System.Drawing.Point(20,180)
$lblFimList.Size = New-Object System.Drawing.Size(250,20)
$tabFim.Controls.Add($lblFimList)

$listFimPaths = New-Object System.Windows.Forms.ListBox
$listFimPaths.Location = New-Object System.Drawing.Point(20,210)
$listFimPaths.Size = New-Object System.Drawing.Size(760,160)
$tabFim.Controls.Add($listFimPaths)

# ============================================================
# SECTION 20F - ATTACK SIMULATION TAB
# ============================================================

$lblAttackInfo = New-Object System.Windows.Forms.Label
$lblAttackInfo.Text = "Safe attack simulations for Wazuh lab alerts."
$lblAttackInfo.Location = New-Object System.Drawing.Point(20,20)
$lblAttackInfo.Size = New-Object System.Drawing.Size(500,20)
$tabAttack.Controls.Add($lblAttackInfo)

New-TabButton $tabAttack "Fake Malware Drop" 20 70 {
    Simulate-MalwareDrop
}

New-TabButton $tabAttack "Fake Credential File" 230 70 {
    Simulate-CredentialFile
}

New-TabButton $tabAttack "Fake Ransom Note" 440 70 {
    Simulate-RansomNote
}

New-TabButton $tabAttack "Suspicious PowerShell" 20 130 {
    Simulate-SuspiciousPowerShell
}

New-TabButton $tabAttack "Sysmon Process Activity" 230 130 {
    Simulate-SysmonProcessActivity
}

New-TabButton $tabAttack "Enable Ping Rule" 440 130 {
    Enable-ICMPPingLab
}
# ============================================================
# SECTION 21 - OUTPUT BOX
# ============================================================

$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Location = New-Object System.Drawing.Point(10,505)
$OutputBox.Size = New-Object System.Drawing.Size(860,110)
$OutputBox.Multiline = $true
$OutputBox.ScrollBars = "Vertical"
$OutputBox.ReadOnly = $true
$form.Controls.Add($OutputBox)

# ============================================================
# SECTION 22 - EXIT BUTTON
# ============================================================

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Location = New-Object System.Drawing.Point(730,625)
$btnExit.Size = New-Object System.Drawing.Size(140,35)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ============================================================
# SECTION 23 - SHOW GUI
# ============================================================

$form.Topmost = $false
$form.Add_Shown({
    $form.Activate()
    Write-OutputBox "Menu 3.0 loaded."
})

[void]$form.ShowDialog()




