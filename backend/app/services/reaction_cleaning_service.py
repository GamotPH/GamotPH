# backend/app/services/reaction_cleaning_service.py

from typing import Dict, List
from fastapi import APIRouter
from pydantic import BaseModel

# Canonical ADR normalizer (single source of truth)
from app.normalization.adr_normalizer import normalize_adr, normalize_adr_list

# Medical vs garbage classifier
from app.normalization.reaction_classifier import is_garbage, is_medical_like

# Optional NER (safe fallback)
try:
    from app.services.ner_pipeline import extract_adr_mentions  # type: ignore
except Exception:  # pragma: no cover
    extract_adr_mentions = None  # type: ignore


# ---------- Helpers ----------

def _clean(s: str) -> str:
    return " ".join(s.strip().split())


def _canon(s: str) -> str:
    return _clean(s).lower()


# ---------- Core normalizer ----------

def normalize_reaction_items(items: list[dict]) -> dict:
    aggregated: Dict[str, int] = {}
    display_label: Dict[str, str] = {}

    for item in items:
        raw_text = _clean(item.get("text", ""))
        if not raw_text:
            continue

        weight = max(item.get("count", 1), 1)
        mentions: List[str] = []

        # 1️⃣ Try NER first (if available)
        if extract_adr_mentions is not None:
            try:
                maybe = extract_adr_mentions(raw_text)
                if maybe:
                    seen = set()
                    for m in maybe:
                        m_clean = _clean(str(m))
                        if m_clean and m_clean.lower() not in seen:
                            mentions.append(m_clean)
                            seen.add(m_clean.lower())
            except Exception:
                mentions = []

        # 2️⃣ Fallback: fuzzy ADR list
        if not mentions:
            try:
                normalized_list = normalize_adr_list(raw_text)
            except Exception:
                normalized_list = []

            mentions = normalized_list if normalized_list else [raw_text]

        # 3️⃣ Canonicalize + classify
        for mention in mentions:
            canon = normalize_adr(mention)

            if canon:
                label = canon
            elif is_garbage(mention):
                continue  # 🔥 DROP GARBAGE COMPLETELY
            elif is_medical_like(mention):
                label = "Medical (Unmapped)"
            else:
                continue  # 🔥 DROP UNKNOWN JUNK

            key = _canon(label)
            display_label.setdefault(key, label)
            aggregated[key] = aggregated.get(key, 0) + weight

    return {
        "items": [
            {"label": display_label[k], "count": v}
            for k, v in sorted(
                aggregated.items(), key=lambda kv: kv[1], reverse=True
            )
        ]
    }


# ---------- API ----------

router = APIRouter(
    prefix="/api/v1/analytics",
    tags=["analytics"],
)


class RawReactionItem(BaseModel):
    text: str
    count: int


class NormalizeReactionsRequest(BaseModel):
    items: List[RawReactionItem]


@router.post("/normalize-reactions")
async def normalize_reactions(payload: NormalizeReactionsRequest):
    return normalize_reaction_items([item.dict() for item in payload.items])
