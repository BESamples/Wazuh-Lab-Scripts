param(
    [switch]$NoGui,
    [switch]$RunScan,
    [string]$ScanPath = "C:\DLP_Test"
)

# ============================================================
# WINDOWS DLP LAB GUI
# One-script version for Wazuh lab
# ============================================================

$script:DlpRoot = "C:\ProgramData\DLP"
$script:DlpTarget = "C:\DLP_Test"
$script:DlpAlerts = "C:\ProgramData\DLP\alerts"
$script:DlpState = "C:\ProgramData\DLP\state"
$script:DlpJson = "C:\ProgramData\DLP\alerts\dlp_alerts.json"
$script:DlpJsonl = "C:\ProgramData\DLP\alerts\dlp_alerts.jsonl"
$script:DlpStateFile = "C:\ProgramData\DLP\state\dlp_state.json"
$script:DlpOutputBox = $null

$script:TextExtensions = @(
    ".txt", ".log", ".csv", ".json", ".xml", ".ini", ".config",
    ".ps1", ".bat", ".cmd", ".yml", ".yaml", ".md", ".rtf"
)

$script:DocxExtensions = @(".docx")

$script:ImageExtensions = @(
    ".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"
)

$script:ExclusionKeywords = @(
    "QA"
)

$script:DlpRules = @(
    [pscustomobject]@{
        Name = "ssn"
        Pattern = "\b\d{3}-\d{2}-\d{4}\b"
        Severity = "high"
    },
    [pscustomobject]@{
        Name = "credit_card"
        Pattern = "\b(?:\d[ -]*?){13,16}\b"
        Severity = "high"
    },
    [pscustomobject]@{
        Name = "api_key"
        Pattern = "\b(api_key|secret|token)\s*[:=]\s*['""]?[A-Za-z0-9_\-]{16,}"
        Severity = "high"
    },
    [pscustomobject]@{
        Name = "confidential_keyword"
        Pattern = "\b(confidential|internal use only|restricted)\b"
        Severity = "medium"
    },
    [pscustomobject]@{
        Name = "aws_access_key"
        Pattern = "\bAKIA[0-9A-Z]{16}\b"
        Severity = "high"
    },
    [pscustomobject]@{
        Name = "database_password"
        Pattern = "\b(db_password|database_password|password)\s*[:=]\s*['""]?[^'""]{8,}['""]?"
        Severity = "high"
    }
)

$script:FileNameRules = @(
    [pscustomobject]@{
        Name = "sensitive_filename"
        Pattern = "(ssn|social|payroll|password|secret|confidential|restricted|pii)"
        Severity = "medium"
    }
)

$script:SeverityScore = @{
    "low" = 1
    "medium" = 2
    "high" = 3
}

function Add-DlpOutput {
    param(
        [string]$Message
    )

    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Host $line

    if ($script:DlpOutputBox -ne $null) {
        $script:DlpOutputBox.AppendText("$line`r`n")
    }
}

function Initialize-DlpLabFolders {
    New-Item -ItemType Directory -Force -Path $script:DlpRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $script:DlpTarget | Out-Null
    New-Item -ItemType Directory -Force -Path $script:DlpAlerts | Out-Null
    New-Item -ItemType Directory -Force -Path $script:DlpState | Out-Null

    Add-DlpOutput "DLP folders are ready."
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-SimpleDocxFile {
    param(
        [string]$Path,
        [string]$Text
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    $tempRoot = Join-Path $env:TEMP ("dlp_docx_" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot "_rels") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot "word") | Out-Null

    $contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'@

    $rels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@

    $paragraphs = ""
    foreach ($line in ($Text -split "`r?`n")) {
        $safeLine = [System.Security.SecurityElement]::Escape($line)
        $paragraphs += "<w:p><w:r><w:t>$safeLine</w:t></w:r></w:p>"
    }

    $documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $paragraphs
  </w:body>
</w:document>
"@

    Set-Content -Path (Join-Path $tempRoot "[Content_Types].xml") -Value $contentTypes -Encoding UTF8
    Set-Content -Path (Join-Path $tempRoot "_rels\.rels") -Value $rels -Encoding UTF8
    Set-Content -Path (Join-Path $tempRoot "word\document.xml") -Value $documentXml -Encoding UTF8

    if (Test-Path $Path) {
        Remove-Item $Path -Force
    }

    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempRoot, $Path)
    Remove-Item $tempRoot -Recurse -Force
}

