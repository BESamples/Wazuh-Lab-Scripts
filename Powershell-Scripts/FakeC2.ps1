# =================================
# LAB SETUP SECTION
# Creates folders/files if missing
# =================================

New-Item -Path "C:\Lab" -ItemType Directory -Force
New-Item -Path "C:\Lab\commands.txt" -ItemType File -Force
New-Item -Path "C:\Lab\VictimDrop" -ItemType Directory -Force



# =================================
# COMMANDS FOR COMMAND FILE
# Writes the test command
# =================================

Set-Content -Path "C:\Lab\commands.txt" -Value "CREATE_FILE|VictimDrop|test1.txt"



# =================================
# LOOP SECTION
# Keeps checking commands.txt
# =================================

while ($true) {

    # =================================
    # Step 1 - Read Command File
    # Reads the text inside commands.txt
    # =================================

    $cmd = Get-Content "C:\Lab\commands.txt"



    # =================================
    # Step 2 - Split Command Into Parts
    # Splits:
    # CREATE_FILE|VictimDrop|test1.txt
    # =================================

    $parts = $cmd -split "\|"



    # =================================
    # Step 3 - Assign Variables
    # Saves each section into variables
    # =================================

    $action = $parts[0]
    $folder = $parts[1]
    $filename = $parts[2]



    # =================================
    # Step 4 - Debug Output
    # Shows what PowerShell extracted
    # =================================

    Write-Host "Action: $action"
    Write-Host "Folder: $folder"
    Write-Host "Filename: $filename"



    # =================================
    # Step 5 - Check Command Type
    # Only continues if action is CREATE_FILE
    # =================================

    if ($action -eq "CREATE_FILE") {

        # =================================
        # Step 6 - Build Full File Path
        # Example:
        # C:\Lab\VictimDrop\test1.txt
        # =================================

        $TargetPath = "C:\Lab\$folder\$filename"



        # =================================
        # Step 7 - Show Target Path
        # =================================

        Write-Host "Creating: $TargetPath"



        # =================================
        # Step 8 - Create the File
        # =================================

        New-Item -Path $TargetPath -ItemType File -Force
        Clear-Content "C:\Lab\commands.txt"

         # =================================
        # Step if nothing is in command text file
        # =================================
        If $cmd = Get-Content "C:\Lab\Command.txt"
        Write-Host "No command found"
        continue
    }



    # =================================
    # Step 9 - Wait Before Checking Again
    # =================================

    Start-Sleep -Seconds 5
}
