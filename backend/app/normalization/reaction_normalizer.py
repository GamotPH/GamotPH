import re
from typing import List
from functools import lru_cache

# Example: you can adjust this list once trained
CANONICAL_REACTIONS = [
    "rashes",
    "headache",
    "dizziness",
    "abdominal pain",
    "shortness of breath",
    "swelling of lips",
    "vomiting",
    "nausea",
    "palpitations",
    "itchiness",
]

@lru_cache(maxsize=1)
def load_reaction_list() -> List[str]:
    return CANONICAL_REACTIONS

def normalize_single_reaction(raw: str) -> str | None:
    if not raw:
        return None

    cleaned = raw.strip().lower()
    cleaned = re.sub(r"[^a-z\s]", "", cleaned)

    # exact match
    for c in CANONICAL_REACTIONS:
        if c in cleaned:
            return c

    # fuzzy fallback
    best = None
    best_score = 0
    for c in CANONICAL_REACTIONS:
        score = similarity(cleaned, c)
        if score > best_score:
            best = c
            best_score = score

    return best if best_score >= 0.6 else None

def similarity(a: str, b: str) -> float:
    # simple normalized overlap similarity
    set_a = set(a.split())
    set_b = set(b.split())
    if not set_a or not set_b:
        return 0
    return len(set_a & set_b) / len(set_a | set_b)
