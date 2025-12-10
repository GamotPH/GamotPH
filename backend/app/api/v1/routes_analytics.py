from fastapi import APIRouter, Query

from app.services.analytics_service import get_top_adrs
from app.services.medicine_service import get_top_medicines, get_medicine_names

router = APIRouter(
    prefix="/api/v1/analytics",
    tags=["analytics"],
)


@router.get("/top-adrs")
def top_adrs(limit: int = Query(10, ge=1, le=100)):
    return get_top_adrs(limit=limit)


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