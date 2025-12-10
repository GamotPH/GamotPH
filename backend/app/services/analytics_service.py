from collections import Counter

from app.db.supabase_client import supabase
from app.normalization.adr_normalizer import normalize_adr_list

ADR_TABLE_NAME = "ADR_Reports"
ADR_RAW_COLUMN = "reactionDescription"


def get_top_adrs(limit: int | None = None) -> list[dict]:
    """
    Fetch ADR reaction descriptions from Supabase,
    normalize them with fuzzy matching, and aggregate counts.
    """
    resp = supabase.table(ADR_TABLE_NAME).select(ADR_RAW_COLUMN).execute()
    rows = resp.data or []

    counter: Counter[str] = Counter()

    for row in rows:
        raw = row.get(ADR_RAW_COLUMN) or ""
        adrs = normalize_adr_list(raw)  # handles strings with one or many ADRs

        for adr in adrs:
            counter[adr] += 1

    items = [{"adr": adr, "count": count} for adr, count in counter.most_common()]

    if limit is not None:
        items = items[:limit]

    return items
