# ============================================================
# Create-ADLabUser-GUI.ps1
# Lab GUI for creating Active Directory users
# Generates Windows Security Event ID 4720 for Wazuh detection
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ----------------------------
# Section 1 - Load AD module
# ----------------------------
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "ActiveDirectory PowerShell module was not found.`n`nRun this on a Domain Controller or install RSAT.",
        "Missing AD Module",
        "OK",
        "Error"
    )
    exit
}

# ----------------------------
# Section 2 - Get domain info
# ----------------------------
try {
    $Domain = Get-ADDomain
    $DefaultUPNSuffix = $Domain.DNSRoot
    $DefaultUserPath = "CN=Users,$($Domain.DistinguishedName)"
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Could not read Active Directory domain info.`n`nMake sure you are domain joined and have permission.",
        "AD Error",
        "OK",
        "Error"
    )
    exit
}

# ----------------------------
# Section 3 - Main form
# ----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "AD Lab User Creator - Wazuh Test"
$form.Size = New-Object System.Drawing.Size(560, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "Create AD Lab User for Wazuh Detection"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(25, 20)
$form.Controls.Add($title)

# ----------------------------
# Section 4 - Helper function
# ----------------------------
function Add-LabelAndTextBox {
    param (
        [string]$LabelText,
        [int]$Y,
        [string]$DefaultText = ""
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $LabelText
    $label.Location = New-Object System.Drawing.Point(25, $Y)
    $label.Size = New-Object System.Drawing.Size(150, 25)
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(180, $Y)
    $textbox.Size = New-Object System.Drawing.Size(330, 25)
    $textbox.Text = $DefaultText
    $form.Controls.Add($textbox)

    return $textbox
}

# ----------------------------
# Section 5 - Input boxes
# ----------------------------
$txtFirstName = Add-LabelAndTextBox "First Name:" 70 "Test"
$txtLastName  = Add-LabelAndTextBox "Last Name:" 110 "User"
$txtUsername  = Add-LabelAndTextBox "Username:" 150 "wazuh.testuser"
$txtPassword  = Add-LabelAndTextBox "Password:" 190 "P@ssw0rd!2026"
$txtOUPath    = Add-LabelAndTextBox "OU / Path:" 230 $DefaultUserPath
$txtGroup     = Add-LabelAndTextBox "Optional Group:" 270 ""

$txtPassword.UseSystemPasswordChar = $true

# ----------------------------
# Section 6 - Checkboxes
# ----------------------------
$chkEnableUser = New-Object System.Windows.Forms.CheckBox
$chkEnableUser.Text = "Enable user account"
$chkEnableUser.Location = New-Object System.Drawing.Point(180, 310)
$chkEnableUser.Size = New-Object System.Drawing.Size(180, 25)
$chkEnableUser.Checked = $true
$form.Controls.Add($chkEnableUser)

$chkChangePassword = New-Object System.Windows.Forms.CheckBox
$chkChangePassword.Text = "User must change password at next logon"
$chkChangePassword.Location = New-Object System.Drawing.Point(180, 340)
$chkChangePassword.Size = New-Object System.Drawing.Size(300, 25)
$chkChangePassword.Checked = $true
$form.Controls.Add($chkChangePassword)

# ----------------------------
# Section 7 - Output box
# ----------------------------
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(25, 390)
$outputBox.Size = New-Object System.Drawing.Size(485, 80)
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.ReadOnly = $true
$form.Controls.Add($outputBox)

# ----------------------------
# Section 8 - Create button
# ----------------------------
$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "Create AD User"
$btnCreate.Location = New-Object System.Drawing.Point(180, 480)
$btnCreate.Size = New-Object System.Drawing.Size(160, 35)
$form.Controls.Add($btnCreate)

# ----------------------------
# Section 9 - Button action
# ----------------------------
$btnCreate.Add_Click({

    $FirstName = $txtFirstName.Text.Trim()
    $LastName  = $txtLastName.Text.Trim()
    $Username  = $txtUsername.Text.Trim()
    $Password  = $txtPassword.Text
    $OUPath    = $txtOUPath.Text.Trim()
    $GroupName = $txtGroup.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($FirstName) -or
        [string]::IsNullOrWhiteSpace($LastName) -or
        [string]::IsNullOrWhiteSpace($Username) -or
        [string]::IsNullOrWhiteSpace($Password) -or
        [string]::IsNullOrWhiteSpace($OUPath)) {

        $outputBox.Text = "Missing required fields. First name, last name, username, password, and OU/path are required."
        return
    }

    if ($Username -notmatch '^[a-zA-Z0-9._-]{1,20}$') {
        $outputBox.Text = "Invalid username. Use letters, numbers, dot, dash, or underscore. Max 20 characters."
        return
    }

    try {
        $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue

        if ($ExistingUser) {
            $outputBox.Text = "User already exists: $Username"
            return
        }

        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $FullName = "$FirstName $LastName"
        $UPN = "$Username@$DefaultUPNSuffix"

        New-ADUser `
            -Name $FullName `
            -GivenName $FirstName `
            -Surname $LastName `
            -SamAccountName $Username `
            -UserPrincipalName $UPN `
            -AccountPassword $SecurePassword `
            -Enabled $chkEnableUser.Checked `
            -ChangePasswordAtLogon $chkChangePassword.Checked `
            -Path $OUPath `
            -Description "Created by AD Lab User Creator for Wazuh detection test" `
            -ErrorAction Stop

        if (-not [string]::IsNullOrWhiteSpace($GroupName)) {
            Add-ADGroupMember -Identity $GroupName -Members $Username -ErrorAction Stop
        }

        $outputBox.Text = @"
SUCCESS: AD user created.

Username: $Username
UPN: $UPN
Path: $OUPath

Check Wazuh for Windows Event ID 4720.
Also check Event Viewer > Windows Logs > Security.
"@
    }
    catch {
        $outputBox.Text = "ERROR:`r`n$($_.Exception.Message)"
    }
})

# ----------------------------
# Section 10 - Show GUI
# ----------------------------
[void]$form.ShowDialog()
