# ============================================================
# FSRM DLP LAB SETUP SCRIPT
# Creates PII, PCI, and Confidential classification + quarantine
# Tested concept: Windows Server 2019 FSRM DLP lab
# ============================================================

# SECTION 1 - ADMIN CHECK
# Approx lines 1-25
# ============================================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$RootPath = "C:\SensitiveData",

    # Use -RunNow if you want the script to run classification and quarantine tasks immediately.
    [switch]$RunNow
)

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Ensure-Folder {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "Created folder: $Path" -ForegroundColor Green
    }
    else {
        Write-Host "Folder already exists: $Path" -ForegroundColor Yellow
    }
}

# SECTION 2 - LAB PATHS
# Approx lines 27-55
# ============================================================

# Cleaner than scanning the whole C:\SensitiveData folder.
# This prevents the file management task from scanning its own Quarantine folder.
$ScanPath = Join-Path $RootPath "Scan"
$QuarantineRoot = Join-Path $RootPath "Quarantine"
$PiiQuarantine = Join-Path $QuarantineRoot "PII"
$PciQuarantine = Join-Path $QuarantineRoot "PCI"
$ConfidentialQuarantine = Join-Path $QuarantineRoot "Confidential"

$ReportRoot = "C:\StorageReports"
$InteractiveReports = Join-Path $ReportRoot "Interactive"
$ScheduledReports = Join-Path $ReportRoot "Scheduled"
$IncidentReports = Join-Path $ReportRoot "Incident"

$PropertyName = "SensitiveDataType"

$ClassificationRules = @(
    "DLP Detect SSN - PII",
    "DLP Detect Credit Card - PCI",
    "DLP Detect Confidential Keywords"
)

$FileManagementJobs = @(
    "Quarantine PII Files",
    "Quarantine PCI Files",
    "Quarantine Confidential Files"
)

# SECTION 3 - INSTALL FSRM
# Approx lines 57-85
# ============================================================

Write-Step "SECTION 3 - Installing File Server Resource Manager"

$feature = Get-WindowsFeature -Name FS-Resource-Manager

if ($feature.Installed -ne $true) {
    Write-Host "Installing FSRM..." -ForegroundColor Yellow
    Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools
}
else {
    Write-Host "FSRM is already installed." -ForegroundColor Green
}

Import-Module FileServerResourceManager -ErrorAction Stop

Start-Service SrmSvc -ErrorAction SilentlyContinue
Restart-Service SrmSvc -Force -ErrorAction SilentlyContinue

# SECTION 4 - CREATE FOLDERS
# Approx lines 87-115
# ============================================================

Write-Step "SECTION 4 - Creating lab folders"

Ensure-Folder $RootPath
Ensure-Folder $ScanPath
Ensure-Folder $QuarantineRoot
Ensure-Folder $PiiQuarantine
Ensure-Folder $PciQuarantine
Ensure-Folder $ConfidentialQuarantine

Ensure-Folder $ReportRoot
Ensure-Folder $InteractiveReports
Ensure-Folder $ScheduledReports
Ensure-Folder $IncidentReports

Write-Host "Fixing folder permissions for report folders..." -ForegroundColor Yellow
icacls $ReportRoot /grant "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" /T | Out-Null

# SECTION 5 - OPTIONAL VSS / REPORT SUPPORT
# Approx lines 117-135
# ============================================================

Write-Step "SECTION 5 - Setting VSS shadow storage for report/classification stability"

try {
    vssadmin resize shadowstorage /For=C: /On=C: /MaxSize=10% | Out-Null
    Write-Host "VSS shadow storage set to 10% for C:." -ForegroundColor Green
}
catch {
    Write-Host "VSS shadow storage resize failed or was not needed." -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor DarkYellow
}

# SECTION 6 - CREATE TEST FILES
# Approx lines 137-170
# ============================================================

Write-Step "SECTION 6 - Creating fake DLP test files"

"SSN test number 123-45-6789. Fake lab data only." |
    Set-Content (Join-Path $ScanPath "FSRM-Test-PII.txt") -Encoding ASCII

"Credit card test 4111 1111 1111 1111. Fake lab data only." |
    Set-Content (Join-Path $ScanPath "FSRM-Test-PCI.txt") -Encoding ASCII

"Confidential company document. Internal use only. Do not distribute. Fake lab data only." |
    Set-Content (Join-Path $ScanPath "FSRM-Test-Confidential.txt") -Encoding ASCII

"This is a normal file with no sensitive data." |
    Set-Content (Join-Path $ScanPath "FSRM-Test-Normal.txt") -Encoding ASCII

