from collections import Counter
from typing import Dict, List, Optional

from app.db.supabase_client import supabase
from app.normalization.medicine_normalizer import normalize_brand_and_generic

# Table and column names
ADR_TABLE_NAME = "ADR_Reports"
ADR_MED_ID_COL = "medicineId"  # FK column in ADR_Reports

MED_TABLE_NAME = "Medicines"   # master medicines table
MED_ID_COL = "id"              # PK in Medicines
MED_BRAND_COL = "brandName"    # brand name column in Medicines
MED_GENERIC_COL = "genericName"  # generic name column in Medicines


def _load_medicine_master() -> Dict[int, str]:
    """
    Load all medicines from the Medicines table and normalize each one
    into a single canonical name (mostly generic), using brand + generic.
    Returns a mapping: medicineId (int) -> canonical_name (str)
    """
    select_cols = f"{MED_ID_COL}, {MED_BRAND_COL}, {MED_GENERIC_COL}"
    resp = supabase.table(MED_TABLE_NAME).select(select_cols).execute()
    rows = resp.data or []

    med_map: Dict[int, str] = {}

    for row in rows:
        med_id = row.get(MED_ID_COL)
        if med_id is None:
            continue

        brand_text = row.get(MED_BRAND_COL) or ""
        generic_text = row.get(MED_GENERIC_COL) or ""

        # normalize_brand_and_generic returns a list of canonical names.
        # For most cases this will be [one_name]; if more, we just pick the first.
        names = normalize_brand_and_generic(brand_text, generic_text)
        if not names:
            # No good match in GENERIC_LIST/BRAND_LIST → treat as unknown / skip
            continue

        canonical_name = names[0]
        med_map[med_id] = canonical_name

    return med_map


def _fetch_adr_medicine_ids(limit: Optional[int] = None) -> List[dict]:
    """
    Fetch medicineId from ADR_Reports.
    """
    query = supabase.table(ADR_TABLE_NAME).select(ADR_MED_ID_COL)
    if limit is not None:
        query = query.limit(limit)

    resp = query.execute()
    return resp.data or []


def get_top_medicines(limit: Optional[int] = None) -> List[dict]:
    """
    Aggregate ADR counts per canonical medicine.

    Steps:
      - Load master medicine mapping: id -> canonical name
      - Fetch all ADR_Reports.medicineId
      - Count occurrences per canonical name
    """
    med_map = _load_medicine_master()
    rows = _fetch_adr_medicine_ids(None)  # fetch all; can optimize later

    counter: Counter[str] = Counter()

    for row in rows:
        med_id = row.get(ADR_MED_ID_COL)
        if med_id is None:
            continue

        canonical = med_map.get(med_id)
        if not canonical:
            # medicineId exists in ADR_Reports but not in our mapped master (or was skipped)
            continue

        counter[canonical] += 1

    items = [{"medicine": med, "count": count} for med, count in counter.most_common()]

    if limit is not None:
        items = items[:limit]

    return items

def get_medicine_names() -> list[str]:
    items = get_top_medicines(limit=None)

    names = {
        item["medicine"]
        for item in items
        if isinstance(item.get("medicine"), str)
    }

    return sorted(names)
