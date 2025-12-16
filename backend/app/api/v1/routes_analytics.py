# backend/app/api/v1/routes_analytics.py

from fastapi import APIRouter, Query, Depends
from app.services.medicine_service import get_top_medicines, get_medicine_names
from app.services.analytics_service import get_raw_reaction_buckets
from app.services.reaction_cleaning_service import normalize_reaction_items


router = APIRouter(
    prefix="/api/v1/analytics",
    tags=["analytics"],
)

@router.get("/top-adrs")
def top_adrs(
    limit: int = Query(10, ge=1, le=100),
):
    # 1. get RAW buckets
    raw_items = get_raw_reaction_buckets()

    # 2. normalize using SINGLE source of truth
    result = normalize_reaction_items(raw_items)

    # 3. apply limit AFTER normalization
    result["items"] = result["items"][:limit]

    return result


@router.get("/top-medicines")
def top_medicines(limit: int = Query(50, ge=1, le=500)):
    """
    Returns normalized medicine names aggregated across ADR_Reports.medicineId.
    """
    return get_top_medicines(limit=limit)

@router.get("/medicine-names")
def medicine_names():
    """
    Returns a sorted list of canonical medicine names for dropdown filters.
    Example: ["Amlodipine", "Cetirizine", "Ibuprofen + Paracetamol", ...]
    """
    return get_medicine_names()