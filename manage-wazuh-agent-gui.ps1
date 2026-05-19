# ============================================================
# Wazuh Agent Manager GUI
# Version 1.6
# Run as Administrator
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
# SECTION 3 - CHECK MICROSOFT VC++ RUNTIME FOR YARA
# ============================================================

function Test-VcRuntime {

    $RuntimePaths = @(
        "C:\Windows\System32\VCRUNTIME140.dll",
        "C:\Windows\SysWOW64\VCRUNTIME140.dll"
    )

    foreach ($Path in $RuntimePaths) {
        if (Test-Path $Path) {
            return $true
        }
    }

    return $false
}

function Check-VcRuntimeFromGUI {

    if (Test-VcRuntime) {
        Write-OutputBox "PASS: Microsoft Visual C++ Runtime found."
        [System.Windows.Forms.MessageBox]::Show(
            "Microsoft Visual C++ Runtime found. YARA should be able to run.",
            "Runtime Found",
            "OK",
            "Information"
        )
    }
    else {
        Write-OutputBox "FAIL: Microsoft Visual C++ Runtime is missing."
        Write-OutputBox "YARA needs VCRUNTIME140.dll to run."
        Write-OutputBox "Download/install VC++ Redistributable 2015-2022 x64:"
        Write-OutputBox "https://aka.ms/vs/17/release/vc_redist.x64.exe"

        [System.Windows.Forms.MessageBox]::Show(
            "Microsoft Visual C++ Runtime is missing.`r`n`r`nInstall VC++ Redistributable 2015-2022 x64 first:`r`nhttps://aka.ms/vs/17/release/vc_redist.x64.exe",
            "Missing Runtime",
            "OK",
            "Warning"
        )
    }
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
# SECTION 10 - RESTART WAZUH SERVICE
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

# ============================================================
# SECTION 11 - INSTALL YARA FROM LOCAL ZIP
# ============================================================

function Install-Yara {

    $YaraFolder = "C:\Program Files (x86)\ossec-agent\active-response\bin\yara"
    $YaraRulesFolder = "$YaraFolder\rules"
    $YaraZipName = $comboYaraZip.SelectedItem

    # ------------------------------------------------------------
    # Check Microsoft VC++ Runtime
    # ------------------------------------------------------------

    if (-not (Test-VcRuntime)) {

        Write-OutputBox "ERROR: Microsoft Visual C++ Runtime is missing."
        Write-OutputBox "Install VC++ Redistributable 2015-2022 x64 first:"
        Write-OutputBox "https://aka.ms/vs/17/release/vc_redist.x64.exe"

        [System.Windows.Forms.MessageBox]::Show(
            "Microsoft Visual C++ Runtime is missing.`r`n`r`nInstall VC++ Redistributable 2015-2022 x64 first:`r`nhttps://aka.ms/vs/17/release/vc_redist.x64.exe",
            "Missing Runtime",
            "OK",
            "Warning"
        )

        return
    }

    # ------------------------------------------------------------
    # Check if YARA ZIP selected
    # ------------------------------------------------------------

    if (-not $YaraZipName) {

        Write-OutputBox "No YARA ZIP selected."
        Write-OutputBox "Download YARA Windows ZIP first from:"
        Write-OutputBox "https://github.com/VirusTotal/yara/releases"

        [System.Windows.Forms.MessageBox]::Show(
            "Download a YARA Windows ZIP first.`r`n`r`nExample:`r`nyara-v4.x.x-win64.zip`r`n`r`nDownload from:`r`nhttps://github.com/VirusTotal/yara/releases",
            "YARA ZIP Missing",
            "OK",
            "Warning"
        )

        return
    }

    # ------------------------------------------------------------
    # Continue YARA install
    # ------------------------------------------------------------

    $YaraZip = Join-Path "$env:USERPROFILE\Downloads" $YaraZipName

    if (!(Test-Path $YaraZip)) {

        Write-OutputBox "ERROR: YARA ZIP not found: $YaraZip"

        [System.Windows.Forms.MessageBox]::Show(
            "Selected YARA ZIP was not found in Downloads.",
            "ZIP Missing",
            "OK",
            "Error"
        )

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

        [System.Windows.Forms.MessageBox]::Show(
            "YARA installed successfully.",
            "Install Complete",
            "OK",
            "Information"
        )
    }
    else {

        Write-OutputBox "WARNING: yara64.exe was not found after extraction."

        [System.Windows.Forms.MessageBox]::Show(
            "YARA extraction completed, but yara64.exe was not found.",
            "Install Warning",
            "OK",
            "Warning"
        )
    }
}
# ============================================================
# SECTION 12 - RUN YARA TROUBLESHOOTER TEST
# ============================================================

function Test-YaraInstall {

    $YaraFolder = "C:\Program Files (x86)\ossec-agent\active-response\bin\yara"
    $RulesFolder = "$YaraFolder\rules"
    $YaraExe = "$YaraFolder\yara64.exe"
    $TestFolder = "C:\Wazuh-Test"
    $TestFile = "$TestFolder\evil.txt"
    $AlwaysRule = "$RulesFolder\always-match.yar"
    $TestRule = "$RulesFolder\test-malware.yar"

    Write-OutputBox "=== YARA Wazuh Troubleshooter ==="

    if (-not (Test-VcRuntime)) {
        Write-OutputBox "FAIL: Microsoft Visual C++ Runtime is missing."
        Write-OutputBox "Install VC++ Redistributable 2015-2022 x64 first:"
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

    if (!(Test-Path $YaraExe)) {
        Write-OutputBox "FAIL: yara64.exe missing: $YaraExe"
        return
    }

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

    if ($AlwaysResult -match "Always_Match") {
        Write-OutputBox "PASS: Always_Match rule worked."
    }
    else {
        Write-OutputBox "FAIL: Always_Match did not return a match."
    }

    Write-OutputBox "Testing malware string rule..."
    $TestResult = & $YaraExe $TestRule $TestFile

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
# SECTION 13 - BROWSE FOR FIM FOLDER
# ============================================================

function Browse-FIMFolder {

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select folder to monitor with Wazuh FIM"

    if ($folderBrowser.ShowDialog() -eq "OK") {
        $txtFimPath.Text = $folderBrowser.SelectedPath
    }
}

# ============================================================
# SECTION 14 - UPDATE WAZUH STATUS DISPLAY
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
# SECTION 15 - CREATE MAIN GUI WINDOW
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Wazuh Agent Manager GUI"
$form.Size = New-Object System.Drawing.Size(820,850)
$form.StartPosition = "CenterScreen"

# ============================================================
# SECTION 16 - TOP INPUT LABELS
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

# ============================================================
# SECTION 17 - TOP INPUT CONTROLS
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

# ============================================================
# SECTION 18 - WAZUH STATUS INDICATOR
# ============================================================

$lblInstallStatus = New-Object System.Windows.Forms.Label
$lblInstallStatus.Text = "Wazuh Status"
$lblInstallStatus.Location = New-Object System.Drawing.Point(20,180)
$lblInstallStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblInstallStatus)

$lblInstallStatusValue = New-Object System.Windows.Forms.Label
$lblInstallStatusValue.Text = "Checking..."
$lblInstallStatusValue.Location = New-Object System.Drawing.Point(160,180)
$lblInstallStatusValue.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblInstallStatusValue)

$lblManagerStatus = New-Object System.Windows.Forms.Label
$lblManagerStatus.Text = "Current Manager"
$lblManagerStatus.Location = New-Object System.Drawing.Point(350,180)
$lblManagerStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblManagerStatus)

