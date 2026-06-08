Set-Content C:\Users\Public\fake-updater.ps1 'Write-Host "Fake updater lab test"'
powershell.exe -ExecutionPolicy Bypass -File C:\Users\Public\fake-updater.ps1
