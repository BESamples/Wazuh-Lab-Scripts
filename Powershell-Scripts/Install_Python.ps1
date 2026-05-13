cd C:\LabShare

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://+:8080/")
$Listener.Start()

Write-Host "HTTP Server running on port 8080..." -ForegroundColor Green

while ($Listener.IsListening) {
    $Context = $Listener.GetContext()
    $Response = $Context.Response

    $FilePath = "C:\LabShare\wazuh-lab-test.ps1"

    $Buffer = [System.IO.File]::ReadAllBytes($FilePath)

    $Response.ContentLength64 = $Buffer.Length
    $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
    $Response.OutputStream.Close()
}
