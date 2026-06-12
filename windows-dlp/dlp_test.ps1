cd C:\
git clone https://github.com/YOUR-GITHUB-USERNAME/Wazuh-Lab-Scripts.git
cd C:\Wazuh-Lab-Scripts\windows-dlp
powershell.exe -ExecutionPolicy Bypass -File .\setup_windows_dlp.ps1
powershell.exe -ExecutionPolicy Bypass -File C:\ProgramData\DLP\run_dlp_once.ps1
