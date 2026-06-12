$InstallRoot = "C:\ProgramData\DLP"
$TargetRoot = "C:\DLP_Test"
$AlertRoot = "$InstallRoot\alerts"
$StateRoot = "$InstallRoot\state"

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
New-Item -ItemType Directory -Force -Path $AlertRoot | Out-Null
New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Copy-Item "$SourceDir\rules_windows.py" "$InstallRoot\rules_windows.py" -Force
Copy-Item "$SourceDir\windows_dlp_scanner.py" "$InstallRoot\windows_dlp_scanner.py" -Force
Copy-Item "$SourceDir\run_dlp_once.ps1" "$InstallRoot\run_dlp_once.ps1" -Force

@"
Employee: John Smith
SSN: 123-45-6789
Classification: Confidential
"@ | Set-Content "$TargetRoot\employee_record.txt"

@"
Customer payment test
Card: 4111-1111-1111-1111
Restricted payment information.
"@ | Set-Content "$TargetRoot\payment_data.txt"

@"
api_key = "ABCD1234SECRETKEY9999"
token: mytokenvalue1234567890
"@ | Set-Content "$TargetRoot\api_config.txt"

@"
QA test data only.
Fake SSN: 123-45-6789
This is not real customer data.
"@ | Set-Content "$TargetRoot\false_positive_test.txt"

@"
AWS key found during review:
AKIA1234567890ABCDEF
database_password = "SuperSecretPassword123"
"@ | Set-Content "$TargetRoot\false_negative_secret.txt"

@"
Payroll backup
SSN: 987-65-4321
Internal use only.
"@ | Set-Content "$TargetRoot\payroll_backup.txt"

Write-Host ""
Write-Host "Windows DLP lab setup complete."
Write-Host "Target folder: $TargetRoot"
Write-Host "Alert folder: $AlertRoot"
Write-Host ""
Write-Host "Run scanner with:"
Write-Host "powershell.exe -ExecutionPolicy Bypass -File C:\ProgramData\DLP\run_dlp_once.ps1"
