import json
import os
from pathlib import Path

from rules import DLP_RULES, EXCLUSION_KEYWORDS

TARGET_DIR = Path("sample_files")
ALERT_DIR = Path("alerts")
ALERT_JSON = ALERT_DIR / "dlp_alerts.json"
ALERT_JSONL = ALERT_DIR / "dlp_alerts.jsonl"


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


def classify_by_threshold(total_matches):
    if total_matches >= 5:
        return "high"
    if total_matches >= 3:
        return "medium"
    if total_matches >= 1:
        return "low"
    return "none"


def scan_file(file_path):
    content = read_file(file_path)

    if not content:
        return None

    if should_exclude(content):
        return None

    match_summary = {}
    total_matches = 0

    for rule_name, rule_data in DLP_RULES.items():
        matches = list(rule_data["pattern"].finditer(content))

        if matches:
            match_summary[rule_name] = len(matches)
            total_matches += len(matches)

    classification = classify_by_threshold(total_matches)

    if classification == "none":
        return None

    set_classification(file_path, classification)

    return {
        "file_path": str(file_path),
        "classification": classification,
        "total_matches": total_matches,
        "match_summary": match_summary,
        "scanner": "match_scanner"
    }


def write_alerts(alerts):
    ALERT_DIR.mkdir(exist_ok=True)

    with open(ALERT_JSON, "w", encoding="utf-8") as file:
        json.dump(alerts, file, indent=4)

    with open(ALERT_JSONL, "w", encoding="utf-8") as file:
        for alert in alerts:
            file.write(json.dumps(alert) + "\n")


def main():
    alerts = []

    for file_path in TARGET_DIR.rglob("*"):
        if file_path.is_file() and not file_path.name.endswith(".gpg"):
            alert = scan_file(file_path)
            if alert:
                alerts.append(alert)

    write_alerts(alerts)

    print("Completed threshold scan")
    print(f"Total files classified: {len(alerts)}")


if __name__ == "__main__":
    main()
