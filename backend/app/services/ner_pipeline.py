from typing import List

from app.models.ner_model import extract_adr_mentions
from app.normalization.adr_normalizer import normalize_adr


def extract_and_normalize_adrs(text: str, threshold: int = 85) -> List[str]:
    """
    1. Use NER model to extract ADR-like spans from text.
    2. Normalize each span to a canonical ADR term via fuzzy matching.
    3. Deduplicate the final list.
    """
    mentions = extract_adr_mentions(text)
    normalized: List[str] = []

    for mention in mentions:
        norm = normalize_adr(mention, threshold=threshold)
        if norm and norm not in normalized:
            normalized.append(norm)

    return normalized
