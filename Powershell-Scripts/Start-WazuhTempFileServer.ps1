# Wazuh Lab Temporary File Server
# Run PowerShell as Administrator

$Port = 8000
$Folder = Get-Location
$RuleName = "Wazuh Lab Temp File Server 8000"
$TimeoutMinutes = 10

Write-Host "Starting temporary file server..." -ForegroundColor Cyan
Write-Host "Serving files from: $Folder"
Write-Host "Port: $Port"

# Open firewall
New-NetFirewallRule `
    -DisplayName $RuleName `
    -Direction Inbound `
    -LocalPort $Port `
    -Protocol TCP `
    -Action Allow `
    -ErrorAction SilentlyContinue | Out-Null

# Get Windows IP
$IP = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*"
    } |
    Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host ""
Write-Host "From Ubuntu, download files with:" -ForegroundColor Yellow
Write-Host "wget http://$IP`:$Port/filename"
Write-Host ""
Write-Host "Example:"
Write-Host "wget http://$IP`:$Port/id_ed25519"
Write-Host ""
Write-Host "Server will close automatically after $TimeoutMinutes minutes."
Write-Host "Press CTRL+C to stop early."
Write-Host ""

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Port/")
$listener.Start()

$StopAt = (Get-Date).AddMinutes($TimeoutMinutes)

try {
    while ($listener.IsListening -and (Get-Date) -lt $StopAt) {

        # Wait max 1 second at a time so timeout can work
        $task = $listener.GetContextAsync()

        while (-not $task.IsCompleted -and (Get-Date) -lt $StopAt) {
            Start-Sleep -Milliseconds 200
        }

        if (-not $task.IsCompleted) {
            continue
        }

        $context = $task.Result

        $requestedFile = $context.Request.Url.AbsolutePath.TrimStart("/")
        $file = Join-Path $Folder $requestedFile

        if (Test-Path $file -PathType Leaf) {
            Write-Host "Serving: $requestedFile" -ForegroundColor Green

            $bytes = [System.IO.File]::ReadAllBytes($file)
            $context.Response.StatusCode = 200
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        else {
            Write-Host "File not found: $requestedFile" -ForegroundColor Red

            $message = [System.Text.Encoding]::UTF8.GetBytes("404 File not found")
            $context.Response.StatusCode = 404
            $context.Response.ContentLength64 = $message.Length
            $context.Response.OutputStream.Write($message, 0, $message.Length)
        }

        $context.Response.OutputStream.Close()
    }
}
finally {
    Write-Host ""
    Write-Host "Stopping server and closing firewall rule..." -ForegroundColor Cyan

    if ($listener.IsListening) {
        $listener.Stop()
    }

    $listener.Close()

    Remove-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue

    Write-Host "Done. Firewall rule removed." -ForegroundColor Green
}
