import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from app.api.v1 import routes_analytics
from app.services.reaction_cleaning_service import (
    router as reaction_cleaning_router,
)
from app.routes.medicine_routes import router as medicine_router

# Load backend/.env so local configuration is available outside the DB module.
BASE_DIR = Path(__file__).resolve().parents[1]
load_dotenv(BASE_DIR / ".env")

ENV = os.getenv("ENV", "development")
IS_PROD = ENV == "production"

app = FastAPI(
    title="GAMOTPH Backend",
    docs_url=None if IS_PROD else "/docs",
    redoc_url=None if IS_PROD else "/redoc",
)

allowed_origins = os.getenv("ALLOWED_ORIGINS", "")
origins = [o.strip() for o in allowed_origins.split(",") if o.strip()]

default_origins = [
    "https://gamotph-client.onrender.com",
    "https://gamotph.aiproject-nationalu.com",
    "http://localhost:5173",
    "http://localhost:3000",
]

allow_origins = list(dict.fromkeys([*default_origins, *origins]))

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(medicine_router)
app.include_router(routes_analytics.router)
app.include_router(reaction_cleaning_router)

@app.get("/health")
def health_check():
    return {"status": "ok"}
