# Run PowerShell as Administrator

$WazuhManager = "Change_ME"
$AgentName    = "WinLab1"
$Installer    = "wazuh-agent-4.14.5-1.msi"
$DownloadPath = "$env:USERPROFILE\Downloads\$Installer"

Write-Host "=== Wazuh Windows Agent Setup ==="

# 1. Confirm MSI exists
if (!(Test-Path $DownloadPath)) {
    Write-Host "ERROR: Installer not found at $DownloadPath" -ForegroundColor Red
    Write-Host "Put the MSI in your Downloads folder first."
    exit 1
}

# 2. Install Wazuh Agent
Write-Host "Installing Wazuh Agent..."
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$DownloadPath`" /qn WAZUH_MANAGER=`"$WazuhManager`" WAZUH_AGENT_NAME=`"$AgentName`""

# 3. Start Wazuh service
Write-Host "Starting Wazuh service..."
Start-Service WazuhSvc -ErrorAction SilentlyContinue

# 4. Enable Windows logon auditing
Write-Host "Enabling Windows logon auditing..."
auditpol /set /subcategory:"Logon" /failure:enable
auditpol /set /subcategory:"Logon" /success:enable

# 5. Enable PowerShell Script Block Logging
Write-Host "Enabling PowerShell Script Block Logging..."
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -Value 1

# 6. Add PowerShell Operational log collection to ossec.conf
$OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

Write-Host "Adding PowerShell log collection to Wazuh agent config..."

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
        Write-Host "PowerShell log collection added."
    } else {
        Write-Host "PowerShell log collection already exists."
    }
} else {
    Write-Host "ERROR: ossec.conf not found." -ForegroundColor Red
}

# 7. Restart Wazuh agent
Write-Host "Restarting Wazuh service..."
Restart-Service WazuhSvc -ErrorAction SilentlyContinue

# 8. Show status
Write-Host ""
Write-Host "=== Wazuh Agent Status ==="
Get-Service WazuhSvc

Write-Host ""
Write-Host "Setup complete. Reboot Windows to fully apply PowerShell logging."
