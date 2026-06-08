Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 80 |
Select-String -Pattern "Sysmon|eventchannel|ERROR|error|WARNING|warning"
