# 관제 API 수집 orchestration
from repositories.api_request_repository import get_list_for_control,update_api_request_status,insert_api_request
from db.postgres import get_connection,get_target_ports
from collectors.mof_ship_control_call import fetch_ship_control_call
from repositories.ship_control_repository import save_ship_call_control_data
from parser.parser import parse_mof_items_xml
from utils.date_util import to_api_date
import math
import logging

logger = logging.getLogger(__name__)

def run_ship_control_pipeline(
    run_id:int | None = None,
    port_code : str | None=None,
    start_date : str | None=None,
    end_date : str | None=None,
    num_of_rows:int = 50,
    mode: str="ALL"
):
    success_count = 0
    empty_count = 0
    failure_count = 0
    failed_items = []
    try:
        # =====================================================
        # 1. 실행 대상 결정
        # =====================================================
        if mode=="ALL":
            if run_id is None:
                raise ValueError("ALL 모드에서는 run_id가 필요합니다.")
            param_list = get_list_for_control(run_id=run_id)
            
        elif mode == "CONTROL":
            if start_date is None or end_date is None:
                raise ValueError(
                    "CONTROL 모드에서는 start_date, end_date가 필요합니다."
                )
            # 관제 단독 실행
            if port_code:
                ports = [port_code]
            else:
                ports = get_target_ports()

            param_list = [
                (port, start_date, end_date)
                for port in ports
            ]
        else:
            raise ValueError(
                f"지원하지 않는 mode입니다: {mode}"
            )
        logger.info("관제정보 수집 시작 - run_id=%s, mode=%s, 대상=%s건",
            run_id,mode,len(param_list))
        
        # =====================================================
        # 2. 항구별 처리
        # =====================================================
        for port_code, start_date, end_date in param_list:
            
            api_request_id = None
            total_count = None
            total_pages = None
            try:
                # -----------------------------------------
                # API 요청 이력 생성
                # -----------------------------------------
                api_request_id, request_id = insert_api_request(
                    run_id=run_id,
                    source_type="CONTROL_EVENT",
                    port_code=port_code,
                    start_date=start_date,
                    end_date=end_date,
                    date_type=None,
                    page_no=1,
                    num_of_rows=num_of_rows,
                )
                # -----------------------------------------
                # 1. 1페이지 조회 → total_count 확인
                # -----------------------------------------
                result = fetch_ship_control_call(
                    port_code=port_code,
                    start_date=to_api_date(start_date),
                    end_date =to_api_date(end_date),
                    num_of_rows= num_of_rows,
                    page_no=1
                )
                
                #parser
                
                items, total_count = parse_mof_items_xml(result.text)
                logger.info("관제 정보 parsing 완료  total_count = %s",total_count)
                # -----------------------------------------
                # 조회 결과 없음
                # -----------------------------------------
                if total_count ==0:
                    update_api_request_status(
                        api_request_id=api_request_id,
                        total_count=0,
                        total_pages=0,
                        response_count=0,
                        detail_count=0,
                        status="SUCCESS"
                    )
                    empty_count +=1
                    logger.info("관제정보 조회 결과 없음 - port=%s",port_code)
                    continue
                
                total_pages = math.ceil( total_count / num_of_rows)
                logger.info("관제정보 수집 - port=%s, total=%s,pages=%s",port_code,total_count,total_pages)
                # -----------------------------------------
                # 2. 전체 페이지 처리
                # -----------------------------------------
                for current_page in range(1, total_pages + 1):
                    

                    # 1페이지는 이미 조회했으므로 재사용
                    if current_page == 1:
                        page_items = items

                    else:
                        # -----------------------------------------
                        # API 요청 이력 생성
                        # -----------------------------------------
                        api_request_id, request_id = insert_api_request(
                            run_id=run_id,
                            source_type="CONTROL_EVENT",
                            port_code=port_code,
                            start_date=start_date,
                            end_date=end_date,
                            date_type=None,
                            page_no=current_page,
                            num_of_rows=num_of_rows,
                        )
                        result =  fetch_ship_control_call(
                                        port_code=port_code,
                                        start_date=to_api_date(start_date),
                                        end_date =to_api_date(end_date),
                                        num_of_rows= num_of_rows,
                                        page_no=current_page
                                    )
                        page_items, _ = parse_mof_items_xml(result.text)
                        
                    

                    # -----------------------------------------
                    # RAW 저장
                    # -----------------------------------------
                    save_ship_call_control_data(
                        items=page_items,
                        total_count=total_count,
                        total_pages=total_pages,
                        api_request_id=api_request_id
                    )
                    # 모든 페이지 완료
                success_count += 1
                logger.info("관제정보 %s 항구 처리 완료", port_code)
            # =================================================
            # 항구 하나 실패 → 다음 항구 계속
            # =================================================
            except Exception as e:
                failure_count += 1
                if api_request_id is not None:
                    try:
                        update_api_request_status(
                            api_request_id=api_request_id,
                            total_pages=total_pages,
                            total_count=total_count,
                            status="FAILED",
                            error_message=f"{type(e).__name__}: {e}"
                        )
                        failed_items.append({
                            "port_code": port_code,
                            "api_request_id": api_request_id,
                            "error_type": type(e).__name__,
                            "error_message": str(e),
                        })
                    except Exception:
                        logger.exception(
                            "FAILED 상태 기록 실패 - api_request_id=%s",
                            api_request_id
                        )

                logger.exception( "관제정보 처리 실패 - port=%s",
                    port_code )

                continue
    # =====================================================
    # 3. Service 결과
    # =====================================================
        processed_count = success_count + empty_count
        if failure_count == 0:
            service_status = "SUCCESS"

        elif processed_count > 0:
            service_status = "PARTIAL_SUCCESS"

        else:
            service_status = "FAILED"

        return {
            "source_type": "CONTROL_EVENT",
            "status": service_status,
            "success_count": success_count,
            "empty_count": empty_count,
            "failure_count": failure_count,
            "total_ports": len(param_list),
            "failed_items": failed_items,
        }

    except KeyboardInterrupt:
        if api_request_id is not None:
            try:
                update_api_request_status(
                    api_request_id=api_request_id,
                    total_count=total_count,
                    total_pages=total_pages,
                    status="CANCELLED",
                    error_message="사용자에 의해 실행 중단됨"
                )
            except Exception:
                logger.exception(
                    "api_request CANCELLED 상태 기록 실패 "
                    "- api_request_id=%s",
                    api_request_id
                )
        logger.warning(
            "관제정보 수집 사용자 중단 "
            "- run_id=%s, api_request_id=%s",
            run_id,
            api_request_id
        )
        raise
    except Exception:
        logger.exception(
            "관제정보 서비스 실행 실패 - run_id=%s",
            run_id
        )
        raise