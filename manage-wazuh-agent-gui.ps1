# ============================================================
# Wazuh Agent Manager GUI
# Version 1.0
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

function Install-WazuhAgent {

    $ManagerIP = $txtManagerIP.Text
    $AgentName = $txtAgentName.Text
    $Installer = $comboInstaller.SelectedItem

    if ([string]::IsNullOrWhiteSpace($ManagerIP)) {
        [System.Windows.Forms.MessageBox]::Show("Enter Wazuh Manager IP.")
        return
    }

    if (-not $Installer) {
        [System.Windows.Forms.MessageBox]::Show("Select a Wazuh installer.")
        return
    }

    $InstallerPath = "$env:USERPROFILE\Downloads\$Installer"

    if (!(Test-Path $InstallerPath)) {
        [System.Windows.Forms.MessageBox]::Show("Installer not found.")
        return
    }

    $OutputBox.AppendText("Installing Wazuh Agent...`r`n")

    Start-Process msiexec.exe -Wait -ArgumentList @(
        "/i `"$InstallerPath`"",
        "/qn",
        "WAZUH_MANAGER=`"$ManagerIP`"",
        "WAZUH_REGISTRATION_SERVER=`"$ManagerIP`"",
        "WAZUH_AGENT_NAME=`"$AgentName`""
    )

    Start-Service WazuhSvc -ErrorAction SilentlyContinue

    $OutputBox.AppendText("Wazuh installation complete.`r`n")
}

function Uninstall-WazuhAgent {

    $OutputBox.AppendText("Stopping Wazuh service...`r`n")

    Stop-Service WazuhSvc -Force -ErrorAction SilentlyContinue

    $apps = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", `
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Wazuh Agent*" }

    foreach ($app in $apps) {

        if ($app.UninstallString -match "\{.*\}") {

            $guid = $Matches[0]

            $OutputBox.AppendText("Uninstalling Wazuh Agent...`r`n")

            Start-Process msiexec.exe -Wait -ArgumentList "/x $guid /qn"
        }
    }

    $OutputBox.AppendText("Wazuh uninstall complete.`r`n")
}

