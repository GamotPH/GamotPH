from datetime import datetime

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import routes_analytics
# ✅ NEW: include our reaction-cleaning router
from app.services.reaction_cleaning_service import (
    router as reaction_cleaning_router,
)

app = FastAPI(title="GAMOTPH Backend")

# CORS – keep as-is or restrict later
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# health check
@app.get("/health")
def health_check():
    return {"status": "ok"}

# ✅ Existing analytics routes (medicine names, etc.)
app.include_router(routes_analytics.router)

# ✅ NEW: normalized reactions endpoint
# (POST /api/v1/analytics/normalize-reactions)
app.include_router(reaction_cleaning_router)

# ❌ OLD: REMOVE this block completely
# from app.services.reaction_service import fetch_reactions
# @app.get("/api/v1/analytics/reactions")
# def get_reactions(start: str, end: str, medicine: str | None = None):
#     start_dt = datetime.fromisoformat(start)
#     end_dt = datetime.fromisoformat(end)
#     return fetch_reactions(start_dt, end_dt, medicine)
