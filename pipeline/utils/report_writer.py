import json
from pathlib import Path
from datetime import datetime, date


REPORT_DIR = Path("reports")


def save_pipeline_report(report: dict,run_key:str) -> str:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    run_id = report["run_id"]
    now = datetime.now().strftime("%Y%m%d_%H%M%S")

    file_path = REPORT_DIR / f"{run_key}_{now}.json"

    with file_path.open("w", encoding="utf-8") as f:
        json.dump(
            report,
            f,
            ensure_ascii=False,
            indent=2,
            default=_json_serializer
        )

    return str(file_path)


def _json_serializer(obj):
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()

    raise TypeError(
        f"Object of type {type(obj).__name__} is not JSON serializable"
    )