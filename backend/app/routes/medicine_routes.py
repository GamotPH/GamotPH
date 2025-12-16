# app/routes/medicine_routes.py

from fastapi import APIRouter
from app.services.medicine_service import get_medicine_names

router = APIRouter(prefix="/api/v1/medicines", tags=["Medicines"])

@router.get("/canonical-generics")
def canonical_generics():
    return get_medicine_names()