$lblManagerStatusValue = New-Object System.Windows.Forms.Label
$lblManagerStatusValue.Text = "Checking..."
$lblManagerStatusValue.Location = New-Object System.Drawing.Point(470,180)
$lblManagerStatusValue.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($lblManagerStatusValue)

$lblAgentStatus = New-Object System.Windows.Forms.Label
$lblAgentStatus.Text = "Current Agent"
$lblAgentStatus.Location = New-Object System.Drawing.Point(20,205)
$lblAgentStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblAgentStatus)

$lblAgentStatusValue = New-Object System.Windows.Forms.Label
$lblAgentStatusValue.Text = "Checking..."
$lblAgentStatusValue.Location = New-Object System.Drawing.Point(160,205)
$lblAgentStatusValue.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblAgentStatusValue)

$lblRegistrationStatus = New-Object System.Windows.Forms.Label
$lblRegistrationStatus.Text = "Agent Registration"
$lblRegistrationStatus.Location = New-Object System.Drawing.Point(350,205)
$lblRegistrationStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblRegistrationStatus)

$lblRegistrationStatusValue = New-Object System.Windows.Forms.Label
$lblRegistrationStatusValue.Text = "Checking..."
$lblRegistrationStatusValue.Location = New-Object System.Drawing.Point(470,205)
$lblRegistrationStatusValue.Size = New-Object System.Drawing.Size(220,20)
$form.Controls.Add($lblRegistrationStatusValue)

