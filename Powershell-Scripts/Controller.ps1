$CommandFile = "C:\Lab\commands.txt"

while ($true) {
    if (Test-Path $CommandFile) {

        $commands = Get-Content $CommandFile

        foreach ($cmd in $commands) {
            $parts = $cmd -split "\|"

            $action = $parts[0]
            $folder = $parts[1]
            $filename = $parts[2]

            if ($action -eq "CREATE_FILE") {
              $TargetPath = "C:\Users\Administrator\Downloads\$fake-note.txt
              New-Item -Path $TargetParth -ItemType File -Force
            }
        }

        # Clear command file after processing
        Clear-Content $CommandFile
    }

    Start-Sleep -Seconds 3
}
