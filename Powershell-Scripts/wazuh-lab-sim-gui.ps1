# Wazuh Lab Simulator GUI
# Safe detection-testing only

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$LabRoot = "C:\WazuhLab"
$PiiPath = "$LabRoot\PII"
$ExePath = "$LabRoot\TestTools"
$FimPath = "$LabRoot\FIM"

function Write-Log {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $StatusBox.AppendText("[$Time] $Message`r`n")
}

function Ensure-LabFolders {
    New-Item -ItemType Directory -Path $LabRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $PiiPath -Force | Out-Null
    New-Item -ItemType Directory -Path $ExePath -Force | Out-Null
    New-Item -ItemType Directory -Path $FimPath -Force | Out-Null
}

function Create-Custom-PII {
    Ensure-LabFolders

    $Name = $TextName.Text
    $DOB = $TextDOB.Text
    $SSN = $TextSSN.Text
        $Password = $TextPassword.Text
    $Card = $TextCard.Text
    $FileName = $TextFileName.Text
    $Extension = $DropExtension.SelectedItem

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        $FileName = "custom_pii"
    }

    if ($null -eq $Extension) {
        $Extension = "txt"
    }

    $File = "$PiiPath\$FileName.$Extension"

@"
Employee: $Name
Date of Birth: $DOB
SSN: $SSN
Password: $Password
Credit Card: $Card
Created: $(Get-Date)
"@ | Out-File -FilePath $File -Encoding UTF8

    Write-Log "Created custom PII file: $File"
}

function Generate-Random-PII {
    $FirstNames = @("John", "Mary", "Alex", "Sarah", "David", "Lisa")
    $LastNames = @("Test", "Sample", "Demo", "User", "Employee")

    $RandomName = "$(Get-Random $FirstNames) $(Get-Random $LastNames)"
    $RandomDOB = Get-Date -Year (Get-Random -Minimum 1950 -Maximum 2005) -Month (Get-Random -Minimum 1 -Maximum 13) -Day (Get-Random -Minimum 1 -Maximum 29)
    $RandomSSN = "{0:000}-{1:00}-{2:0000}" -f (Get-Random -Minimum 100 -Maximum 999), (Get-Random -Minimum 10 -Maximum 99), (Get-Random -Minimum 1000 -Maximum 9999)
    $RandomPassword = "TestPass$(Get-Random -Minimum 1000 -Maximum 9999)!"
    $RandomCard = "4111-1111-1111-$(Get-Random -Minimum 1000 -Maximum 9999)"

    $TextName.Text = $RandomName
    $TextDOB.Text = $RandomDOB.ToString("MM/dd/yyyy")
    $TextSSN.Text = $RandomSSN
    $TextPassword.Text = $RandomPassword
    $TextCard.Text = $RandomCard
    $TextFileName.Text = "random_pii_$(Get-Random -Minimum 100 -Maximum 999)"

    Write-Log "Generated random fake PII values."
}

