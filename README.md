# Wazuh Windows Agent Automation

PowerShell script to:
- Install Wazuh agent
- Enable logging
- Configure environment

## Usage
Run as Administrator:
.\setup-wazuh-agent.ps1 -WazuhManager "IP" -AgentName "Name"

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YOURNAME/wazuh-lab-scripts/main/setup-wazuh-agent.ps1" -OutFile setup-wazuh-agent.ps1
.\setup-wazuh-agent.ps1
