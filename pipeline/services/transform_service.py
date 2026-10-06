import logging
from repositories.mart_repository import load_mart_data
from repositories.fact_repository import load_fact_ship_call, load_fact_control_event
from repositories.monitoring_repository import get_monitoring_summary

logger = logging.getLogger(__name__)

def run_transform_service(
    mode: str = "ALL",
    start_date: str | None=None,
    end_date: str | None=None,
    run_id: int | None=None,
    port_code: str = None
):

    """fact → 관제 이벤트 → mart 전체 재계산.
    start_date / end_date / port_code / mode는 부분 재계산용 예약 인자 (아직 미지원, 넘겨도 무시됨)."""
    logger.info("Transform Service 시작 - run_id=%s, mode=%s", run_id, mode)

    steps = [
        ("fact_ship_call",     load_fact_ship_call),
        ("fact_control_event", load_fact_control_event),
        ("mart_port_daily_kpi", load_mart_data),
    ]
    result = {"source_type": "TRANSFORM", "status": "SUCCESS",
              "steps": {}, "failed_step": None, "monitoring": None, "error_message": None}
    logger.info("Transform Service 종료 - run_id=%s, mode=%s", run_id, mode)

    for name, func in steps:
        try:
            result["steps"][name]=func()
        except Exception as e:
            logger.exception("Transform 단계 실패 - %s",name)
            result.update(status="FAILED",
                          failed_step=name,
                          error_message=f"{type(e).__name__}:{e}")
            break
    if result["status"] == "SUCCESS":
        try:
            result["monitoring"] = get_monitoring_summary()
        except Exception:
            logger.exception("모니터링 요약 실패 — 적재 결과에는 영향 없음")
            result["monitoring"] = None
        
    logger.info("Transform Service 종료 - run_id=%s , status=%s",run_id,result["status"])
    return result