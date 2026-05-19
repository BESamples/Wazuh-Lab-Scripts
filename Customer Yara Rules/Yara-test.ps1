# test-yara-wazuh.ps1
# Run as Administrator

$YaraFolder = "C:\Program Files (x86)\ossec-agent\active-response\bin\yara"
$RulesFolder = "$YaraFolder\rules"
$YaraExe = "$YaraFolder\yara64.exe"
$TestFile = "C:\Wazuh-Test\evil.txt"
$AlwaysRule = "$RulesFolder\always-match.yar"
$TestRule = "$RulesFolder\test-malware.yar"

# Check for Microsoft Visual C++ runtime required by yara64.exe
$VcRuntime = @(
    "C:\Windows\System32\VCRUNTIME140.dll",
    "C:\Windows\SysWOW64\VCRUNTIME140.dll"
)

$VcRuntimeFound = $false

foreach ($dll in $VcRuntime) {
    if (Test-Path $dll) {
        $VcRuntimeFound = $true
    }
}

if (-not $VcRuntimeFound) {
    Write-Host "FAIL: Microsoft Visual C++ Runtime is missing." -ForegroundColor Red
    Write-Host "YARA needs VCRUNTIME140.dll to run." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Fix:" -ForegroundColor Cyan
    Write-Host "Download and install Microsoft Visual C++ Redistributable 2015-2022 x64:"
    Write-Host "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    Write-Host ""
    Write-Host "After installing it, reopen PowerShell as Administrator and rerun this script."
    exit
}
else {
    Write-Host "PASS: Microsoft Visual C++ Runtime found." -ForegroundColor Green
}



Write-Host "=== YARA Wazuh Troubleshooter ===" -ForegroundColor Cyan

if (!(Test-Path $YaraFolder)) {
    Write-Host "FAIL: YARA folder missing: $YaraFolder" -ForegroundColor Red
    exit
}

if (!(Test-Path $RulesFolder)) {
    Write-Host "Creating rules folder..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $RulesFolder | Out-Null
}

if (!(Test-Path $YaraExe)) {
    Write-Host "FAIL: yara64.exe missing: $YaraExe" -ForegroundColor Red
    exit
}

if (!(Test-Path "C:\Wazuh-Test")) {
    Write-Host "Creating C:\Wazuh-Test..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path "C:\Wazuh-Test" | Out-Null
}

Write-Host "Creating test file..." -ForegroundColor Yellow
Set-Content -Path $TestFile -Value "MALWARE_TEST_STRING" -Encoding ASCII

Write-Host "Creating Always_Match rule..." -ForegroundColor Yellow
Set-Content -Path $AlwaysRule -Encoding ASCII -Value @'
rule Always_Match
{
    condition:
        true
}
'@

Write-Host "Creating Test_Malware_String rule..." -ForegroundColor Yellow
Set-Content -Path $TestRule -Encoding ASCII -Value @'
rule Test_Malware_String
{
    strings:
        $a = "MALWARE_TEST_STRING"

    condition:
        $a
}
'@

Write-Host ""
Write-Host "Testing Always_Match rule..." -ForegroundColor Cyan
$AlwaysResult = & $YaraExe $AlwaysRule $TestFile

if ($AlwaysResult -match "Always_Match") {
    Write-Host "PASS: Always_Match rule worked." -ForegroundColor Green
}
else {
    Write-Host "FAIL: Always_Match did not return a match." -ForegroundColor Red
}

Write-Host ""
Write-Host "Testing malware string rule..." -ForegroundColor Cyan
$TestResult = & $YaraExe $TestRule $TestFile

if ($TestResult -match "Test_Malware_String") {
    Write-Host "PASS: Test_Malware_String rule worked." -ForegroundColor Green
}
else {
    Write-Host "FAIL: Test_Malware_String did not return a match." -ForegroundColor Red
}

Write-Host ""
Write-Host "YARA executable:" -ForegroundColor Cyan
Write-Host $YaraExe

Write-Host ""
Write-Host "Rules folder:" -ForegroundColor Cyan
Write-Host $RulesFolder

Write-Host ""
Write-Host "Test file:" -ForegroundColor Cyan
Write-Host $TestFile
