import os
import logging

from dotenv import load_dotenv
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
LOG_DIR = BASE_DIR / "logs"

load_dotenv()

DB_CONFIG={
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT"),
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD")
}

SERVICE_KEY=os.getenv("SERVICE_KEY")
MOF_SHIP_CALL_URL=os.getenv("MOF_SHIP_CALL_URL")
MOF_SHIP_CALL_CONTROL_URL=os.getenv("MOF_SHIP_CALL_CONTROL_URL")


# def setup_logging():
#     logging.basicConfig(
#         level=logging.INFO,
#         format=(
#             "%(asctime)s "
#             "[%(levelname)s] "
#             "%(name)s - "
#             "%(message)s"
#         )
#     )