function New-DlpTestImage {
    param(
        [string]$Path,
        [string]$Text
    )

    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $bitmap = New-Object System.Drawing.Bitmap 1000, 250
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::White)

        $font = New-Object System.Drawing.Font("Arial", 24)
        $brush = [System.Drawing.Brushes]::Black

        $graphics.DrawString($Text, $font, $brush, 20, 50)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)

        $graphics.Dispose()
        $bitmap.Dispose()

        Add-DlpOutput "Created test image: $Path"
    }
    catch {
        Add-DlpOutput "Could not create test image: $($_.Exception.Message)"
    }
}

function New-DlpSampleFiles {
    param(
        [string]$TargetPath = $script:DlpTarget
    )

    Initialize-DlpLabFolders

    New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null

@"
Employee: John Smith
SSN: 123-45-6789
Classification: Confidential
"@ | Set-Content -Path (Join-Path $TargetPath "employee_record.txt") -Encoding UTF8

@"
Customer payment test
Card: 4111-1111-1111-1111
Restricted payment information.
"@ | Set-Content -Path (Join-Path $TargetPath "payment_data.txt") -Encoding UTF8

@"
api_key = "ABCD1234SECRETKEY9999"
token: mytokenvalue1234567890
"@ | Set-Content -Path (Join-Path $TargetPath "api_config.txt") -Encoding UTF8

@"
QA test data only.
Fake SSN: 123-45-6789
This is not real customer data.
"@ | Set-Content -Path (Join-Path $TargetPath "false_positive_test.txt") -Encoding UTF8

@"
AWS key found during review:
AKIA1234567890ABCDEF
database_password = "SuperSecretPassword123"
"@ | Set-Content -Path (Join-Path $TargetPath "false_negative_secret.txt") -Encoding UTF8

@"
This is a normal helpdesk note.
No sensitive data here.
"@ | Set-Content -Path (Join-Path $TargetPath "clean_notes.txt") -Encoding UTF8

    $docxText = @"
HR document
Employee: Jane Doe
SSN: 222-33-4444
Internal use only
"@

    New-SimpleDocxFile -Path (Join-Path $TargetPath "employee_pii_document.docx") -Text $docxText

    New-DlpTestImage -Path (Join-Path $TargetPath "pii_screenshot.png") -Text "Fake PII Screenshot - SSN 555-66-7777 - Confidential"

    Add-DlpOutput "Sample DLP files created in: $TargetPath"
}

function Get-PlainTextFromFile {
    param(
        [System.IO.FileInfo]$File
    )

    try {
        return Get-Content -Path $File.FullName -Raw -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        try {
            return Get-Content -Path $File.FullName -Raw -ErrorAction Stop
        }
        catch {
            Add-DlpOutput "Could not read file: $($File.FullName)"
            return ""
        }
    }
}

function Get-DocxText {
    param(
        [System.IO.FileInfo]$File
    )

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        $zip = [System.IO.Compression.ZipFile]::OpenRead($File.FullName)
        $entry = $zip.Entries | Where-Object { $_.FullName -eq "word/document.xml" } | Select-Object -First 1

        if ($entry -eq $null) {
            $zip.Dispose()
            return ""
        }

        $stream = $entry.Open()
        $reader = New-Object System.IO.StreamReader($stream)
        $xml = $reader.ReadToEnd()

        $reader.Close()
        $stream.Close()
        $zip.Dispose()

        $text = $xml -replace "<[^>]+>", " "
        $text = [System.Net.WebUtility]::HtmlDecode($text)
        return $text
    }
    catch {
        Add-DlpOutput "Could not read DOCX: $($File.FullName)"
        return ""
    }
}

function Get-ImageTextWithTesseract {
    param(
        [System.IO.FileInfo]$File
    )

    $tesseract = Get-Command "tesseract.exe" -ErrorAction SilentlyContinue

    if ($tesseract -eq $null) {
        return ""
    }

    try {
        $outputBase = Join-Path $env:TEMP ("dlp_ocr_" + [guid]::NewGuid().ToString())
        & $tesseract.Source $File.FullName $outputBase --psm 6 2>$null | Out-Null

        $ocrTextFile = "$outputBase.txt"

        if (Test-Path $ocrTextFile) {
            $text = Get-Content -Path $ocrTextFile -Raw -ErrorAction SilentlyContinue
            Remove-Item $ocrTextFile -Force -ErrorAction SilentlyContinue
            return $text
        }

        return ""
    }
    catch {
        Add-DlpOutput "OCR failed for image: $($File.FullName)"
        return ""
    }
}