Write-Host "Created fake test files in: $ScanPath" -ForegroundColor Green

# SECTION 7 - REMOVE OLD LAB RULES AND JOBS
# Approx lines 172-205
# ============================================================

Write-Step "SECTION 7 - Removing old lab-created rules and jobs"

foreach ($job in $FileManagementJobs) {
    try {
        Remove-FsrmFileManagementJob -Name $job -Confirm:$false -ErrorAction Stop
        Write-Host "Removed old file management job: $job" -ForegroundColor Yellow
    }
    catch {
        Write-Host "No existing file management job found: $job" -ForegroundColor DarkGray
    }
}

foreach ($rule in $ClassificationRules) {
    try {
        Remove-FsrmClassificationRule -Name $rule -Confirm:$false -ErrorAction Stop
        Write-Host "Removed old classification rule: $rule" -ForegroundColor Yellow
    }
    catch {
        Write-Host "No existing classification rule found: $rule" -ForegroundColor DarkGray
    }
}

# SECTION 8 - CREATE CLASSIFICATION PROPERTY
# Approx lines 207-250
# ============================================================

Write-Step "SECTION 8 - Creating SensitiveDataType classification property"

$PropertyValues = @(
    New-FsrmClassificationPropertyValue -Name "PII" -Description "Personally Identifiable Information"
    New-FsrmClassificationPropertyValue -Name "PCI" -Description "Payment Card Information"
    New-FsrmClassificationPropertyValue -Name "Confidential" -Description "Confidential company data"
    New-FsrmClassificationPropertyValue -Name "None" -Description "No sensitive data detected"
)

$ExistingProperty = Get-FsrmClassificationPropertyDefinition -Name $PropertyName -ErrorAction SilentlyContinue

if ($null -eq $ExistingProperty) {
    New-FsrmClassificationPropertyDefinition `
        -Name $PropertyName `
        -DisplayName $PropertyName `
        -Description "DLP lab classification property for PII, PCI, Confidential, and None." `
        -Type OrderedList `
        -PossibleValue $PropertyValues

    Write-Host "Created classification property: $PropertyName" -ForegroundColor Green
}
else {
    Set-FsrmClassificationPropertyDefinition `
        -Name $PropertyName `
        -DisplayName $PropertyName `
        -Description "DLP lab classification property for PII, PCI, Confidential, and None." `
        -PossibleValue $PropertyValues

    Write-Host "Updated existing classification property: $PropertyName" -ForegroundColor Green
}

# SECTION 9 - CREATE CLASSIFICATION RULES
# Approx lines 252-310
# ============================================================

Write-Step "SECTION 9 - Creating DLP classification rules"

# PII / SSN rule
New-FsrmClassificationRule `
    -Name "DLP Detect SSN - PII" `
    -Description "Detects SSN pattern and labels file as PII." `
    -Namespace @($ScanPath) `
    -Property $PropertyName `
    -PropertyValue "PII" `
    -ClassificationMechanism "Content Classifier" `
    -ContentRegularExpression @("\d{3}-\d{2}-\d{4}") `
    -ReevaluateProperty Overwrite

Write-Host "Created rule: DLP Detect SSN - PII" -ForegroundColor Green

# PCI / credit card rule
New-FsrmClassificationRule `
    -Name "DLP Detect Credit Card - PCI" `
    -Description "Detects credit card-like numbers and labels file as PCI." `
    -Namespace @($ScanPath) `
    -Property $PropertyName `
    -PropertyValue "PCI" `
    -ClassificationMechanism "Content Classifier" `
    -ContentRegularExpression @("\b\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}\b") `
    -ReevaluateProperty Overwrite

Write-Host "Created rule: DLP Detect Credit Card - PCI" -ForegroundColor Green

# Confidential rule
New-FsrmClassificationRule `
    -Name "DLP Detect Confidential Keywords" `
    -Description "Detects confidential keywords and labels file as Confidential." `
    -Namespace @($ScanPath) `
    -Property $PropertyName `
    -PropertyValue "Confidential" `
    -ClassificationMechanism "Content Classifier" `
    -ContentRegularExpression @("(?i)\b(confidential|internal use only|do not distribute|restricted|secret)\b") `
    -ReevaluateProperty Overwrite

Write-Host "Created rule: DLP Detect Confidential Keywords" -ForegroundColor Green

# SECTION 10 - CREATE FILE MANAGEMENT TASKS
# Approx lines 312-390
# ============================================================

Write-Step "SECTION 10 - Creating quarantine remediation tasks"

$Schedule = New-FsrmScheduledTask -Time (Get-Date "12:00am") -Weekly @("Monday")

function New-DlpQuarantineJob {
    param(
        [string]$JobName,
        [string]$ClassificationValue,
        [string]$DestinationPath
    )

    $Condition = New-FsrmFmjCondition `
        -Property $PropertyName `
        -Condition Equal `
        -Value $ClassificationValue

    $CommandParameters = "/c move /Y `"[Source File Path]`" `"$DestinationPath\`""

    $Action = New-FsrmFmjAction `
        -Type Custom `
        -Command "C:\Windows\System32\cmd.exe" `
        -CommandParameters $CommandParameters `
        -SecurityLevel LocalSystem

    New-FsrmFileManagementJob `
        -Name $JobName `
        -Description "DLP lab remediation: move $ClassificationValue files to quarantine." `
        -Namespace @($ScanPath) `
        -Condition @($Condition) `
        -Action $Action `
        -Schedule $Schedule

    Write-Host "Created file management task: $JobName" -ForegroundColor Green
}

