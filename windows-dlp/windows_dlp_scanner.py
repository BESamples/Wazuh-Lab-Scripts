import hashlib
import json
import os
import socket
from datetime import datetime, timezone
from pathlib import Path

from rules_windows import DLP_RULES, EXCLUSION_KEYWORDS

TARGET_DIR = Path(r"C:\DLP_Test")
ALERT_DIR = Path(r"C:\ProgramData\DLP\alerts")
STATE_DIR = Path(r"C:\ProgramData\DLP\state")

ALERT_JSON = ALERT_DIR / "dlp_alerts.json"
ALERT_JSONL = ALERT_DIR / "dlp_alerts.jsonl"
STATE_FILE = STATE_DIR / "dlp_state.json"

SEVERITY_ORDER = {
    "low": 1,
    "medium": 2,
    "high": 3
}


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def read_file(file_path):
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as file:
            return file.read()
    except Exception as error:
        print(f"Could not read {file_path}: {error}")
        return ""


def should_exclude(content):
    for keyword in EXCLUSION_KEYWORDS:
        if keyword.lower() in content.lower():
            return True
    return False


def sha256_text(content):
    return hashlib.sha256(content.encode("utf-8", errors="ignore")).hexdigest()


def make_fingerprint(file_path, file_hash, match_type):
    raw = f"{file_path}|{file_hash}|{match_type}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def highest_severity(alerts):
    if not alerts:
        return "none"

    return max(
        [alert["severity"] for alert in alerts],
        key=lambda severity: SEVERITY_ORDER.get(severity, 0)
    )


def set_windows_classification_stream(file_path, classification):
    """
    Stores the classification in a Windows NTFS Alternate Data Stream.
    You can verify it with:
    Get-Content -Path C:\DLP_Test\employee_record.txt -Stream classification
    """
    try:
        ads_path = f"{str(file_path)}:classification"
        with open(ads_path, "w", encoding="utf-8") as stream:
            stream.write(classification)
    except Exception as error:
        print(f"Could not set classification stream on {file_path}: {error}")


def load_state():
    if not STATE_FILE.exists():
        return {
            "seen_findings": {}
        }

    try:
        with open(STATE_FILE, "r", encoding="utf-8") as file:
            return json.load(file)
    except Exception:
        return {
            "seen_findings": {}
        }


def save_state(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    with open(STATE_FILE, "w", encoding="utf-8") as file:
        json.dump(state, file, indent=4)


def scan_file(file_path):
    content = read_file(file_path)

    if not content:
        return []

    if should_exclude(content):
        return []

    file_hash = sha256_text(content)
    hostname = socket.gethostname()
    alerts = []

    for rule_name, rule_data in DLP_RULES.items():
        matches = list(rule_data["pattern"].finditer(content))

        if matches:
            alerts.append({
                "timestamp": utc_now(),
                "scanner": "windows_dlp_scanner",
                "host": hostname,
                "file_path": str(file_path),
                "file_name": file_path.name,
                "match_type": rule_name,
                "severity": rule_data["severity"],
                "classification": rule_data["severity"],
                "match_count": len(matches),
                "file_hash_sha256": file_hash
            })

    if alerts:
        classification = highest_severity(alerts)
        set_windows_classification_stream(file_path, classification)

    return alerts


def write_latest_alerts(alerts):
    ALERT_DIR.mkdir(parents=True, exist_ok=True)

    with open(ALERT_JSON, "w", encoding="utf-8") as file:
        json.dump(alerts, file, indent=4)


def append_new_alerts(alerts, state):
    ALERT_DIR.mkdir(parents=True, exist_ok=True)

    new_alerts = []

    for alert in alerts:
        fingerprint = make_fingerprint(
            alert["file_path"],
            alert["file_hash_sha256"],
            alert["match_type"]
        )

        if fingerprint not in state["seen_findings"]:
            alert["fingerprint"] = fingerprint
            new_alerts.append(alert)
            state["seen_findings"][fingerprint] = utc_now()

    if new_alerts:
        with open(ALERT_JSONL, "a", encoding="utf-8") as file:
            for alert in new_alerts:
                file.write(json.dumps(alert) + "\n")

    return new_alerts


def main():
    if not TARGET_DIR.exists():
        print(f"Target directory does not exist: {TARGET_DIR}")
        return

    state = load_state()
    all_alerts = []

    for file_path in TARGET_DIR.rglob("*"):
        if file_path.is_file():
            if file_path.name.endswith(".gpg"):
                continue

            file_alerts = scan_file(file_path)
            all_alerts.extend(file_alerts)

    write_latest_alerts(all_alerts)
    new_alerts = append_new_alerts(all_alerts, state)
    save_state(state)

    print("Completed Windows DLP scan")
    print(f"Current alerts: {len(all_alerts)}")
    print(f"New alerts written to JSONL: {len(new_alerts)}")
    print(f"Alert JSON: {ALERT_JSON}")
    print(f"Alert JSONL for Wazuh: {ALERT_JSONL}")


if __name__ == "__main__":
    main()
