import logging
from repositories.mart_repository import load_mart_data
from repositories.fact_repository import load_fact_ship_call, load_fact_control_event
logger = logging.getLogger(__name__)
def run_transform_service(
    start_date: str,
    end_date: str,
    mode: str = "ALL",
    run_id: int = None,
    port_code: str = None
):
    
    logger.info("Transform Service 시작 - run_id=%s, mode=%s", run_id, mode)

    load_fact_ship_call()
    load_fact_control_event()
    load_mart_data()

    logger.info("Transform Service 종료 - run_id=%s, mode=%s", run_id, mode)
    