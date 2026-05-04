⚡ WAZUH LAB QUICK START (Morning Reset Guide)
🧱 1. Install Wazuh (Ubuntu)
curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
sudo bash ./wazuh-install.sh -a

Get IP:

hostname -I | awk '{print $1}'
🪟 2. Windows Agent Setup (Fast)

Open PowerShell as Admin:

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Download your script:

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/BESamples/Wazuh-Lab-Scripts/main/manage-wazuh-agent.ps1" -OutFile manage-wazuh-agent.ps1

Run it:

.\manage-wazuh-agent.ps1

👉 Choose:

1 (Install)

Enter:

Wazuh Manager IP = <Ubuntu IP>
Agent Name = WinLab1
Installer = wazuh-agent-*.msi

👉 Reboot when done

🐧 3. Pull Rules from GitHub (Ubuntu)
cd /home/labadmin
git clone https://github.com/BESamples/Wazuh-Lab-Scripts.git
cd wazuh-lab-scripts/wazuh-rules
💾 4. Apply Rules
sudo cp local_rules.xml /var/ossec/etc/rules/local_rules.xml
🔎 5. Validate + Restart
sudo /var/ossec/bin/wazuh-analysisd -t
sudo systemctl restart wazuh-manager
🔍 6. Verify in Dashboard

Search:

rule.id:(100100 OR 100101 OR 100200)
🧪 7. Quick Tests
Failed login
Lock screen → wrong password
PowerShell
Get-Process
🔁 DAILY SHORTCUT (once repo exists)
cd /home/labadmin/wazuh-lab-scripts
git pull
cd wazuh-rules

sudo cp local_rules.xml /var/ossec/etc/rules/local_rules.xml
sudo /var/ossec/bin/wazuh-analysisd -t
sudo systemctl restart wazuh-manager
🧠 IF SOMETHING BREAKS

Restore backup:

sudo cp local_rules_default_backup.xml /var/ossec/etc/rules/local_rules.xml
sudo systemctl restart wazuh-manager
