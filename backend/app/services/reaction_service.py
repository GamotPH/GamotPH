from typing import Dict, List
from supabase import create_client
from app.normalization.reaction_normalizer import normalize_single_reaction

# Initialize Supabase connection
# This uses your SUPABASE_URL and SUPABASE_KEY from env
from app.config import settings
supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)


def fetch_reactions(start, end, medicine=None) -> Dict:
    """Fetch raw reactions from ADR_Reports, normalize and group them."""

    query = (
        supabase.table("ADR_Reports")
        .select("reactionDescription, medicine_name, generic_name, created_at")
        .gte("created_at", start.isoformat())
        .lt("created_at", end.isoformat())
    )

    if medicine:
        query = query.ilike("generic_name", f"%{medicine}%")

    data = query.execute().data or []

    counts = {}
    total = 0

    for row in data:
        raw = row.get("reactionDescription", "")
        if not raw:
            continue

        normalized = normalize_single_reaction(raw)
        if not normalized:
            continue

        total += 1
        counts[normalized] = counts.get(normalized, 0) + 1

    # Convert to top 5 + Other
    sorted_items = sorted(counts.items(), key=lambda x: x[1], reverse=True)
    top5 = sorted_items[:5]
    other_sum = sum(x[1] for x in sorted_items[5:])

    result = []
    for label, count in top5:
        pct = round((count / total) * 100, 1) if total > 0 else 0
        result.append({"label": label, "count": count, "pct": pct})

    if other_sum > 0:
        pct_other = round((other_sum / total) * 100, 1)
        result.append({"label": "Other", "count": other_sum, "pct": pct_other})

    return {"total": total, "items": result}
