import re

DLP_RULES = {
    "ssn": {
        "pattern": re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
        "severity": "high"
    },
    "credit_card": {
        "pattern": re.compile(r"\b(?:\d[ -]*?){13,16}\b"),
        "severity": "high"
    },
    "api_key": {
        "pattern": re.compile(r"\b(api_key|secret|token)\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{16,}"),
        "severity": "high"
    },
    "confidential_keyword": {
        "pattern": re.compile(r"\b(confidential|internal use only|restricted)\b", re.IGNORECASE),
        "severity": "medium"
    }
}

EXCLUSION_KEYWORDS = []
