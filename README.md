# Wazuh Windows Agent Lab Scripts

PowerShell scripts to install and remove the Wazuh Windows Agent in a lab environment.

---

## 📁 Scripts

| Script | Purpose |
|------|--------|
| `manage-wazuh-agent.ps1` | Interactive script to install OR uninstall the Wazuh Agent with safety checks |
| `setup-wazuh-agent.ps1` *(legacy)* | Installs Wazuh Agent (replaced by manage script) |
| `uninstall-wazuh-agent.ps1` *(legacy)* | Removes Wazuh Agent (replaced by manage script) |

---

## 🧠 manage-wazuh-agent.ps1 (Recommended)

This is the primary script and replaces both setup and uninstall scripts.

### 🔧 Features

- Detects if Wazuh Agent is already installed
- Prevents reinstall if agent exists
- Prevents uninstall if agent is not installed
- Prompts user for:
  - Wazuh Manager IP
  - Agent name
  - Installer file name
- Installs Wazuh Agent
- Starts and configures the service
- Enables:
  - Windows logon auditing
  - PowerShell Script Block Logging
- Configures PowerShell log collection in Wazuh
- Uninstalls Wazuh Agent cleanly
- Removes leftover files
- Prompts for reboot after install or uninstall

---

## 🚀 Usage

Run PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\manage-wazuh-agent.ps1
