$folder = Get-Location
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:8000/")
$listener.Start()
Write-Host "Serving files from $folder on port 8000"
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $file = Join-Path $folder ($context.Request.Url.AbsolutePath.TrimStart("/"))
    if (Test-Path $file) {
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    $context.Response.OutputStream.Close()
}