function Get-ContentForDlpScan {
    param(
        [System.IO.FileInfo]$File
    )

    $extension = $File.Extension.ToLower()

    if ($script:TextExtensions -contains $extension) {
        return [pscustomobject]@{
            Text = Get-PlainTextFromFile -File $File
            SourceType = "text"
        }
    }

    if ($script:DocxExtensions -contains $extension) {
        return [pscustomobject]@{
            Text = Get-DocxText -File $File
            SourceType = "docx"
        }
    }

    if ($script:ImageExtensions -contains $extension) {
        $ocrText = Get-ImageTextWithTesseract -File $File

        if ([string]::IsNullOrWhiteSpace($ocrText)) {
            return [pscustomobject]@{
                Text = ""
                SourceType = "image_no_ocr"
            }
        }

        return [pscustomobject]@{
            Text = $ocrText
            SourceType = "image_ocr"
        }
    }

    return [pscustomobject]@{
        Text = ""
        SourceType = "unsupported"
    }
}

function Test-DlpExcludedContent {
    param(
        [string]$Content
    )

    foreach ($keyword in $script:ExclusionKeywords) {
        if ($Content.ToLower().Contains($keyword.ToLower())) {
            return $true
        }
    }

    return $false
}

function Get-FileSha256 {
    param(
        [System.IO.FileInfo]$File
    )

    try {
        return (Get-FileHash -Path $File.FullName -Algorithm SHA256).Hash
    }
    catch {
        return ""
    }
}

function Get-HighestSeverity {
    param(
        [array]$Alerts
    )

    if ($Alerts.Count -eq 0) {
        return "none"
    }

    $highest = "low"

    foreach ($alert in $Alerts) {
        if ($script:SeverityScore[$alert.severity] -gt $script:SeverityScore[$highest]) {
            $highest = $alert.severity
        }
    }

    return $highest
}

function Set-DlpClassificationStream {
    param(
        [System.IO.FileInfo]$File,
        [string]$Classification
    )

    try {
        Set-Content -Path $File.FullName -Stream "classification" -Value $Classification -Force -ErrorAction Stop
    }
    catch {
        Add-DlpOutput "Could not set classification stream on: $($File.FullName)"
    }
}

function New-DlpAlertObject {
    param(
        [System.IO.FileInfo]$File,
        [string]$MatchType,
        [string]$Severity,
        [int]$MatchCount,
        [string]$SourceType,
        [string]$FileHash
    )

    return [pscustomobject]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        scanner = "windows_powershell_dlp_scanner"
        host = $env:COMPUTERNAME
        file_path = $File.FullName
        file_name = $File.Name
        match_type = $MatchType
        severity = $Severity
        classification = $Severity
        match_count = $MatchCount
        source_type = $SourceType
        file_hash_sha256 = $FileHash
    }
}

