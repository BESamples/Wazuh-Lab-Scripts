# manage-powershell-wazuh-logging.ps1
# Run as Administrator

$OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

$PowerShellBlock = @"

  <localfile>
    <location>Microsoft-Windows-PowerShell/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
"@

function Show-Menu {
    Write-Host ""
    Write-Host "=== Wazuh PowerShell Log Collection Manager ===" -ForegroundColor Cyan
    Write-Host "1. Check status"
    Write-Host "2. Enable PowerShell log collection"
    Write-Host "3. Disable PowerShell log collection"
    Write-Host "4. Exit"
}

if (!(Test-Path $OssecConf)) {
    Write-Host "ERROR: ossec.conf not found at $OssecConf" -ForegroundColor Red
    exit 1
}

Show-Menu
$Choice = Read-Host "Choose an option"

$conf = Get-Content $OssecConf -Raw
$Enabled = $conf -match "Microsoft-Windows-PowerShell/Operational"

switch ($Choice) {

    "1" {
        if ($Enabled) {
            Write-Host "PowerShell log collection is ENABLED in ossec.conf." -ForegroundColor Green
        } else {
            Write-Host "PowerShell log collection is NOT enabled in ossec.conf." -ForegroundColor Yellow
        }
    }

    "2" {
        if ($Enabled) {
            Write-Host "PowerShell log collection is already enabled." -ForegroundColor Yellow
        } else {
            $conf = $conf -replace "</ossec_config>", "$PowerShellBlock`n</ossec_config>"
            Set-Content -Path $OssecConf -Value $conf
            Write-Host "PowerShell log collection added." -ForegroundColor Green
            Restart-Service WazuhSvc
            Write-Host "Wazuh service restarted."
        }
    }

    "3" {
        if (-not $Enabled) {
            Write-Host "PowerShell log collection is already disabled." -ForegroundColor Yellow
        } else {
            $pattern = '(?s)\s*<localfile>\s*<location>Microsoft-Windows-PowerShell/Operational</location>\s*<log_format>eventchannel</log_format>\s*</localfile>'
            $conf = $conf -replace $pattern, ""
            Set-Content -Path $OssecConf -Value $conf
            Write-Host "PowerShell log collection removed." -ForegroundColor Green
            Restart-Service WazuhSvc
            Write-Host "Wazuh service restarted."
        }
    }

    "4" {
        Write-Host "Exiting."
    }

    default {
        Write-Host "Invalid choice." -ForegroundColor Red
    }
}
