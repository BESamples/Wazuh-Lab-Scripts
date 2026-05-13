# ============================================================
# Safe Wazuh Lab - Remote Login Simulation
# Server 2019 -> Windows 10
# ============================================================

@'
Write-Host "Safe Wazuh Lab Simulation Running"

$LogPath = "C:\Wazuh-Test\lab_simulation.txt"

"==== Safe Wazuh Lab Simulation ====" | Out-File $LogPath
"Hostname: $env:COMPUTERNAME" | Out-File $LogPath -Append
"User: $env:USERNAME" | Out-File $LogPath -Append
"Date: $(Get-Date)" | Out-File $LogPath -Append
"IP Info:" | Out-File $LogPath -Append
ipconfig | Out-File $LogPath -Append

Write-Host "Lab simulation complete. Log written to $LogPath"
'@ | Out-File C:\LabShare\wazuh-lab-test.ps1

Start-Process "powershell" -ArgumentList "-NoExit", "-Command", "cd C:\LabShare; python -m http.server 8080"
