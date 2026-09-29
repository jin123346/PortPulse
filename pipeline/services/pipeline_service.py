# pipeline_service
#   → run 생성
#   → 전체 실행 순서 관리
#   → SUCCESS / FAILED / CANCELLE

from repositories.pipeline_repository import create_pipeline_run, update_pipeline_run_status,get_pipeline_run
from services.ship_call_service import run_ship_call_pipeline
from services.ship_call_control_service import run_ship_control_pipeline
import logging
from utils.report_writer import save_pipeline_report
from utils.date_util import to_api_date
logger = logging.getLogger(__name__)

# mode : ALL / SHIP_CALL / CONTROL

PIPELINE_NAME_MAP = {
    "ALL": "PORT_DATA_PIPELINE",
    "SHIP_CALL": "SHIP_CALL_PIPELINE",
    "CONTROL": "CONTROL_EVENT_PIPELINE",
}

def run_pipeline(
    mode:str,
    start_date:str,
    end_date:str,
    date_type: str,
    num_of_rows: int,
    port_code: str | None = None,
    run_id=None
):
    mode = mode.upper()
    if mode not in PIPELINE_NAME_MAP:
        raise ValueError(f"지원하지 않는 mode입니다: {mode}")
    pipeline_name = PIPELINE_NAME_MAP[mode]
    
    if run_id is None:
        run_id,run_key = create_pipeline_run(
            pipeline_name=pipeline_name,
            start_date=start_date,
            end_date=end_date
        )
    else:
        pipeline_run = get_pipeline_run(run_id)
        if pipeline_run is None:
            raise ValueError(
                f"존재하지 않는 run_id입니다: {run_id}"
            )
         # get_pipeline_run 반환값
        _,pipeline_name, run_key, saved_start_date, saved_end_date = pipeline_run
        # 기존 실행 조건 사용
        start_date = to_api_date(saved_start_date)
        end_date = to_api_date(saved_end_date)
        logger.info(
            "기존 pipeline Run 재개! run_id=%s, run_key=%s",
            run_id,
            run_key
        )
                     
    logger.info("pipeline Run 시작! run_id : %s, run_key : %s",run_id, run_key)
    results= []
    try:
        if mode in ("ALL", "SHIP_CALL"):
            ship_call_result= run_ship_call_pipeline(
                run_id = run_id,
                start_date=start_date,
                end_date=end_date,
                num_of_rows=num_of_rows,
                port_code=port_code,
                date_type=date_type
            )
            results.append(ship_call_result)
        
        if mode in ("ALL", "CONTROL"):   
            control_call_result = run_ship_control_pipeline(
                run_id=run_id,
                start_date=start_date,
                end_date=end_date,
                num_of_rows=num_of_rows,
                port_code=port_code,
                mode=mode
            )
            results.append(control_call_result)
        
        pipeline_status = determine_pipeline_status(results)
        report = {
            "run_id": run_id,
            "run_key": run_key,
            "pipeline_name": pipeline_name,
            "mode": mode,
            "status": pipeline_status,
            "start_date": start_date,
            "end_date": end_date,
            "results": results
        }

        update_pipeline_run_status(
            run_id=run_id,
            status=pipeline_status
        )
        
        save_pipeline_report(
            report=report,
            run_key=run_key
        )
        return report
    except KeyboardInterrupt:
            update_pipeline_run_status(
                run_id=run_id,
                status="CANCELLED",
                error_message="사용자에 의해 실행 중단됨"
            )
            error_message = "사용자에 의해 실행 중단됨"
            report = {
                "run_id": run_id,
                "run_key": run_key,
                "pipeline_name": pipeline_name,
                "mode": mode,
                "status": "CANCELLED",
                "start_date": start_date,
                "end_date": end_date,
                "results": results,
                "error_message": error_message
            }
            save_pipeline_report(
                report=report,
                run_key=run_key
            )
            logger.warning("사용자 중단 - run_id=%s", run_id)
            
            raise    
    except Exception as e: 
        error_message = f"{type(e).__name__}: {e}"
        update_pipeline_run_status(
            run_id=run_id,
            status="FAILED",
            error_message=error_message
        )
        report = {
            "run_id": run_id,
            "run_key": run_key,
            "pipeline_name": pipeline_name,
            "mode": mode,
            "status": "FAILED",
            "start_date": start_date,
            "end_date": end_date,
            "results": results,
            "error_message": error_message
        }

        save_pipeline_report(
            report=report,
            run_key=run_key
        )
        raise
 
        
            
    
        

    

def determine_pipeline_status(results: list[dict]) -> str:

    statuses = [result["status"] for result in results]

    if all(status == "SUCCESS" for status in statuses):
        return "SUCCESS"

    if all(status == "FAILED" for status in statuses):
        return "FAILED"

    return "PARTIAL_SUCCESS"