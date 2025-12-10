from app.db.supabase_client import supabase
from app.normalization.adr_normalizer import normalize_adr_list


def backfill_reaction_normalized(page_size: int = 1000):
    """
    Fills the reaction_normalized column in adr_reports using fuzzy ADR normalization.
    Runs in pages to avoid loading everything at once.
    """
    offset = 0

    while True:
        # Fetch a page of rows
        resp = (
            supabase
            .table("adr_reports")
            .select("id, reaction, reaction_normalized")
            .range(offset, offset + page_size - 1)
            .execute()
        )

        rows = resp.data or []
        if not rows:
            break  # no more data

        updates = []

        for row in rows:
            # Skip rows that are already normalized
            if row.get("reaction_normalized"):
                continue

            raw = row.get("reaction") or ""
            normalized_list = normalize_adr_list(raw)

            # If nothing could be normalized, you can choose to leave it null
            normalized_str = ", ".join(normalized_list) if normalized_list else None

            updates.append({
                "id": row["id"],
                "reaction_normalized": normalized_str,
            })

        if updates:
            supabase.table("adr_reports").upsert(updates).execute()
            print(f"Updated {len(updates)} rows (offset {offset})")

        offset += page_size

    print("Backfill completed.")


if __name__ == "__main__":
    backfill_reaction_normalized()
