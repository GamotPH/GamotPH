from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import routes_analytics

app = FastAPI(title="GAMOTPH Backend")

# (optional CORS – if you already have it, keep as is)
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

# include analytics routes
app.include_router(routes_analytics.router)
