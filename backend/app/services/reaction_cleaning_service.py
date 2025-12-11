# backend/app/services/reaction_cleaning_service.py

from typing import Dict, List, Optional
from fastapi import APIRouter
from pydantic import BaseModel

# ✅ Use your existing ADR normalizer
from app.normalization.adr_normalizer import normalize_adr, normalize_adr_list

# ✅ Try to import NER; if it doesn't exist or fails, we'll just not use it
try:
    from app.services.ner_pipeline import extract_adr_mentions  # type: ignore
except Exception:  # pragma: no cover
    extract_adr_mentions = None  # type: ignore


router = APIRouter(
    prefix="/api/v1/analytics",
    tags=["analytics"],
)


# ---------- Pydantic models ----------

class RawReactionItem(BaseModel):
    text: str
    count: int


class NormalizeReactionsRequest(BaseModel):
    items: List[RawReactionItem]


class NormalizedReactionItem(BaseModel):
    label: str
    count: int


class NormalizeReactionsResponse(BaseModel):
    items: List[NormalizedReactionItem]


# ---------- Helpers ----------

def _clean(s: str) -> str:
    return " ".join(s.strip().split())


def _canon(s: str) -> str:
    return _clean(s).lower()


# ---------- Endpoint ----------

@router.post(
    "/normalize-reactions",
    response_model=NormalizeReactionsResponse,
)
async def normalize_reactions(
    payload: NormalizeReactionsRequest,
) -> NormalizeReactionsResponse:
    """
    Combine NER (if available) + ADR normalizer to clean reactionDescription.

    For each input item:
      - `text`  = raw reactionDescription (or bucket label)
      - `count` = how many ADR_Reports rows had that text

    Steps:
      1. Try NER (if `extract_adr_mentions` is available) to get ADR phrases.
      2. For each phrase, use `normalize_adr` to map to canonical ADR.
      3. If NER finds nothing OR NER is not available:
         - Use `normalize_adr_list` on the whole text as a fallback.
      4. If absolutely nothing normalizes, bucket under "Unspecified".
      5. Aggregate counts per canonical ADR label.
    """
    aggregated: Dict[str, int] = {}
    display_label: Dict[str, str] = {}

    for item in payload.items:
        raw_text = _clean(item.text)
        if not raw_text:
            continue

        # number of ADR_Reports rows represented by this text
        weight = max(item.count, 1)

        mentions: List[str] = []

        # 1) Try NER, if available
        if extract_adr_mentions is not None:
            try:
                maybe = extract_adr_mentions(raw_text)  # type: ignore
                if maybe:
                    # ensure clean unique mentions
                    seen: set[str] = set()
                    for m in maybe:
                        m_clean = _clean(str(m))
                        if m_clean and m_clean.lower() not in seen:
                            mentions.append(m_clean)
                            seen.add(m_clean.lower())
            except Exception:
                # if NER blows up, just ignore it
                mentions = []

        # 2) Fallback: if NER gave us nothing, use your normalize_adr_list
        if not mentions:
            # this returns a list of canonical ADR labels already
            try:
                normalized_list = normalize_adr_list(raw_text)
            except Exception:
                normalized_list = []

            # if normalize_adr_list returns things, treat those as mentions
            if normalized_list:
                mentions = normalized_list
            else:
                # last-resort: single mention = original text
                mentions = [raw_text]

        # 3) Normalize each mention to canonical ADR using normalize_adr
        for mention in mentions:
            try:
                canon_label: Optional[str] = normalize_adr(mention)
            except Exception:
                canon_label = None

            if not canon_label:
                canon_label = "Unspecified"

            key = _canon(canon_label)
            display_label.setdefault(key, canon_label)
            aggregated[key] = aggregated.get(key, 0) + weight

    # Build sorted response
    items = [
        NormalizedReactionItem(label=display_label[k], count=v)
        for k, v in sorted(
            aggregated.items(), key=lambda kv: kv[1], reverse=True
        )
    ]

    return NormalizeReactionsResponse(items=items)
