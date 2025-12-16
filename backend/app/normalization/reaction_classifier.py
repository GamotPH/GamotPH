import re

MEDICAL_HINTS = [
    "pain", "ache", "rash", "swelling", "itch", "vomit",
    "nausea", "dizz", "breath", "palp", "fever",
    "head", "chest", "abdominal", "skin", "throat"
]

GARBAGE_PATTERNS = [
    r"^\d+$",
    r"^(n/?a|none|nil|unknown)$",
]

def is_garbage(text: str) -> bool:
    t = text.strip().lower()
    if not t:
        return True

    for p in GARBAGE_PATTERNS:
        if re.match(p, t):
            return True

    # single short word, no medical hint
    if len(t.split()) == 1 and not any(h in t for h in MEDICAL_HINTS):
        return True

    return False


def is_medical_like(text: str) -> bool:
    t = text.lower()
    return any(h in t for h in MEDICAL_HINTS)
