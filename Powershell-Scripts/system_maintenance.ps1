# Task 1: Check Disk Space and Report If Low
Write-Host "Reporting low disk space"
$lowSpaceThreshold = 10GB
Get-PSDrive | Where-Object { $_.Used -ne $null -and $_.Free -lt $lowSpaceThreshold } | ForEach-Object {
    Write-Host "Drive $($_.Name) has low disk space: $([math]::round($_.Free/1GB,2)) GB left"
}
# Task 2: Check and Start Stopped Services
Write-Host "Starting stopped services"
$servicesToCheck = @("spooler")
foreach ($service in $servicesToCheck) {
    $svc = Get-Service -Name $service
    if ($svc.Status -ne 'Running') {
        Start-Service $service
        Write-Host "Service $service started."
    }
}  
# Task 3: Archive Old Logs and Report Which Logs Were Archived
Write-Host "Archiving logs"
$logPath = "C:\logs"
$archivePath = "C:\archive"
$cutoffDate = (Get-Date).AddMonths(-6)
if (-not (Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory
}
if (-not (Test-Path -Path $archivePath)) {
    New-Item -Path $archivePath -ItemType Directory
}
Get-ChildItem -Path $logPath -Filter "*.log" | Where-Object {$_.LastWriteTime -lt $cutoffDate} | ForEach-Object {
    Move-Item $_.FullName -Destination $archivePath
    Write-Host "Archived log: $($_.Name)"
}