function Create-Realistic-Business-PII {

    Ensure-LabFolders

    $Departments = @(
        "finance",
        "hr",
        "sales",
        "operations",
        "benefits",
        "vendor",
        "client",
        "audit"
    )

    $FileTypes = @(
        "export",
        "sync",
        "review",
        "cache",
        "backup",
        "notes",
        "records",
        "update"
    )

    $Extensions = @("txt","csv","log","rtf","tmp")

    $FirstNames = @(
        "John",
        "Mary",
        "Alex",
        "Sarah",
        "David",
        "Lisa",
        "Chris",
        "Taylor"
    )

    $LastNames = @(
        "Smith",
        "Johnson",
        "Brown",
        "Davis",
        "Wilson",
        "Taylor"
    )

    $Department = Get-Random $Departments
    $FileType = Get-Random $FileTypes
    $Extension = Get-Random $Extensions

    $RandomName = "$(Get-Random $FirstNames) $(Get-Random $LastNames)"

    $RandomDOB = Get-Date `
        -Year (Get-Random -Minimum 1950 -Maximum 2005) `
        -Month (Get-Random -Minimum 1 -Maximum 13) `
        -Day (Get-Random -Minimum 1 -Maximum 29)

    $RandomSSN = "{0:000}-{1:00}-{2:0000}" -f `
        (Get-Random -Minimum 100 -Maximum 999),
        (Get-Random -Minimum 10 -Maximum 99),
        (Get-Random -Minimum 1000 -Maximum 9999)

    $RandomPassword = "TempPass$(Get-Random -Minimum 1000 -Maximum 9999)!"

    $RandomCard = "4111-1111-1111-$(Get-Random -Minimum 1000 -Maximum 9999)"

    $FileName = "$Department`_$FileType`_$(Get-Random -Minimum 1000 -Maximum 9999).$Extension"

    $File = "$PiiPath\$FileName"

@"
Business Export Record
Department: $Department
Record Type: $FileType

Employee/Client: $RandomName
Date of Birth: $($RandomDOB.ToString("MM/dd/yyyy"))
SSN: $RandomSSN

Account Note: Password reset issued
Temporary Password: $RandomPassword

Payment Card: $RandomCard

Created: $(Get-Date)
"@ | Out-File -FilePath $File -Encoding UTF8

    Write-Log "Created realistic business PII file: $File"
}


function Create-PII-Txt {
    Ensure-LabFolders
    $File = "$PiiPath\payroll_login.txt"

@"
Employee: John Test
Date of Birth: 01/01/1901
SSN: 123-45-6789
Password: Abc123!
Credit Card: 4111-1111-1111-1111
"@ | Out-File -FilePath $File -Encoding UTF8

    Write-Log "Created PII TXT test file: $File"
}

function Create-PII-RTF {
    Ensure-LabFolders
    $File = "$PiiPath\employee_record.rtf"

@"
{\rtf1\ansi
\b Employee Record\b0\line
Name: John Test\line
Date of Birth: $($TextDOB.Text)\line
SSN: 123-45-6789\line
Password: Abc123!\line
Credit Card: 4111-1111-1111-1111\line
}
"@ | Out-File -FilePath $File -Encoding ASCII

    Write-Log "Created Word-style RTF PII file: $File"
}

function Create-Fake-Exe {
    Ensure-LabFolders
    $File = "$ExePath\invoice_update.exe"

    "FAKE EXE FOR WAZUH FIM TEST ONLY - NOT EXECUTABLE" |
        Out-File -FilePath $File -Encoding ASCII

    Write-Log "Created harmless fake EXE test file: $File"
}

function Modify-FIM-TestFile {
    Ensure-LabFolders
    $File = "$FimPath\watched_file.txt"
    "FIM test modified at $(Get-Date)" | Out-File -FilePath $File -Append -Encoding UTF8
    Write-Log "Modified FIM test file: $File"
}

function Run-Safe-PowerShell-Test {
    Write-Output "Wazuh safe PowerShell test event at $(Get-Date)"
    Write-Log "Ran safe PowerShell test command."
}

function Simulate-Random-Lab-Event {
    $Choice = Get-Random -Minimum 1 -Maximum 5

    switch ($Choice) {
        1 { Create-PII-Txt }
        2 { Create-PII-RTF }
        3 { Create-Fake-Exe }
        4 { Modify-FIM-TestFile }
    }

    Write-Log "Random lab event simulation completed."
}

function Check-Wazuh-Agent {
    $Service = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue

    if ($null -eq $Service) {
        Write-Log "Wazuh service not found."
    }
    else {
        Write-Log "Wazuh service status: $($Service.Status)"
    }
}

function Restart-Wazuh-Agent {
    $Service = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue

    if ($null -eq $Service) {
        Write-Log "Wazuh service not found."
        return
    }

    Restart-Service -Name "WazuhSvc" -Force
    Write-Log "Restarted Wazuh agent service."
}

