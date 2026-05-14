# ========================
# LAB SETUP
# ========================

New-Item -Path "C:\Lab" -ItemType Directory -Force
New-Item -Path "C:\Lab\commands.txt" -ItemType File -Force
New-Item -Path "C:\Lab\VictimDrop" -ItemType Directory -Force



# ========================
# TEST COMMAND
# ========================

Set-Content -Path "C:\Lab\commands.txt" -Value "CREATE_FILE|VictimDrop|test1.txt"

# Set-Content -Path "C:\Lab\commands.txt" -Value "CREATE_FOLDER|VictimDrop|ReconResults"



# ========================
# MAIN LOOP
# ========================

while ($true) {

    # Read command file
    $cmd = Get-Content "C:\Lab\commands.txt"



    # If empty, wait and restart loop
    if ([string]::IsNullOrWhiteSpace($cmd)) {

        Write-Host "No command found"

        Start-Sleep -Seconds 5

        continue
    }



    # Split command
    $parts = $cmd -split "\|"



    # Variables
    $action = $parts[0]
    $folder = $parts[1]
    $name = $parts[2]



    # Debug
    Write-Host "Action: $action"
    Write-Host "Folder: $folder"
    Write-Host "Name: $name"



    # ========================
    # CREATE FILE
    # ========================

    if ($action -eq "CREATE_FILE") {

        $TargetPath = "C:\Lab\$folder\$name"

        Write-Host "Creating file: $TargetPath"

        New-Item -Path $TargetPath -ItemType File -Force

        Clear-Content "C:\Lab\commands.txt"
    }



    # ========================
    # CREATE FOLDER
    # ========================

    if ($action -eq "CREATE_FOLDER") {

        $TargetPath = "C:\Lab\$folder\$name"

        Write-Host "Creating folder: $TargetPath"

        New-Item -Path $TargetPath -ItemType Directory -Force

        Clear-Content "C:\Lab\commands.txt"
    }



    # Wait before next check
    Start-Sleep -Seconds 5
}