function Invoke-DlpFileScan {
    param(
        [System.IO.FileInfo]$File
    )

    $alerts = @()
    $fileHash = Get-FileSha256 -File $File

    foreach ($fileNameRule in $script:FileNameRules) {
        $fileNameMatches = [regex]::Matches($File.Name, $fileNameRule.Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($fileNameMatches.Count -gt 0) {
            $alerts += New-DlpAlertObject `
                -File $File `
                -MatchType $fileNameRule.Name `
                -Severity $fileNameRule.Severity `
                -MatchCount $fileNameMatches.Count `
                -SourceType "filename" `
                -FileHash $fileHash
        }
    }

    $contentResult = Get-ContentForDlpScan -File $File
    $content = $contentResult.Text
    $sourceType = $contentResult.SourceType

    if ($sourceType -eq "unsupported") {
        return $alerts
    }

    if ([string]::IsNullOrWhiteSpace($content)) {
        return $alerts
    }

    if (Test-DlpExcludedContent -Content $content) {
        return @()
    }

    foreach ($rule in $script:DlpRules) {
        $matches = [regex]::Matches($content, $rule.Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($matches.Count -gt 0) {
            $alerts += New-DlpAlertObject `
                -File $File `
                -MatchType $rule.Name `
                -Severity $rule.Severity `
                -MatchCount $matches.Count `
                -SourceType $sourceType `
                -FileHash $fileHash
        }
    }

    if ($alerts.Count -gt 0) {
        $classification = Get-HighestSeverity -Alerts $alerts
        Set-DlpClassificationStream -File $File -Classification $classification
    }

    return $alerts
}

function Get-DlpState {
    $seen = @{}

    if (Test-Path $script:DlpStateFile) {
        try {
            $state = Get-Content -Path $script:DlpStateFile -Raw | ConvertFrom-Json

            if ($state.seen_findings -ne $null) {
                foreach ($prop in $state.seen_findings.PSObject.Properties) {
                    $seen[$prop.Name] = $prop.Value
                }
            }
        }
        catch {
            $seen = @{}
        }
    }

    return $seen
}

function Save-DlpState {
    param(
        [hashtable]$SeenFindings
    )

    New-Item -ItemType Directory -Force -Path $script:DlpState | Out-Null

    $state = [pscustomobject]@{
        seen_findings = $SeenFindings
    }

    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $script:DlpStateFile -Encoding UTF8
}

function New-DlpFingerprint {
    param(
        [pscustomobject]$Alert
    )

    $raw = "$($Alert.file_path)|$($Alert.file_hash_sha256)|$($Alert.match_type)"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)

    return ([BitConverter]::ToString($hashBytes)).Replace("-", "")
}

function Save-DlpAlerts {
    param(
        [array]$Alerts
    )

    New-Item -ItemType Directory -Force -Path $script:DlpAlerts | Out-Null

    $Alerts | ConvertTo-Json -Depth 8 | Set-Content -Path $script:DlpJson -Encoding UTF8

    $seen = Get-DlpState
    $newCount = 0

    foreach ($alert in $Alerts) {
        $fingerprint = New-DlpFingerprint -Alert $alert

        if (-not $seen.ContainsKey($fingerprint)) {
            $alert | Add-Member -NotePropertyName "fingerprint" -NotePropertyValue $fingerprint -Force
            ($alert | ConvertTo-Json -Compress -Depth 8) | Add-Content -Path $script:DlpJsonl -Encoding UTF8
            $seen[$fingerprint] = (Get-Date).ToUniversalTime().ToString("o")
            $newCount++
        }
    }

    Save-DlpState -SeenFindings $seen

    return $newCount
}

function Invoke-DlpScan {
    param(
        [string]$TargetPath = $script:DlpTarget
    )

    Initialize-DlpLabFolders

    if (-not (Test-Path $TargetPath)) {
        Add-DlpOutput "Target path does not exist: $TargetPath"
        return
    }

    Add-DlpOutput "Starting DLP scan: $TargetPath"

    $allAlerts = @()
    $files = Get-ChildItem -Path $TargetPath -File -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        if ($file.Name.EndsWith(".gpg")) {
            continue
        }

        $fileAlerts = Invoke-DlpFileScan -File $file

        if ($fileAlerts.Count -gt 0) {
            $allAlerts += $fileAlerts
        }
    }

    $newCount = Save-DlpAlerts -Alerts $allAlerts

    Add-DlpOutput "Completed DLP scan."
    Add-DlpOutput "Total findings in latest scan: $($allAlerts.Count)"
    Add-DlpOutput "New JSONL alerts for Wazuh: $newCount"
    Add-DlpOutput "Alert JSON: $script:DlpJson"
    Add-DlpOutput "Alert JSONL: $script:DlpJsonl"

    $tesseract = Get-Command "tesseract.exe" -ErrorAction SilentlyContinue

    if ($tesseract -eq $null) {
        Add-DlpOutput "Image OCR note: Tesseract is not installed, so image text was not scanned."
    }
    else {
        Add-DlpOutput "Image OCR enabled using: $($tesseract.Source)"
    }
}

function Reset-DlpAlertsAndState {
    Remove-Item $script:DlpJson -Force -ErrorAction SilentlyContinue
    Remove-Item $script:DlpJsonl -Force -ErrorAction SilentlyContinue
    Remove-Item $script:DlpStateFile -Force -ErrorAction SilentlyContinue

    Add-DlpOutput "DLP alert files and state were reset."
}

function Open-DlpAlertsFolder {
    Initialize-DlpLabFolders
    Start-Process explorer.exe $script:DlpAlerts
}