# ============================================================
# SECTION 19 - MAIN ACTION BUTTONS
# ============================================================

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install Wazuh Agent"
$btnInstall.Location = New-Object System.Drawing.Point(20,245)
$btnInstall.Size = New-Object System.Drawing.Size(180,40)
$btnInstall.Add_Click({ Install-WazuhAgent })
$form.Controls.Add($btnInstall)

$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Text = "Uninstall Wazuh Agent"
$btnUninstall.Location = New-Object System.Drawing.Point(220,245)
$btnUninstall.Size = New-Object System.Drawing.Size(180,40)
$btnUninstall.Add_Click({ Uninstall-WazuhAgent })
$form.Controls.Add($btnUninstall)

$btnFIM = New-Object System.Windows.Forms.Button
$btnFIM.Text = "Add Default FIM"
$btnFIM.Location = New-Object System.Drawing.Point(420,245)
$btnFIM.Size = New-Object System.Drawing.Size(180,40)
$btnFIM.Add_Click({ Add-FIMMonitoring })
$form.Controls.Add($btnFIM)

$btnSysmon = New-Object System.Windows.Forms.Button
$btnSysmon.Text = "Install Sysmon"
$btnSysmon.Location = New-Object System.Drawing.Point(20,305)
$btnSysmon.Size = New-Object System.Drawing.Size(180,40)
$btnSysmon.Add_Click({ Install-Sysmon })
$form.Controls.Add($btnSysmon)

$btnRestartWazuh = New-Object System.Windows.Forms.Button
$btnRestartWazuh.Text = "Restart Wazuh"
$btnRestartWazuh.Location = New-Object System.Drawing.Point(220,305)
$btnRestartWazuh.Size = New-Object System.Drawing.Size(180,40)
$btnRestartWazuh.Add_Click({ Restart-WazuhService })
$form.Controls.Add($btnRestartWazuh)

$btnRestart = New-Object System.Windows.Forms.Button
$btnRestart.Text = "Restart Computer"
$btnRestart.Location = New-Object System.Drawing.Point(420,305)
$btnRestart.Size = New-Object System.Drawing.Size(180,40)

