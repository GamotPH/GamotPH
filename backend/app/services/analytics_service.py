# backend/app/services/analytics_service.py

from collections import Counter
from app.db.supabase_client import supabase

ADR_TABLE_NAME = "ADR_Reports"
ADR_RAW_COLUMN = "reactionDescription"


def get_raw_reaction_buckets(
    start=None,
    end=None,
    medicine: str | None = None,
) -> list[dict]:
    """
    Fetch RAW reactionDescription values and aggregate counts.
    NO normalization here.
    """

    query = supabase.table(ADR_TABLE_NAME).select(ADR_RAW_COLUMN)

    if start:
        query = query.gte("created_at", start.isoformat())
    if end:
        query = query.lt("created_at", end.isoformat())
    if medicine:
        query = query.eq("canonical_generic", medicine)  # or medicineId mapping

    rows = query.execute().data or []

    counter: Counter[str] = Counter()

    for row in rows:
        raw = (row.get(ADR_RAW_COLUMN) or "").strip()
        if not raw:
            continue
        counter[raw] += 1

    return [
        {"text": text, "count": count}
        for text, count in counter.items()
    ]
