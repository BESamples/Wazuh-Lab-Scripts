# Wazuh Windows Agent Lab Scripts

PowerShell scripts for installing, uninstalling, and configuring the Wazuh Windows Agent in a lab environment.

---

## ⚠️ Lab Use Notice

These scripts are intended for:

- Personal labs
- Sandbox environments
- Testing environments
- Educational use

Review all scripts before using them in production environments.

---

## 📁 Scripts

| Script | Purpose |
|---|---|
| [manage-wazuh-agent.ps1](./manage-wazuh-agent.ps1) | Main interactive script to install, uninstall, and configure the Wazuh Agent |
| [manage-wazuh-agent-gui.ps1](./manage-wazuh-agent-gui.ps1) | Optional GUI version of the Wazuh Agent manager |
| [manage-powershell-wazuh-logging.ps1](./manage-powershell-wazuh-logging.ps1) | Optional helper script to check, enable, or disable PowerShell Operational log collection |
| [setup-wazuh-agent.ps1](./setup-wazuh-agent.ps1) *(legacy)* | Older install-only script replaced by `manage-wazuh-agent.ps1` |
| [uninstall-wazuh-agent.ps1](./uninstall-wazuh-agent.ps1) *(legacy)* | Older uninstall-only script replaced by `manage-wazuh-agent.ps1` |

---

## 🧠 manage-wazuh-agent.ps1 Recommended

This is the primary script for the lab and replaces the older standalone setup and uninstall scripts.

The script provides one interactive menu to:

- Install Wazuh Agent
- Uninstall Wazuh Agent
- Add File Integrity Monitoring (FIM)
- Install Sysmon
- Exit safely

---

## ✨ Features

- Detects whether Wazuh Agent is already installed
- Prevents accidental reinstall attempts
- Prevents uninstall attempts when the agent is not installed
- Prompts for:
  - Wazuh Manager IP
  - Agent name
  - Wazuh installer MSI file
- Automatically detects Wazuh installers in the Downloads folder
- Installs the Wazuh Agent automatically
- Starts the Wazuh service
- Enables Windows logon auditing
- Enables PowerShell Script Block Logging
- Adds PowerShell Operational log collection to `ossec.conf`
- Adds optional File Integrity Monitoring (FIM)
- Installs Sysmon with SwiftOnSecurity configuration
- Adds Sysmon Operational log collection to `ossec.conf`
- Restarts the Wazuh service after configuration changes
- Uninstalls the Wazuh Agent cleanly
- Removes leftover Wazuh files
- Prompts for reboot after install or uninstall

---

## 📋 Requirements

- Windows VM
- PowerShell run as Administrator
- Wazuh server already installed and reachable
- Wazuh Agent MSI downloaded to the Windows VM

Example MSI file:

```text
wazuh-agent-4.14.5-1.msi
```

Download the Wazuh Agent MSI separately from the official Wazuh website:

:contentReference[oaicite:0]{index=0}

---

## 🔐 PowerShell Execution Policy

If PowerShell blocks script execution, run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process
```

---

## ⬇️ Download Scripts

Download the standard version:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/BESamples/wazuh-lab-scripts/main/manage-wazuh-agent.ps1" -OutFile manage-wazuh-agent.ps1
```

Download the GUI version:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/BESamples/wazuh-lab-scripts/main/manage-wazuh-agent-gui.ps1" -OutFile manage-wazuh-agent-gui.ps1
```

---

## ▶️ Running the Scripts

Run PowerShell as Administrator.

Standard version:

```powershell
.\manage-wazuh-agent.ps1
```

GUI version:

```powershell
.\manage-wazuh-agent-gui.ps1
```

---

## 🛡️ Sysmon Configuration Credit

Sysmon configuration provided by:

:contentReference[oaicite:1]{index=1}

---

## 📌 Notes

- These scripts are designed for Wazuh lab and testing environments.
- Always review scripts before running in production.
- Reboot after install or uninstall is strongly recommended.
- Sysmon and PowerShell logging may require reboot before telemetry appears correctly in Wazuh.

---

## 📸 Screenshots

(Add screenshots here once GUI version is finalized.)
