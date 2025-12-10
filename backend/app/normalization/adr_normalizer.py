from pathlib import Path
from functools import lru_cache
from fuzzywuzzy import process


# Path to the ADR list file (must be located in the same folder)
ADR_LIST_PATH = Path(__file__).parent / "ADR_LIST.txt"


@lru_cache(maxsize=1)
def load_adr_list():
    """
    Loads canonical ADR (Adverse Drug Reaction) terms from ADR_LIST.txt.
    - Removes empty lines
    - Strips whitespace
    - Caches the result so the file is read only once
    """
    if not ADR_LIST_PATH.exists():
        raise FileNotFoundError(f"ADR list not found at {ADR_LIST_PATH}")

    with open(ADR_LIST_PATH, "r", encoding="utf-8") as f:
        return [line.strip() for line in f if line.strip()]


def normalize_adr(raw_text: str, threshold: int = 70) -> str | None:
    """
    Normalizes a free-text ADR string to the closest canonical ADR using fuzzy matching.

    Args:
        raw_text (str): The user-submitted ADR text.
        threshold (int): Minimum matching score required to accept the match (0–100).

    Returns:
        str | None: Canonical ADR term if matched, otherwise None.
    """
    if raw_text is None:
        return None

    raw_text = raw_text.strip()
    if not raw_text:
        return None

    adr_list = load_adr_list()

    # Fuzzy match to find the closest ADR
    best = process.extractOne(raw_text, adr_list)
    if best is None:
        return None

    best_match, score = best

    # Accept only if similarity passes threshold
    return best_match if score >= threshold else None


def normalize_adr_list(raw_text: str, threshold: int = 85) -> list[str]:
    """
    Accepts a comma/semicolon/slash separated list of ADRs and normalizes each.
    Removes duplicates automatically.

    Example:
        Input: "feverr, head ache, nausea"
        Output: ["Fever", "Headache", "Nausea"]

    Returns:
        list[str]: A list of normalized ADRs.
    """
    import re

    if not raw_text:
        return []

    # Split ADRs on commas, semicolons, slashes, or "and"
    parts = re.split(r"[;,/]| and ", raw_text, flags=re.IGNORECASE)

    normalized = []
    for part in parts:
        clean = part.strip()
        if clean:
            norm = normalize_adr(clean, threshold)
            if norm and norm not in normalized:
                normalized.append(norm)

    return normalized
