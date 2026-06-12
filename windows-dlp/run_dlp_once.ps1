$ScannerPath = "C:\ProgramData\DLP\windows_dlp_scanner.py"

$Python = Get-Command python.exe -ErrorAction SilentlyContinue

if ($Python) {
    & $Python.Source $ScannerPath
    exit
}

$PyLauncher = Get-Command py.exe -ErrorAction SilentlyContinue

if ($PyLauncher) {
    & $PyLauncher.Source -3 $ScannerPath
    exit
}

Write-Host "Python was not found. Install Python 3, then run this again."
