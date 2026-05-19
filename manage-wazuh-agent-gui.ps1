# ============================================================
# Wazuh Agent Manager GUI
# Version 1.4
# Run as Administrator
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# ADMIN CHECK
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
# FUNCTIONS
# ============================================================

function Write-OutputBox {
    param(
        [string]$Message
    )

    if ($OutputBox) {
        $OutputBox.AppendText("$Message`r`n")
    }
}

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

        # Hide default Wazuh/Windows system FIM paths from the GUI list.
        # This keeps the list focused on lab/custom paths like C:\Users or C:\Wazuh-Test.
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

function Install-Yara {

    $YaraFolder = "C:\Program Files (x86)\ossec-agent\active-response\bin\yara"
    $YaraRulesFolder = "$YaraFolder\rules"
    $YaraZip = "$YaraFolder\yara.zip"

    Write-OutputBox "Creating YARA folders..."

    New-Item -ItemType Directory -Force -Path $YaraFolder | Out-Null
    New-Item -ItemType Directory -Force -Path $YaraRulesFolder | Out-Null

    Write-OutputBox "Downloading YARA..."

    Invoke-WebRequest `
        -Uri "https://github.com/VirusTotal/yara/releases/download/v4.5.5/yara-4.5.5-2326-win64.zip" `
        -OutFile $YaraZip

    Write-OutputBox "Extracting YARA..."

    Expand-Archive `
        -Path $YaraZip `
        -DestinationPath $YaraFolder `
        -Force

    $YaraExe = "$YaraFolder\yara64.exe"

    if (Test-Path $YaraExe) {

        Write-OutputBox "YARA installed successfully."
        Write-OutputBox "YARA executable: $YaraExe"
    }
    else {

        Write-OutputBox "WARNING: yara64.exe was not found after extraction."
    }
}

function Browse-FIMFolder {

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select folder to monitor with Wazuh FIM"

    if ($folderBrowser.ShowDialog() -eq "OK") {
        $txtFimPath.Text = $folderBrowser.SelectedPath
    }
}

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

    # Default display name should be the textbox value or the Windows computer name.
    # The GUI does not display the key value from client.keys.
    $FallbackAgentName = $txtAgentName.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($FallbackAgentName)) {
        $FallbackAgentName = $env:COMPUTERNAME
    }

    $lblAgentStatusValue.Text = $FallbackAgentName

    # client.keys is used only as a registration indicator.
    # If it has a normal registered agent line, the second field is the agent name.
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
# GUI WINDOW
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Wazuh Agent Manager GUI"
$form.Size = New-Object System.Drawing.Size(820,760)
$form.StartPosition = "CenterScreen"

# ============================================================
# LABELS
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
$lblInstaller.Text = "Installer"
$lblInstaller.Location = New-Object System.Drawing.Point(20,100)
$lblInstaller.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblInstaller)

# ============================================================
# TEXT BOXES
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

# ============================================================
# INSTALLER DROPDOWN
# ============================================================

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

# ============================================================
# WAZUH STATUS INDICATOR
# ============================================================

$lblInstallStatus = New-Object System.Windows.Forms.Label
$lblInstallStatus.Text = "Wazuh Status"
$lblInstallStatus.Location = New-Object System.Drawing.Point(20,135)
$lblInstallStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblInstallStatus)

$lblInstallStatusValue = New-Object System.Windows.Forms.Label
$lblInstallStatusValue.Text = "Checking..."
$lblInstallStatusValue.Location = New-Object System.Drawing.Point(160,135)
$lblInstallStatusValue.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblInstallStatusValue)

$lblManagerStatus = New-Object System.Windows.Forms.Label
$lblManagerStatus.Text = "Current Manager"
$lblManagerStatus.Location = New-Object System.Drawing.Point(350,135)
$lblManagerStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblManagerStatus)

$lblManagerStatusValue = New-Object System.Windows.Forms.Label
$lblManagerStatusValue.Text = "Checking..."
$lblManagerStatusValue.Location = New-Object System.Drawing.Point(470,135)
$lblManagerStatusValue.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($lblManagerStatusValue)

$lblAgentStatus = New-Object System.Windows.Forms.Label
$lblAgentStatus.Text = "Current Agent"
$lblAgentStatus.Location = New-Object System.Drawing.Point(20,160)
$lblAgentStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblAgentStatus)

$lblAgentStatusValue = New-Object System.Windows.Forms.Label
$lblAgentStatusValue.Text = "Checking..."
$lblAgentStatusValue.Location = New-Object System.Drawing.Point(160,160)
$lblAgentStatusValue.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblAgentStatusValue)

$lblRegistrationStatus = New-Object System.Windows.Forms.Label
$lblRegistrationStatus.Text = "Agent Registration"
$lblRegistrationStatus.Location = New-Object System.Drawing.Point(350,160)
$lblRegistrationStatus.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblRegistrationStatus)

$lblRegistrationStatusValue = New-Object System.Windows.Forms.Label
$lblRegistrationStatusValue.Text = "Checking..."
$lblRegistrationStatusValue.Location = New-Object System.Drawing.Point(470,160)
$lblRegistrationStatusValue.Size = New-Object System.Drawing.Size(220,20)
$form.Controls.Add($lblRegistrationStatusValue)

# ============================================================
# BUTTONS
# ============================================================

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install Wazuh Agent"
$btnInstall.Location = New-Object System.Drawing.Point(20,200)
$btnInstall.Size = New-Object System.Drawing.Size(180,40)
$btnInstall.Add_Click({ Install-WazuhAgent })
$form.Controls.Add($btnInstall)

$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Text = "Uninstall Wazuh Agent"
$btnUninstall.Location = New-Object System.Drawing.Point(220,200)
$btnUninstall.Size = New-Object System.Drawing.Size(180,40)
$btnUninstall.Add_Click({ Uninstall-WazuhAgent })
$form.Controls.Add($btnUninstall)

$btnFIM = New-Object System.Windows.Forms.Button
$btnFIM.Text = "Add Default FIM"
$btnFIM.Location = New-Object System.Drawing.Point(420,200)
$btnFIM.Size = New-Object System.Drawing.Size(180,40)
$btnFIM.Add_Click({ Add-FIMMonitoring })
$form.Controls.Add($btnFIM)

$btnSysmon = New-Object System.Windows.Forms.Button
$btnSysmon.Text = "Install Sysmon"
$btnSysmon.Location = New-Object System.Drawing.Point(20,260)
$btnSysmon.Size = New-Object System.Drawing.Size(180,40)
$btnSysmon.Add_Click({ Install-Sysmon })
$form.Controls.Add($btnSysmon)

# ============================================================
# INSTALL YARA BUTTON
# ============================================================

$btnYara = New-Object System.Windows.Forms.Button
$btnYara.Text = "Install YARA"
$btnYara.Location = New-Object System.Drawing.Point(20,310)
$btnYara.Size = New-Object System.Drawing.Size(180,40)

$btnYara.Add_Click({
    Install-Yara
})

$form.Controls.Add($btnYara)


$btnRestartWazuh = New-Object System.Windows.Forms.Button
$btnRestartWazuh.Text = "Restart Wazuh"
$btnRestartWazuh.Location = New-Object System.Drawing.Point(220,260)
$btnRestartWazuh.Size = New-Object System.Drawing.Size(180,40)
$btnRestartWazuh.Add_Click({ Restart-WazuhService })
$form.Controls.Add($btnRestartWazuh)

$btnRestart = New-Object System.Windows.Forms.Button
$btnRestart.Text = "Restart Computer"
$btnRestart.Location = New-Object System.Drawing.Point(420,260)
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

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Location = New-Object System.Drawing.Point(650,260)
$btnExit.Size = New-Object System.Drawing.Size(90,40)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ============================================================
# FIM PATH MANAGER CONTROLS
# ============================================================

$lblFimPath = New-Object System.Windows.Forms.Label
$lblFimPath.Text = "FIM Folder Path"
$lblFimPath.Location = New-Object System.Drawing.Point(20,370)
$lblFimPath.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblFimPath)

$txtFimPath = New-Object System.Windows.Forms.TextBox
$txtFimPath.Location = New-Object System.Drawing.Point(160,370)
$txtFimPath.Size = New-Object System.Drawing.Size(320,20)
$form.Controls.Add($txtFimPath)

$btnBrowseFim = New-Object System.Windows.Forms.Button
$btnBrowseFim.Text = "Browse"
$btnBrowseFim.Location = New-Object System.Drawing.Point(500,365)
$btnBrowseFim.Size = New-Object System.Drawing.Size(90,30)
$btnBrowseFim.Add_Click({ Browse-FIMFolder })
$form.Controls.Add($btnBrowseFim)

$btnAddFimPath = New-Object System.Windows.Forms.Button
$btnAddFimPath.Text = "Add FIM Path"
$btnAddFimPath.Location = New-Object System.Drawing.Point(20,410)
$btnAddFimPath.Size = New-Object System.Drawing.Size(140,35)
$btnAddFimPath.Add_Click({ Add-FIMPathFromGUI })
$form.Controls.Add($btnAddFimPath)

$btnRefreshFim = New-Object System.Windows.Forms.Button
$btnRefreshFim.Text = "Refresh FIM Paths"
$btnRefreshFim.Location = New-Object System.Drawing.Point(180,410)
$btnRefreshFim.Size = New-Object System.Drawing.Size(150,35)
$btnRefreshFim.Add_Click({ Get-FIMPaths })
$form.Controls.Add($btnRefreshFim)

$lblFimList = New-Object System.Windows.Forms.Label
$lblFimList.Text = "Custom / Lab FIM Paths"
$lblFimList.Location = New-Object System.Drawing.Point(20,450)
$lblFimList.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($lblFimList)

$listFimPaths = New-Object System.Windows.Forms.ListBox
$listFimPaths.Location = New-Object System.Drawing.Point(20,475)
$listFimPaths.Size = New-Object System.Drawing.Size(570,80)
$form.Controls.Add($listFimPaths)

# ============================================================
# OUTPUT BOX
# ============================================================

$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Location = New-Object System.Drawing.Point(20,575)
$OutputBox.Size = New-Object System.Drawing.Size(660,120)
$OutputBox.Multiline = $true
$OutputBox.ScrollBars = "Vertical"
$OutputBox.ReadOnly = $true
$form.Controls.Add($OutputBox)

# ============================================================
# SHOW GUI
# ============================================================

$form.Topmost = $true
$form.Add_Shown({
    $form.Activate()
    Update-WazuhStatus
    Get-FIMPaths
})

[void]$form.ShowDialog()