function Add-DlpWazuhLocalfile {
    if (-not (Test-IsAdmin)) {
        Add-DlpOutput "Run PowerShell as Administrator to modify Wazuh config."
        return
    }

    $wazuhConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    if (-not (Test-Path $wazuhConf)) {
        Add-DlpOutput "Wazuh agent config not found: $wazuhConf"
        return
    }

    $content = Get-Content -Path $wazuhConf -Raw

    if ($content -like "*$script:DlpJsonl*") {
        Add-DlpOutput "Wazuh is already configured to monitor the DLP JSONL file."
        return
    }

    $backup = "$wazuhConf.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $wazuhConf $backup -Force

    $localfileBlock = @"

  <localfile>
    <log_format>json</log_format>
    <location>$script:DlpJsonl</location>
  </localfile>
"@

    if ($content -match "</ossec_config>") {
        $newContent = $content -replace "</ossec_config>", "$localfileBlock`r`n</ossec_config>"
        Set-Content -Path $wazuhConf -Value $newContent -Encoding UTF8
        Add-DlpOutput "Added DLP JSONL monitoring to Wazuh agent config."
        Add-DlpOutput "Backup created: $backup"
    }
    else {
        Add-DlpOutput "Could not find </ossec_config>. Wazuh config was not changed."
    }
}

function Restart-WazuhAgentService {
    if (-not (Test-IsAdmin)) {
        Add-DlpOutput "Run PowerShell as Administrator to restart Wazuh."
        return
    }

    try {
        Restart-Service -Name "WazuhSvc" -Force -ErrorAction Stop
        Add-DlpOutput "Wazuh agent service restarted."
    }
    catch {
        Add-DlpOutput "Could not restart WazuhSvc: $($_.Exception.Message)"
    }
}

function Install-DlpScheduledTask {
    param(
        [string]$TargetPath = $script:DlpTarget
    )

    if (-not (Test-IsAdmin)) {
        Add-DlpOutput "Run PowerShell as Administrator to install scheduled task."
        return
    }

    Initialize-DlpLabFolders

    $installedScript = Join-Path $script:DlpRoot "Start-WindowsDLP-GUI.ps1"

    if ($PSCommandPath) {
        Copy-Item $PSCommandPath $installedScript -Force
    }

    if (-not (Test-Path $installedScript)) {
        Add-DlpOutput "Could not install scheduled task because script copy was not found."
        return
    }

    $taskName = "Windows DLP Scanner Lab"

    $argument = "-ExecutionPolicy Bypass -File `"$installedScript`" -NoGui -RunScan -ScanPath `"$TargetPath`""

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument $argument

    $trigger = New-ScheduledTaskTrigger `
        -Once `
        -At (Get-Date).AddMinutes(1) `
        -RepetitionInterval (New-TimeSpan -Minutes 5) `
        -RepetitionDuration (New-TimeSpan -Days 3650)

    $principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Force | Out-Null

    Add-DlpOutput "Scheduled task installed: $taskName"
    Add-DlpOutput "The scanner will run every 5 minutes."
}

