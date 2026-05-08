🚀 Start the Tool
cd Wazuh-Lab-Scripts
./ubuntu/manage-wazuh-lab.sh

🧭 When to Use Each Option
⭐ First Thing After Lab Reset
Option 12 → Fresh Lab Bootstrap

👉 Use this when:
Lab was reset
Fresh Wazuh install
Nothing is configured

What it does:

Pulls latest GitHub repo
Applies rules
Applies config (auto-enroll if present)
Validates setup
Restarts Wazuh
Shows agent status

✏️ WHEN YOU WANT TO EDIT RULES
Option 1 → Edit GitHub local_rules.xml
👉 Use this when:
creating new detections
modifying rules
testing ideas

💾 Save Changes to GitHub
Option 8 → Git add / commit / push

👉 Use this when:
Saving changes
Version controlling rules

Version controlling rules
🚀 Deploy Rules to Wazuh
Option 11 → Deploy latest rules ⭐

👉 Use this when:

After committing changes
You want rules live in Wazuh

What it does:

Pulls latest repo
Backs up current rules
Applies new rules
Validates config
Restarts Wazuh (if valid)
🧪 Test Rules
Option 3 → Test Wazuh rules

👉 Use this when:

Debugging rule errors
Checking syntax before deploy
🔄 Restart Wazuh
Option 4 → Restart wazuh-manager (safe)

👉 Use this when:

Config changes were made
Service needs refresh
🔍 View Live Events
Option 9 → Check Wazuh logs live

👉 Use this when:

Testing detections
Troubleshooting alerts
🧾 Check Agents
Option 6 → Check agent list

👉 Use this when:

Agent not showing in dashboard
Verifying connection
🌐 Dashboard Info
Option 10 → Show Wazuh dashboard info
🔁 Daily Workflow
1 → Edit rules  
8 → Commit changes  
11 → Deploy rules  
9 → Watch logs  
🔁 After Lab Reset
12 → Bootstrap lab  
6 → Check agents  
9 → Verify logs  
🧠 If Something Breaks
Rules not working:
3 → Test rules  
11 → Redeploy rules  
Wazuh not responding:
4 → Restart wazuh-manager  
Everything broken:
12 → Fresh Lab Bootstrap  