function Clear-Test-Files {
    if (Test-Path $LabRoot) {
        Remove-Item $LabRoot -Recurse -Force
        Write-Log "Cleared test folder: $LabRoot"
    }
    else {
        Write-Log "No test files found."
    }
}

# GUI

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Wazuh Lab Simulator GUI"
$Form.Size = New-Object System.Drawing.Size(760, 760)
$Form.StartPosition = "CenterScreen"

$Title = New-Object System.Windows.Forms.Label
$Title.Text = "Wazuh Lab Event Simulator"
$Title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$Title.Location = New-Object System.Drawing.Point(20, 15)
$Title.Size = New-Object System.Drawing.Size(500, 35)
$Form.Controls.Add($Title)

$SubTitle = New-Object System.Windows.Forms.Label
$SubTitle.Text = "Safe lab actions for FIM, PII, fake EXE, and PowerShell detection testing."
$SubTitle.Location = New-Object System.Drawing.Point(22, 55)
$SubTitle.Size = New-Object System.Drawing.Size(700, 25)
$Form.Controls.Add($SubTitle)

# Input labels and boxes

###### Employee Name ######
$LabelName = New-Object System.Windows.Forms.Label
$LabelName.Text = "Employee Name"
$LabelName.Location = New-Object System.Drawing.Point(25, 95)
$LabelName.Size = New-Object System.Drawing.Size(120, 20)
$Form.Controls.Add($LabelName)

$TextName = New-Object System.Windows.Forms.TextBox
$TextName.Location = New-Object System.Drawing.Point(150, 92)
$TextName.Size = New-Object System.Drawing.Size(200, 22)
$Form.Controls.Add($TextName)

###### Date of Birth ######
$LabelDOB = New-Object System.Windows.Forms.Label
$LabelDOB.Text = "Date of Birth"
$LabelDOB.Location = New-Object System.Drawing.Point(25, 215)
$LabelDOB.Size = New-Object System.Drawing.Size(120, 20)
$Form.Controls.Add($LabelDOB)

$TextDOB = New-Object System.Windows.Forms.TextBox
$TextDOB.Location = New-Object System.Drawing.Point(150, 212)
$TextDOB.Size = New-Object System.Drawing.Size(200, 22)
$Form.Controls.Add($TextDOB)

###### SSN ######
$LabelSSN = New-Object System.Windows.Forms.Label
$LabelSSN.Text = "SSN"
$LabelSSN.Location = New-Object System.Drawing.Point(25, 125)
$LabelSSN.Size = New-Object System.Drawing.Size(120, 20)
$Form.Controls.Add($LabelSSN)

$TextSSN = New-Object System.Windows.Forms.TextBox
$TextSSN.Location = New-Object System.Drawing.Point(150, 122)
$TextSSN.Size = New-Object System.Drawing.Size(200, 22)
$Form.Controls.Add($TextSSN)

###### Password ######
$LabelPassword = New-Object System.Windows.Forms.Label
$LabelPassword.Text = "Password"
$LabelPassword.Location = New-Object System.Drawing.Point(25, 155)
$LabelPassword.Size = New-Object System.Drawing.Size(120, 20)
$Form.Controls.Add($LabelPassword)

$TextPassword = New-Object System.Windows.Forms.TextBox
$TextPassword.Location = New-Object System.Drawing.Point(150, 152)
$TextPassword.Size = New-Object System.Drawing.Size(200, 22)
$Form.Controls.Add($TextPassword)

$LabelCard = New-Object System.Windows.Forms.Label
$LabelCard.Text = "Credit Card"
$LabelCard.Location = New-Object System.Drawing.Point(25, 185)
$LabelCard.Size = New-Object System.Drawing.Size(120, 20)
$Form.Controls.Add($LabelCard)

