# Wazuh Windows Agent Lab Scripts

PowerShell scripts to install and remove the Wazuh Windows Agent in a lab environment.

---

## 📁 Scripts

| Script | Purpose |
|------|--------|
| `setup-wazuh-agent.ps1` | Installs Wazuh Agent, enables logging, configures system |
| `uninstall-wazuh-agent.ps1` | Removes Wazuh Agent and cleans up system |

---

## ⚠️ IMPORTANT — PowerShell Execution Policy

Windows blocks unsigned scripts by default.

Before running **ANY script**, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
---

## Requirements

- Windows VM
- PowerShell run as Administrator
- Wazuh server already installed and reachable
- Wazuh Agent MSI downloaded to the Windows VM
- Example MSI: `wazuh-agent-4.14.5-1.msi`

---

## 1. Install Wazuh Server First

Install Wazuh on Ubuntu before installing agents.

```bash
curl -sO https://packages.wazuh.com/x.xx/wazuh-install.sh
sudo bash ./wazuh-install.sh -a
