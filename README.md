# Wazuh Windows Agent Lab Scripts

PowerShell scripts to install and remove the Wazuh Windows Agent in a lab environment.

---

## 📁 Scripts

| Script | Purpose |
|---|---|
| [manage-wazuh-agent.ps1](./manage-wazuh-agent.ps1) | Main interactive script to install or uninstall the Wazuh Agent with safety checks. During install, it also enables Windows logon auditing, enables PowerShell Script Block Logging, adds PowerShell Operational log collection to `ossec.conf`, restarts the Wazuh service, and prompts for reboot. |
| [manage-powershell-wazuh-logging.ps1](./manage-powershell-wazuh-logging.ps1) | Optional helper script to check, enable, or disable PowerShell Operational log collection in the Wazuh agent config without reinstalling the agent. |
| [setup-wazuh-agent.ps1](./setup-wazuh-agent.ps1) *(legacy)* | Older install-only script. Replaced by `manage-wazuh-agent.ps1`. |
| [uninstall-wazuh-agent.ps1](./uninstall-wazuh-agent.ps1) *(legacy)* | Older uninstall-only script. Replaced by `manage-wazuh-agent.ps1`. |

---

## 🧠 manage-wazuh-agent.ps1 (Recommended)

This is the primary script for the lab and replaces the separate setup and uninstall scripts.

It provides one menu to either install or uninstall the Wazuh Agent safely.

### 🔧 Features

- Detects whether Wazuh Agent is already installed
- Prevents reinstall if the agent already exists
- Prevents uninstall if the agent is not installed
- Prompts user for:
  - Wazuh Manager IP
  - Agent name
  - Wazuh installer MSI file name
- Installs Wazuh Agent from the Downloads folder
- Starts the Wazuh service
- Enables Windows logon auditing
- Enables PowerShell Script Block Logging
- Adds PowerShell Operational log collection to `ossec.conf`
- Restarts the Wazuh service after configuration changes
- Uninstalls Wazuh Agent cleanly
- Removes leftover Wazuh files
- Prompts for reboot after install or uninstall

---

## 🚀 Usage

Run PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\manage-wazuh-agent.ps1