New-DlpQuarantineJob `
    -JobName "Quarantine PII Files" `
    -ClassificationValue "PII" `
    -DestinationPath $PiiQuarantine

New-DlpQuarantineJob `
    -JobName "Quarantine PCI Files" `
    -ClassificationValue "PCI" `
    -DestinationPath $PciQuarantine

New-DlpQuarantineJob `
    -JobName "Quarantine Confidential Files" `
    -ClassificationValue "Confidential" `
    -DestinationPath $ConfidentialQuarantine

# SECTION 11 - RUN CLASSIFICATION OPTIONAL
# Approx lines 392-450
# ============================================================

if ($RunNow) {
    Write-Step "SECTION 11 - Running classification now"

    try {
        Stop-FsrmClassification -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Start-FsrmClassification -Confirm:$false

        for ($i = 1; $i -le 30; $i++) {
            $Status = Get-FsrmClassification
            Write-Host "Classification status: $($Status.Status)"

            if ($Status.Status -eq "NotRunning") {
                break
            }

            Start-Sleep -Seconds 5
        }

        $FinalStatus = Get-FsrmClassification
        Write-Host "Final classification status: $($FinalStatus.Status)" -ForegroundColor Green

        if ($FinalStatus.LastError) {
            Write-Host "LastError: $($FinalStatus.LastError)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Classification failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Step "SECTION 12 - Running quarantine tasks now"

    foreach ($job in $FileManagementJobs) {
        try {
            Write-Host "Starting file management job: $job" -ForegroundColor Yellow
            Start-FsrmFileManagementJob -Name $job -Confirm:$false
            Wait-FsrmFileManagementJob -Name $job -Timeout 120
            Write-Host "Completed or timeout reached for: $job" -ForegroundColor Green
        }
        catch {
            Write-Host "Could not run job: $job" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
}
else {
    Write-Host ""
    Write-Host "Setup complete. Classification and quarantine jobs were created but not run." -ForegroundColor Yellow
    Write-Host "To run classification manually:" -ForegroundColor Yellow
    Write-Host "Start-FsrmClassification -Confirm:`$false" -ForegroundColor White
    Write-Host ""
    Write-Host "To run quarantine tasks manually:" -ForegroundColor Yellow
    Write-Host "Start-FsrmFileManagementJob -Name `"Quarantine PII Files`"" -ForegroundColor White
    Write-Host "Start-FsrmFileManagementJob -Name `"Quarantine PCI Files`"" -ForegroundColor White
    Write-Host "Start-FsrmFileManagementJob -Name `"Quarantine Confidential Files`"" -ForegroundColor White
}

# SECTION 13 - DISPLAY SUMMARY
# Approx lines 452-500
# ============================================================

Write-Step "SECTION 13 - Setup summary"

Write-Host "Scan folder:" -ForegroundColor Cyan
Write-Host "  $ScanPath"

Write-Host "Quarantine folders:" -ForegroundColor Cyan
Write-Host "  PII:          $PiiQuarantine"
Write-Host "  PCI:          $PciQuarantine"
Write-Host "  Confidential: $ConfidentialQuarantine"

Write-Host "Report folder:" -ForegroundColor Cyan
Write-Host "  $InteractiveReports"

Write-Host "Created classification property:" -ForegroundColor Cyan
Write-Host "  $PropertyName"

Write-Host "Created classification rules:" -ForegroundColor Cyan
$ClassificationRules | ForEach-Object { Write-Host "  $_" }

Write-Host "Created file management tasks:" -ForegroundColor Cyan
$FileManagementJobs | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "FSRM DLP lab setup is complete." -ForegroundColor Green