$TextCard = New-Object System.Windows.Forms.TextBox
$TextCard.Location = New-Object System.Drawing.Point(150, 182)
$TextCard.Size = New-Object System.Drawing.Size(200, 22)
$Form.Controls.Add($TextCard)

$LabelFileName = New-Object System.Windows.Forms.Label
$LabelFileName.Text = "Filename"
$LabelFileName.Location = New-Object System.Drawing.Point(380, 95)
$LabelFileName.Size = New-Object System.Drawing.Size(100, 20)
$Form.Controls.Add($LabelFileName)

$TextFileName = New-Object System.Windows.Forms.TextBox
$TextFileName.Location = New-Object System.Drawing.Point(485, 92)
$TextFileName.Size = New-Object System.Drawing.Size(180, 22)
$TextFileName.Text = "custom_pii"
$Form.Controls.Add($TextFileName)

$LabelExtension = New-Object System.Windows.Forms.Label
$LabelExtension.Text = "Extension"
$LabelExtension.Location = New-Object System.Drawing.Point(380, 125)
$LabelExtension.Size = New-Object System.Drawing.Size(100, 20)
$Form.Controls.Add($LabelExtension)

$DropExtension = New-Object System.Windows.Forms.ComboBox
$DropExtension.Location = New-Object System.Drawing.Point(485, 122)
$DropExtension.Size = New-Object System.Drawing.Size(180, 22)
$DropExtension.Items.AddRange(@("txt", "rtf", "csv", "log"))
$DropExtension.SelectedItem = "txt"
$Form.Controls.Add($DropExtension)

function New-GuiButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [scriptblock]$Action
    )

    $Button = New-Object System.Windows.Forms.Button
    $Button.Text = $Text
    $Button.Location = New-Object System.Drawing.Point($X, $Y)
    $Button.Size = New-Object System.Drawing.Size(200, 40)
    $Button.Add_Click($Action)
    $Form.Controls.Add($Button)
}

New-GuiButton "Generate Random PII" 380 155 { Generate-Random-PII }
New-GuiButton "Create Custom PII File" 380 205 { Create-Custom-PII }

New-GuiButton "Create Realistic Business File" 25 245 { Create-Realistic-Business-PII }
New-GuiButton "Create Default PII TXT" 245 245 { Create-PII-Txt }
New-GuiButton "Create Default PII RTF" 465 245 { Create-PII-RTF }

New-GuiButton "Create Fake EXE File" 25 300 { Create-Fake-Exe }
New-GuiButton "Modify FIM Test File" 245 300 { Modify-FIM-TestFile }
New-GuiButton "Safe PowerShell Test" 465 300 { Run-Safe-PowerShell-Test }

New-GuiButton "Random Lab Event" 25 355 { Simulate-Random-Lab-Event }
New-GuiButton "Check Wazuh Agent" 245 355 { Check-Wazuh-Agent }
New-GuiButton "Restart Wazuh Agent" 465 355 { Restart-Wazuh-Agent }

New-GuiButton "Clear Test Files" 245 410 { Clear-Test-Files }

$StatusBox = New-Object System.Windows.Forms.TextBox
$StatusBox.Location = New-Object System.Drawing.Point(25, 470)
$StatusBox.Size = New-Object System.Drawing.Size(685, 120)
$StatusBox.Multiline = $true
$StatusBox.ScrollBars = "Vertical"
$StatusBox.ReadOnly = $true
$Form.Controls.Add($StatusBox)

$ExitButton = New-Object System.Windows.Forms.Button
$ExitButton.Text = "Exit"
$ExitButton.Location = New-Object System.Drawing.Point(610, 610)
$ExitButton.Size = New-Object System.Drawing.Size(100, 30)
$ExitButton.Add_Click({ $Form.Close() })
$Form.Controls.Add($ExitButton)

Write-Log "GUI loaded. Lab root: $LabRoot"

[void]$Form.ShowDialog()
