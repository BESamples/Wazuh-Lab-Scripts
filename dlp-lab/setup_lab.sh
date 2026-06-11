#!/usr/bin/env bash
set -e

sudo apt-get update
sudo apt-get install -y python3 attr gnupg

mkdir -p sample_files alerts

cat > sample_files/employee_record.txt << 'EOF'
Employee: John Smith
SSN: 123-45-6789
Classification: Confidential
EOF

cat > sample_files/payment_data.txt << 'EOF'
Customer payment test
Card: 4111-1111-1111-1111
Restricted payment information.
EOF

cat > sample_files/api_config.txt << 'EOF'
api_key = "ABCD1234SECRETKEY9999"
token: mytokenvalue1234567890
EOF

cat > sample_files/false_positive_test.txt << 'EOF'
QA test data only.
Fake SSN: 123-45-6789
This is not real customer data.
EOF

cat > sample_files/false_negative_secret.txt << 'EOF'
AWS key found during review:
AKIA1234567890ABCDEF
database_password = "SuperSecretPassword123"
EOF

cat > sample_files/payroll_backup.txt << 'EOF'
Payroll backup
SSN: 987-65-4321
Internal use only.
EOF

sudo chown root:root sample_files/payroll_backup.txt || true

rm -f alerts/dlp_alerts.json alerts/dlp_alerts.jsonl
rm -f sample_files/*.gpg
rm -f payment_data.txt

echo "DLP lab setup complete."
echo "Run: sudo python3 dlp_scanner.py"
