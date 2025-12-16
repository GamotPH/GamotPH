import re
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Optional, Set

from fuzzywuzzy import process


BASE_DIR = Path(__file__).parent

# Files you already created / will create
GENERIC_LIST_PATH = BASE_DIR / "GENERIC_LIST.txt"
BRAND_LIST_PATH = BASE_DIR / "BRAND_LIST.txt"
NON_MEDICAL_TOKENS = {
    "n/a", "na", "none", "unknown", "generic",
    "bb", "jj", "xx", "water", "burger", "mcdon",
}

GARBAGE_PATTERNS = re.compile(
    r"""
    ^\s*$|
    ^n/?a$|
    ^none$|
    ^unknown$|
    ^nil$|
    ^water$|
    ^burger$
    """,
    re.IGNORECASE | re.VERBOSE,
)

def is_garbage(text: str) -> bool:
    if not text:
        return True

    t = text.strip().lower()

    if GARBAGE_PATTERNS.match(t):
        return True

    if len(t) < 4:          # kills bb, jj, aa
        return True

    if not re.search(r"[a-z]", t):
        return True

    return False



# ---------- LOAD CANONICAL GENERIC LIST ----------

@lru_cache(maxsize=1)
def load_generic_list() -> List[str]:
    """
    Load canonical generic medicine names from GENERIC_LIST.txt.
    One name per line, already cleaned by you.
    """
    generics: List[str] = []
    if GENERIC_LIST_PATH.exists():
        with open(GENERIC_LIST_PATH, encoding="utf-8") as f:
            for line in f:
                name = line.strip()
                if name:
                    generics.append(name)
    return generics


# ---------- LOAD BRAND -> GENERIC MAPPING ----------

@lru_cache(maxsize=1)
def load_brand_mapping() -> Dict[str, str]:
    """
    Load brand -> generic mappings from BRAND_LIST.txt.

    Expected format per line:
        BrandName = GenericName

    Lines containing 'Not a medicine' or 'SKIP' are ignored.
    Case-insensitive on brand side.
    """
    brand_map: Dict[str, str] = {}

    if not BRAND_LIST_PATH.exists():
        return brand_map

    with open(BRAND_LIST_PATH, encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue

            # Only lines with '=' are considered mappings
            if "=" not in line:
                continue

            left, right = line.split("=", 1)
            brand = left.strip()
            generic = right.strip()

            # Ignore "Not a medicine" entries or SKIP markers
            if "not a medicine" in generic.lower() or "skip" in generic.lower():
                continue

            if not brand or not generic:
                continue

            brand_map[brand.lower()] = generic

    return brand_map


@lru_cache(maxsize=1)
def load_brand_keys() -> List[str]:
    """
    List of all brand names (keys) for fuzzy matching.
    """
    return list(load_brand_mapping().keys())


# ---------- FUZZY HELPERS ----------

def _fuzzy_match(term: str, candidates: List[str]) -> Optional[tuple]:
    """
    Fuzzy-match `term` against `candidates` using fuzzywuzzy.
    Returns (match, score) or None.
    """
    if not term or not candidates:
        return None
    best = process.extractOne(term, candidates)
    return best  # (match, score) or None


def _fuzzy_to_generic(term: str, threshold: int = 85) -> Optional[str]:
    """
    Fuzzy-match term to a canonical generic, using GENERIC_LIST.txt.
    """
    generics = load_generic_list()
    if not generics:
        return None

    best = _fuzzy_match(term, generics)
    if not best:
        return None

    match, score = best
    if score < threshold:
        return None
    return match


# ---------- NORMALIZATION CORE ----------

def normalize_brand_name(name: str, threshold: int = 85) -> Optional[str]:
    """
    Normalize a brand name to its canonical generic.

    Steps:
      1. Fuzzy-match brand name to known brand keys.
      2. Look up brand -> generic from BRAND_LIST.txt.
      3. If that generic is in GENERIC_LIST, return it.
         Otherwise, return the generic string from the brand file.
    """
    if not name:
        return None

    name = name.strip()
    if not name:
        return None

    brand_map = load_brand_mapping()
    brand_keys = load_brand_keys()
    if not brand_keys:
        return None

    best = _fuzzy_match(name.lower(), brand_keys)
    if not best:
        return None

    matched_brand, score = best
    if score < threshold:
        return None

    generic = brand_map.get(matched_brand)
    if not generic:
        return None

    # If the mapped generic is itself a canonical generic, prefer the exact canonical name
    generics = load_generic_list()
    if generic in generics:
        return generic

    # Otherwise, keep the generic string from BRAND_LIST as the canonical label
    return generic


def normalize_single_medicine(name: str, threshold: int = 85) -> Optional[str]:
    if not name or is_garbage(name):
        return None

    name = name.strip()

    generic_from_brand = normalize_brand_name(name, threshold=threshold)
    if generic_from_brand:
        return generic_from_brand

    generic = _fuzzy_to_generic(name, threshold=threshold)
    if generic:
        return generic

    return None



def normalize_medicine_list(raw_text: str, threshold: int = 85) -> List[str]:
    if not raw_text:
        return []

    parts = re.split(
        r"[;,/+]|\band\b",
        raw_text,
        flags=re.IGNORECASE,
    )

    normalized: Set[str] = set()

    for part in parts:
        n = normalize_single_medicine(part, threshold=threshold)
        if n:
            normalized.add(n)

    return sorted(normalized)


def normalize_brand_and_generic(
    brand_text: str,
    generic_text: str,
    threshold: int = 85,
) -> List[str]:
    """
    Given brand + generic fields from one ADR report, return
    a list of unique canonical medicine names.

    - brand_text: brand name(s) field from Supabase
    - generic_text: generic name(s) field from Supabase
    """
    result: Set[str] = set()

    result.update(normalize_medicine_list(brand_text, threshold=threshold))
    result.update(normalize_medicine_list(generic_text, threshold=threshold))

    return list(result)
