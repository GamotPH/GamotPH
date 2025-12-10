import os
from pathlib import Path

from supabase import create_client, Client
from dotenv import load_dotenv

# Find backend/.env based on this file's location
BASE_DIR = Path(__file__).resolve().parents[2]  # .../GAMOTPH/backend
ENV_PATH = BASE_DIR / ".env"

# Load variables from backend/.env
load_dotenv(dotenv_path=ENV_PATH)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError(
        "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in environment or .env file"
    )

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
