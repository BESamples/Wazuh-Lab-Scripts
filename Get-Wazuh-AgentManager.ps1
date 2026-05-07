Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        Wazuh Agent Manager" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Quick Start:" -ForegroundColor Yellow
Write-Host "1. Open PowerShell as Administrator"
Write-Host "2. Navigate to this folder"
Write-Host "3. If scripts are blocked, run:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass" -ForegroundColor Green
Write-Host ""
Write-Host "4. Run the script:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   .\manage-wazuh-agent.ps1" -ForegroundColor Green
Write-Host ""

Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/manage-wazuh-agent.ps1" `
  -OutFile "manage-wazuh-agent.ps1"

Write-Host "Download complete." -ForegroundColor Green
Write-Host "Run with:"
Write-Host ".\manage-wazuh-agent.ps1"