$btnRestart.Add_Click({

    $ConfirmRestart = [System.Windows.Forms.MessageBox]::Show(
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

$btnCheckRuntime = New-Object System.Windows.Forms.Button
$btnCheckRuntime.Text = "Check VC++ Runtime"
$btnCheckRuntime.Location = New-Object System.Drawing.Point(20,365)
$btnCheckRuntime.Size = New-Object System.Drawing.Size(180,40)
$btnCheckRuntime.Add_Click({ Check-VcRuntimeFromGUI })
$form.Controls.Add($btnCheckRuntime)

$btnYara = New-Object System.Windows.Forms.Button
$btnYara.Text = "Install YARA"
$btnYara.Location = New-Object System.Drawing.Point(220,365)
$btnYara.Size = New-Object System.Drawing.Size(180,40)
$btnYara.Add_Click({ Install-Yara })
$form.Controls.Add($btnYara)

$btnTestYara = New-Object System.Windows.Forms.Button
$btnTestYara.Text = "Run YARA Test"
$btnTestYara.Location = New-Object System.Drawing.Point(420,365)
$btnTestYara.Size = New-Object System.Drawing.Size(180,40)
$btnTestYara.Add_Click({ Test-YaraInstall })
$form.Controls.Add($btnTestYara)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Location = New-Object System.Drawing.Point(650,305)
$btnExit.Size = New-Object System.Drawing.Size(90,40)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ============================================================
# SECTION 20 - FIM PATH MANAGER CONTROLS
# ============================================================

$lblFimPath = New-Object System.Windows.Forms.Label
$lblFimPath.Text = "FIM Folder Path"
$lblFimPath.Location = New-Object System.Drawing.Point(20,430)
$lblFimPath.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblFimPath)

$txtFimPath = New-Object System.Windows.Forms.TextBox
$txtFimPath.Location = New-Object System.Drawing.Point(160,430)
$txtFimPath.Size = New-Object System.Drawing.Size(320,20)
$form.Controls.Add($txtFimPath)

$btnBrowseFim = New-Object System.Windows.Forms.Button
$btnBrowseFim.Text = "Browse"
$btnBrowseFim.Location = New-Object System.Drawing.Point(500,425)
$btnBrowseFim.Size = New-Object System.Drawing.Size(90,30)
$btnBrowseFim.Add_Click({ Browse-FIMFolder })
$form.Controls.Add($btnBrowseFim)

$btnAddFimPath = New-Object System.Windows.Forms.Button
$btnAddFimPath.Text = "Add FIM Path"
$btnAddFimPath.Location = New-Object System.Drawing.Point(20,470)
$btnAddFimPath.Size = New-Object System.Drawing.Size(140,35)
$btnAddFimPath.Add_Click({ Add-FIMPathFromGUI })
$form.Controls.Add($btnAddFimPath)

$btnRefreshFim = New-Object System.Windows.Forms.Button
$btnRefreshFim.Text = "Refresh FIM Paths"
$btnRefreshFim.Location = New-Object System.Drawing.Point(180,470)
$btnRefreshFim.Size = New-Object System.Drawing.Size(150,35)
$btnRefreshFim.Add_Click({ Get-FIMPaths })
$form.Controls.Add($btnRefreshFim)

$lblFimList = New-Object System.Windows.Forms.Label
$lblFimList.Text = "Custom / Lab FIM Paths"
$lblFimList.Location = New-Object System.Drawing.Point(20,515)
$lblFimList.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblFimList)

$listFimPaths = New-Object System.Windows.Forms.ListBox
$listFimPaths.Location = New-Object System.Drawing.Point(20,540)
$listFimPaths.Size = New-Object System.Drawing.Size(570,80)
$form.Controls.Add($listFimPaths)

# ============================================================
# SECTION 21 - OUTPUT BOX
# ============================================================

$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Location = New-Object System.Drawing.Point(20,640)
$OutputBox.Size = New-Object System.Drawing.Size(660,150)
$OutputBox.Multiline = $true
$OutputBox.ScrollBars = "Vertical"
$OutputBox.ReadOnly = $true
$form.Controls.Add($OutputBox)

# ============================================================
# SECTION 22 - SHOW GUI
# ============================================================

$form.Topmost = $true
$form.Add_Shown({
    $form.Activate()
    Update-WazuhStatus
    Get-FIMPaths
})

[void]$form.ShowDialog()
