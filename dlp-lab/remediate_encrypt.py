import json
import subprocess
from pathlib import Path

ALERT_FILE = Path("alerts/dlp_alerts.json")
GPG_PASSWORD = "safe"

MINIMUM_SEVERITY = "medium"
REMOVE_ORIGINAL = True

SEVERITY_ORDER = {
    "low": 1,
    "medium": 2,
    "high": 3
}


def severity_allowed(alert):
    severity = alert.get("severity") or alert.get("classification", "low")
    return SEVERITY_ORDER.get(severity, 0) >= SEVERITY_ORDER[MINIMUM_SEVERITY]


def load_alerts():
    if not ALERT_FILE.exists():
        print(f"Alert file not found: {ALERT_FILE}")
        return []

    with open(ALERT_FILE, "r", encoding="utf-8") as file:
        return json.load(file)


def encrypt_file(file_path):
    source = Path(file_path)

    if not source.exists():
        print(f"File not found, skipping: {source}")
        return

    if source.name.endswith(".gpg"):
        print(f"Already encrypted, skipping: {source}")
        return

    encrypted_file = source.with_suffix(source.suffix + ".gpg")

    command = [
        "gpg",
        "--batch",
        "--yes",
        "--pinentry-mode",
        "loopback",
        "--passphrase",
        GPG_PASSWORD,
        "--symmetric",
        "--cipher-algo",
        "AES256",
        "--output",
        str(encrypted_file),
        str(source)
    ]

    subprocess.run(command, check=True)

    if REMOVE_ORIGINAL:
        source.unlink()

    print(f"Encrypted: {source} -> {encrypted_file}")


def main():
    alerts = load_alerts()

    files_to_encrypt = set()

    for alert in alerts:
        if severity_allowed(alert):
            file_path = alert.get("file_path")

            if file_path:
                files_to_encrypt.add(file_path)

    if not files_to_encrypt:
        print("No files met remediation criteria.")
        return

    for file_path in sorted(files_to_encrypt):
        encrypt_file(file_path)

    print("Remediation complete.")


if __name__ == "__main__":
    main()
