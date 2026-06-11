import json
import os
from pathlib import Path

from rules import DLP_RULES, EXCLUSION_KEYWORDS

TARGET_DIR = Path("sample_files")
ALERT_DIR = Path("alerts")
ALERT_JSON = ALERT_DIR / "dlp_alerts.json"
ALERT_JSONL = ALERT_DIR / "dlp_alerts.jsonl"

SEVERITY_ORDER = {
    "low": 1,
    "medium": 2,
    "high": 3
}


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


def set_classification(file_path, classification):
    try:
        os.setxattr(str(file_path), b"user.classification", classification.encode())
    except Exception as error:
        print(f"Could not set classification on {file_path}: {error}")


def highest_severity(alerts):
    if not alerts:
        return "none"

    return max(
        [alert["severity"] for alert in alerts],
        key=lambda severity: SEVERITY_ORDER.get(severity, 0)
    )


def scan_file(file_path):
    content = read_file(file_path)

    if not content:
        return []

    if should_exclude(content):
        return []

    alerts = []

    for rule_name, rule_data in DLP_RULES.items():
        matches = list(rule_data["pattern"].finditer(content))

        if matches:
            alerts.append({
                "file_path": str(file_path),
                "match_type": rule_name,
                "severity": rule_data["severity"],
                "classification": rule_data["severity"],
                "match_count": len(matches),
                "scanner": "dlp_scanner"
            })

    if alerts:
        classification = highest_severity(alerts)
        set_classification(file_path, classification)

    return alerts


def write_alerts(alerts):
    ALERT_DIR.mkdir(exist_ok=True)

    with open(ALERT_JSON, "w", encoding="utf-8") as file:
        json.dump(alerts, file, indent=4)

    with open(ALERT_JSONL, "w", encoding="utf-8") as file:
        for alert in alerts:
            file.write(json.dumps(alert) + "\n")


def main():
    all_alerts = []

    if not TARGET_DIR.exists():
        print(f"Target directory does not exist: {TARGET_DIR}")
        return

    for file_path in TARGET_DIR.rglob("*"):
        if file_path.is_file() and not file_path.name.endswith(".gpg"):
            file_alerts = scan_file(file_path)
            all_alerts.extend(file_alerts)

    write_alerts(all_alerts)

    print("Completed Scan")
    print(f"Alerts written to: {ALERT_JSON}")
    print(f"JSONL alerts written to: {ALERT_JSONL}")
    print(f"Total alerts: {len(all_alerts)}")


if __name__ == "__main__":
    main()