function Add-FIMMonitoring {

    $OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    $FIMEntries = @(
'    <directories realtime="yes">C:\Users</directories>',
'    <directories realtime="yes">C:\Wazuh-Test</directories>'
)

    if (!(Test-Path "C:\Wazuh-Test")) {

        New-Item -Path "C:\Wazuh-Test" `
            -ItemType Directory `
            -Force | Out-Null
    }

    if (Test-Path $OssecConf) {

        $conf = Get-Content $OssecConf -Raw

        foreach ($Entry in $FIMEntries) {

            if ($conf -notmatch [regex]::Escape($Entry)) {

                $conf = $conf -replace `
                    "(?s)(<syscheck>.*?)(</syscheck>)",
                    "`$1`n$Entry`n`$2"
            }
        }

        Set-Content -Path $OssecConf -Value $conf

        Restart-Service WazuhSvc -ErrorAction SilentlyContinue

        $OutputBox.AppendText("FIM monitoring added.`r`n")
    }
    else {
        $OutputBox.AppendText("ossec.conf not found.`r`n")
    }
}

function Install-Sysmon {

    $SysmonFolder = "C:\Sysmon"
    $SysmonZip = "$SysmonFolder\Sysmon.zip"
    $SysmonConfig = "$SysmonFolder\sysmonconfig.xml"

    if (!(Test-Path $SysmonFolder)) {

        New-Item -Path $SysmonFolder `
            -ItemType Directory `
            -Force | Out-Null
    }

    $OutputBox.AppendText("Downloading Sysmon...`r`n")

    Invoke-WebRequest `
        -Uri "https://download.sysinternals.com/files/Sysmon.zip" `
        -OutFile $SysmonZip

    Expand-Archive `
        -Path $SysmonZip `
        -DestinationPath $SysmonFolder `
        -Force

    $OutputBox.AppendText("Downloading Sysmon config...`r`n")

    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" `
        -OutFile $SysmonConfig

    $OutputBox.AppendText("Installing Sysmon...`r`n")

    Start-Process `
        -FilePath "$SysmonFolder\Sysmon64.exe" `
        -Wait `
        -ArgumentList "-accepteula -i `"$SysmonConfig`""

    $OutputBox.AppendText("Sysmon installation complete.`r`n")
}

# ============================================================
# FIM PATH MANAGER
# ============================================================

$lblFimPath = New-Object System.Windows.Forms.Label
$lblFimPath.Text = "FIM Folder Path"
$lblFimPath.Location = New-Object System.Drawing.Point(20,280)
$lblFimPath.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($lblFimPath)

$txtFimPath = New-Object System.Windows.Forms.TextBox
$txtFimPath.Location = New-Object System.Drawing.Point(160,280)
$txtFimPath.Size = New-Object System.Drawing.Size(320,20)
$form.Controls.Add($txtFimPath)

$btnBrowseFim = New-Object System.Windows.Forms.Button
$btnBrowseFim.Text = "Browse"
$btnBrowseFim.Location = New-Object System.Drawing.Point(500,275)
$btnBrowseFim.Size = New-Object System.Drawing.Size(90,30)
$btnBrowseFim.Add_Click({ Browse-FIMFolder })
$form.Controls.Add($btnBrowseFim)

$btnAddFimPath = New-Object System.Windows.Forms.Button
$btnAddFimPath.Text = "Add FIM Path"
$btnAddFimPath.Location = New-Object System.Drawing.Point(20,320)
$btnAddFimPath.Size = New-Object System.Drawing.Size(140,35)
$btnAddFimPath.Add_Click({ Add-FIMPathFromGUI })
$form.Controls.Add($btnAddFimPath)

$btnRefreshFim = New-Object System.Windows.Forms.Button
$btnRefreshFim.Text = "Refresh FIM Paths"
$btnRefreshFim.Location = New-Object System.Drawing.Point(180,320)
$btnRefreshFim.Size = New-Object System.Drawing.Size(150,35)
$btnRefreshFim.Add_Click({ Get-FIMPaths })
$form.Controls.Add($btnRefreshFim)

$listFimPaths = New-Object System.Windows.Forms.ListBox
$listFimPaths.Location = New-Object System.Drawing.Point(20,370)
$listFimPaths.Size = New-Object System.Drawing.Size(570,80)
$form.Controls.Add($listFimPaths)



# ============================================================
# GUI WINDOW
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Wazuh Agent Manager GUI"
$form.Size = New-Object System.Drawing.Size(700,500)
$form.StartPosition = "CenterScreen"

# ============================================================
# LABELS
# ============================================================

$lblManagerIP = New-Object System.Windows.Forms.Label
$lblManagerIP.Text = "Wazuh Manager IP"
$lblManagerIP.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($lblManagerIP)

$lblAgentName = New-Object System.Windows.Forms.Label
$lblAgentName.Text = "Agent Name"
$lblAgentName.Location = New-Object System.Drawing.Point(20,60)
$form.Controls.Add($lblAgentName)

$lblInstaller = New-Object System.Windows.Forms.Label
$lblInstaller.Text = "Installer"
$lblInstaller.Location = New-Object System.Drawing.Point(20,100)
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

$Installers = Get-ChildItem `
    -Path "$env:USERPROFILE\Downloads" `
    -Filter "wazuh-agent-*.msi" `
    -ErrorAction SilentlyContinue

foreach ($item in $Installers) {
    $comboInstaller.Items.Add($item.Name)
}

$form.Controls.Add($comboInstaller)

# ============================================================
# BUTTONS
# ============================================================

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install Wazuh Agent"
$btnInstall.Location = New-Object System.Drawing.Point(20,160)
$btnInstall.Size = New-Object System.Drawing.Size(180,40)
$btnInstall.Add_Click({ Install-WazuhAgent })
$form.Controls.Add($btnInstall)

$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Text = "Uninstall Wazuh Agent"
$btnUninstall.Location = New-Object System.Drawing.Point(220,160)
$btnUninstall.Size = New-Object System.Drawing.Size(180,40)
$btnUninstall.Add_Click({ Uninstall-WazuhAgent })
$form.Controls.Add($btnUninstall)

$btnFIM = New-Object System.Windows.Forms.Button
$btnFIM.Text = "Add FIM Monitoring"
$btnFIM.Location = New-Object System.Drawing.Point(420,160)
$btnFIM.Size = New-Object System.Drawing.Size(180,40)
$btnFIM.Add_Click({ Add-FIMMonitoring })
$form.Controls.Add($btnFIM)

$btnSysmon = New-Object System.Windows.Forms.Button
$btnSysmon.Text = "Install Sysmon"
$btnSysmon.Location = New-Object System.Drawing.Point(20,220)
$btnSysmon.Size = New-Object System.Drawing.Size(180,40)
$btnSysmon.Add_Click({ Install-Sysmon })
$form.Controls.Add($btnSysmon)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Location = New-Object System.Drawing.Point(220,220)
$btnExit.Size = New-Object System.Drawing.Size(180,40)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ============================================================
# OUTPUT BOX
# ============================================================

$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Location = New-Object System.Drawing.Point(20,290)
$OutputBox.Size = New-Object System.Drawing.Size(640,140)
$OutputBox.Multiline = $true
$OutputBox.ScrollBars = "Vertical"
$form.Controls.Add($OutputBox)

# ============================================================
# SHOW GUI
# ============================================================

$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })

[void]$form.ShowDialog()
