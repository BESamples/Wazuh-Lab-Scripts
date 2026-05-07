# ============================================================
# Wazuh Lab Temporary File Server
# Purpose:
#   Temporarily share files from the current Windows folder
#   so Ubuntu can download them using wget.
#
# Run as Administrator.
# ============================================================


# ============================================================
# Section 1 - Settings
# ============================================================

$Port = 8000
$Folder = Get-Location
$RuleName = "Wazuh Lab Temp File Server 8000"
$TimeoutMinutes = 10


# ============================================================
# Section 2 - Display Startup Information
# ============================================================

Write-Host "Starting temporary file server..." -ForegroundColor Cyan
Write-Host "Serving files from: $Folder"
Write-Host "Port: $Port"


# ============================================================
# Section 3 - Open Windows Firewall Port
# ============================================================

New-NetFirewallRule `
    -DisplayName $RuleName `
    -Direction Inbound `
    -LocalPort $Port `
    -Protocol TCP `
    -Action Allow `
    -ErrorAction SilentlyContinue | Out-Null


# ============================================================
# Section 4 - Find Windows IP Address
# ============================================================

$IP = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*"
    } |
    Select-Object -First 1 -ExpandProperty IPAddress)


# ============================================================
# Section 5 - Show Ubuntu Download Commands
# ============================================================

Write-Host ""
Write-Host "From Ubuntu, download files with:" -ForegroundColor Yellow
Write-Host "wget http://$IP`:$Port/filename"
Write-Host ""
Write-Host "Examples:"
Write-Host "wget http://$IP`:$Port/id_ed25519"
Write-Host "wget http://$IP`:$Port/id_ed25519.pub"
Write-Host ""
Write-Host "To view file list in browser:"
Write-Host "http://$IP`:$Port/"
Write-Host ""
Write-Host "Server will close automatically after $TimeoutMinutes minutes."
Write-Host "Press CTRL+C to stop early."
Write-Host ""


# ============================================================
# Section 6 - Start HTTP Listener
# ============================================================

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Port/")
$listener.Start()

$StopAt = (Get-Date).AddMinutes($TimeoutMinutes)


# ============================================================
# Section 7 - Serve Files Until Timeout
# ============================================================

try {
    while ($listener.IsListening -and (Get-Date) -lt $StopAt) {

        $task = $listener.GetContextAsync()

        while (-not $task.IsCompleted -and (Get-Date) -lt $StopAt) {
            Start-Sleep -Milliseconds 200
        }

        if (-not $task.IsCompleted) {
            continue
        }

        $context = $task.Result
        $requestedFile = $context.Request.Url.AbsolutePath.TrimStart("/")


        # ----------------------------------------------------
        # Section 7A - Show Directory Listing
        # ----------------------------------------------------

        if ([string]::IsNullOrWhiteSpace($requestedFile)) {

            $files = Get-ChildItem -Path $Folder -File | Select-Object -ExpandProperty Name

            $html = "<html><body><h2>Available Files</h2><ul>"

            foreach ($f in $files) {
                $html += "<li><a href='/$f'>$f</a></li>"
            }

            $html += "</ul></body></html>"

            $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)

            $context.Response.StatusCode = 200
            $context.Response.ContentType = "text/html"
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.OutputStream.Close()

            continue
        }


        # ----------------------------------------------------
        # Section 7B - Serve Requested File
        # ----------------------------------------------------

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


# ============================================================
# Section 8 - Cleanup
# ============================================================

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