function Show-DlpWindow {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    Initialize-DlpLabFolders

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Windows DLP Lab Scanner"
    $form.Size = New-Object System.Drawing.Size(850, 620)
    $form.StartPosition = "CenterScreen"

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Scan Folder:"
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(100, 25)
    $form.Controls.Add($label)

    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Text = $script:DlpTarget
    $txtPath.Location = New-Object System.Drawing.Point(120, 18)
    $txtPath.Size = New-Object System.Drawing.Size(560, 25)
    $form.Controls.Add($txtPath)

    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "Browse"
    $btnBrowse.Location = New-Object System.Drawing.Point(690, 16)
    $btnBrowse.Size = New-Object System.Drawing.Size(120, 30)
    $btnBrowse.Add_Click({
        $browser = New-Object System.Windows.Forms.FolderBrowserDialog
        $browser.Description = "Choose a folder to scan for DLP findings"

        if ($browser.ShowDialog() -eq "OK") {
            $txtPath.Text = $browser.SelectedPath
        }
    })
    $form.Controls.Add($btnBrowse)

    $btnCreateSamples = New-Object System.Windows.Forms.Button
    $btnCreateSamples.Text = "Create Test Files"
    $btnCreateSamples.Location = New-Object System.Drawing.Point(20, 65)
    $btnCreateSamples.Size = New-Object System.Drawing.Size(160, 35)
    $btnCreateSamples.Add_Click({
        New-DlpSampleFiles -TargetPath $txtPath.Text
    })
    $form.Controls.Add($btnCreateSamples)

    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = "Run DLP Scan"
    $btnScan.Location = New-Object System.Drawing.Point(190, 65)
    $btnScan.Size = New-Object System.Drawing.Size(160, 35)
    $btnScan.Add_Click({
        Invoke-DlpScan -TargetPath $txtPath.Text
    })
    $form.Controls.Add($btnScan)

    $btnOpenAlerts = New-Object System.Windows.Forms.Button
    $btnOpenAlerts.Text = "Open Alerts"
    $btnOpenAlerts.Location = New-Object System.Drawing.Point(360, 65)
    $btnOpenAlerts.Size = New-Object System.Drawing.Size(140, 35)
    $btnOpenAlerts.Add_Click({
        Open-DlpAlertsFolder
    })
    $form.Controls.Add($btnOpenAlerts)

    $btnReset = New-Object System.Windows.Forms.Button
    $btnReset.Text = "Reset Alerts"
    $btnReset.Location = New-Object System.Drawing.Point(510, 65)
    $btnReset.Size = New-Object System.Drawing.Size(140, 35)
    $btnReset.Add_Click({
        Reset-DlpAlertsAndState
    })
    $form.Controls.Add($btnReset)

    $btnTask = New-Object System.Windows.Forms.Button
    $btnTask.Text = "Install 5-Min Task"
    $btnTask.Location = New-Object System.Drawing.Point(660, 65)
    $btnTask.Size = New-Object System.Drawing.Size(150, 35)
    $btnTask.Add_Click({
        Install-DlpScheduledTask -TargetPath $txtPath.Text
    })
    $form.Controls.Add($btnTask)

    $btnWazuh = New-Object System.Windows.Forms.Button
    $btnWazuh.Text = "Add Wazuh Monitor"
    $btnWazuh.Location = New-Object System.Drawing.Point(20, 110)
    $btnWazuh.Size = New-Object System.Drawing.Size(180, 35)
    $btnWazuh.Add_Click({
        Add-DlpWazuhLocalfile
    })
    $form.Controls.Add($btnWazuh)

    $btnRestartWazuh = New-Object System.Windows.Forms.Button
    $btnRestartWazuh.Text = "Restart Wazuh Agent"
    $btnRestartWazuh.Location = New-Object System.Drawing.Point(210, 110)
    $btnRestartWazuh.Size = New-Object System.Drawing.Size(180, 35)
    $btnRestartWazuh.Add_Click({
        Restart-WazuhAgentService
    })
    $form.Controls.Add($btnRestartWazuh)

    $btnOpenTarget = New-Object System.Windows.Forms.Button
    $btnOpenTarget.Text = "Open Scan Folder"
    $btnOpenTarget.Location = New-Object System.Drawing.Point(400, 110)
    $btnOpenTarget.Size = New-Object System.Drawing.Size(170, 35)
    $btnOpenTarget.Add_Click({
        if (Test-Path $txtPath.Text) {
            Start-Process explorer.exe $txtPath.Text
        }
    })
    $form.Controls.Add($btnOpenTarget)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"
    $btnClose.Location = New-Object System.Drawing.Point(660, 110)
    $btnClose.Size = New-Object System.Drawing.Size(150, 35)
    $btnClose.Add_Click({
        $form.Close()
    })
    $form.Controls.Add($btnClose)

    $script:DlpOutputBox = New-Object System.Windows.Forms.TextBox
    $script:DlpOutputBox.Multiline = $true
    $script:DlpOutputBox.ScrollBars = "Vertical"
    $script:DlpOutputBox.ReadOnly = $true
    $script:DlpOutputBox.Location = New-Object System.Drawing.Point(20, 165)
    $script:DlpOutputBox.Size = New-Object System.Drawing.Size(790, 370)
    $form.Controls.Add($script:DlpOutputBox)

    Add-DlpOutput "Windows DLP GUI ready."
    Add-DlpOutput "Pick a folder, create test files, then run the scan."
    Add-DlpOutput "Wazuh JSONL path: $script:DlpJsonl"

    [void]$form.ShowDialog()
}

if ($RunScan) {
    Invoke-DlpScan -TargetPath $ScanPath
    exit
}

if (-not $NoGui) {
    Show-DlpWindow
}
