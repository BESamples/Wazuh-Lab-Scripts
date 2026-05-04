# Wazuh Windows Agent Lab Scripts

PowerShell scripts for quickly setting up and removing the Wazuh Windows Agent in a lab environment.

These scripts are intended for Windows lab VMs used with a Wazuh server.

---

## Scripts Included

| Script | Purpose |
|---|---|
| `setup-wazuh-agent.ps1` | Installs Wazuh Agent, sets agent name, enables Windows logon auditing, enables PowerShell logging, and configures PowerShell event collection |
| `uninstall-wazuh-agent.ps1` | Stops and removes the Wazuh Agent, deletes leftover files, and offers a reboot |

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
