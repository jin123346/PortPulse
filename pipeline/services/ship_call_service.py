# 입출항 API 수집 orchestration
from db.postgres import get_target_ports
import logging
from repositories.api_request_repository import update_api_request_status,insert_api_request
from repositories.ship_call_repository import save_ship_calls
from collectors.mof_ship_call import fetch_ship_calls
import math

logger = logging.getLogger(__name__)


def run_ship_call_pipeline(
    run_id:int,
    start_date:str,
    end_date:str,
    num_of_rows:int,
    date_type: str,
    port_code:int | None=None,
):
    try:
        if port_code:
                    ports = [port_code]
        else:
            ports = get_target_ports()

        logger.info("======================================")
        logger.info("선박 입출항 데이터 수집 시작")
        logger.info("조회 기간: %s ~ %s", start_date, end_date)
        logger.info("조회 기준: %s", date_type)
        logger.info("페이지당 조회 건수: %s", num_of_rows)
        logger.info("수집 대상 항구 수: %s", len(ports))
        logger.debug("수집 대상 항구: %s", ports)
        logger.info("======================================")
        success_count = 0
        empty_count = 0
        failure_count = 0
        failed_items = []
        for port_code in ports:
            api_request_id = None
            total_count = None
            total_pages = None
            try:
                # =========================================
                # 0. API 요청기록 생성 (api_request)
                # =========================================
                api_request_id,request_id = insert_api_request(
                    run_id = run_id,
                    source_type="SHIP_CALL",
                    port_code=port_code,
                    start_date=start_date,
                    end_date=end_date,
                    date_type=date_type,
                    page_no=1,
                    num_of_rows=num_of_rows,
                )
                logger.info("api_request_id 생성완료! id : %s, request_id: %s, page_no: %s ",api_request_id,request_id,1)
                

                # =========================================
                # 1. 첫 페이지 조회
                # =========================================
                ship_calls, total_count = fetch_ship_calls(
                    port_code= port_code,
                    start_date=start_date,
                    end_date=end_date,
                    date_type=date_type,
                    call_sign=None,
                    page_no=1,
                    num_of_rows=num_of_rows
                )
                logger.info(
                    "항구 코드 %s API 조회 완료 - total_count=%s",
                    port_code,
                    total_count
                )
                # =========================================
                # 2. 조회 결과 없음
                # =========================================
                if total_count == 0:
                    update_api_request_status(
                                            api_request_id=api_request_id,
                                            total_count=total_count,
                                            total_pages=total_pages,
                                            response_count=0,
                                            detail_count=0,
                                            status="SUCCESS"
                                        )
                    logger.info("항구 코드: %s 조회 데이터 없음", port_code)
                    empty_count += 1
                    continue

            
                # =========================================
                # 3. 전체 페이지 수 계산
                # =========================================
                total_pages = math.ceil(
                    total_count / num_of_rows
                )
                
                logger.info(
                    "항구 코드 %s - 총 %s건 / %s페이지",
                    port_code,
                    total_count,
                    total_pages
                )

                # =========================================
                # 4. 첫 페이지 저장
                # =========================================
                if ship_calls:
                    
                    save_ship_calls(ship_calls,api_request_id,total_count,total_pages)
                    logger.info(
                        "항구 코드 %s 페이지 1 저장 완료 - %s건",
                        port_code,
                        len(ship_calls)
                    )

                # =========================================
                # 5. 2페이지 이후 처리
                # =========================================
                for page_no in range(2, total_pages+1):
                    # 1. 요청 기록 먼저 생성
                    api_request_id,request_id = insert_api_request(
                                                    run_id= run_id,
                                                    source_type="SHIP_CALL",
                                                    port_code=port_code,
                                                    start_date=start_date,
                                                    end_date=end_date,
                                                    date_type=date_type,
                                                    num_of_rows=num_of_rows,
                                                    page_no=page_no,
                                                )
                    logger.info(
                        "항구 코드 %s 페이지 %s/%s 수집 시작",
                        port_code,
                        page_no,
                        total_pages
                    )
                    # 2. 실제 API 요청
                    ship_calls,_ = fetch_ship_calls(
                        port_code=port_code,
                        start_date=start_date,
                        end_date=end_date,
                        date_type=date_type,
                        call_sign=None,
                        page_no=page_no,
                        num_of_rows=num_of_rows
                    )
                    
                    # 3. 조회 결과 없음
                    if not ship_calls:
                        update_api_request_status(
                            api_request_id=api_request_id,
                            total_count=total_count,
                            total_pages=total_pages,
                            response_count=0,
                            detail_count=0,
                            status="SUCCESS"
                        )
                        logger.info(
                            "항구 코드 %s 페이지 %s 조회 결과 없음 - 페이지 처리 종료",
                            port_code,
                            page_no
                        )
                        break
                    
                    total_count_t= len(ship_calls)
                    logger.info("%s페이지 요청시 총 데이터 수 :%s ",page_no,total_count_t)

                    
                    
                    # 저장로직 
                    save_ship_calls(
                        ship_calls,
                        api_request_id,
                        total_count,
                        total_pages
                    )

                    logger.info(
                        "항구 코드 %s 페이지 %s/%s 저장 완료 - %s건",
                        port_code,
                        page_no,
                        total_pages,
                        total_count
                    )

                success_count+=1
                logger.info(
                    "항구 코드 %s 전체 처리 완료 - 총 %s건 / %s페이지",
                    port_code,
                    total_count,
                    total_pages
                )
                
            except Exception as e:
                failure_count += 1
                if api_request_id is not None:
                    try:
                        update_api_request_status(
                            api_request_id=api_request_id,
                            total_count=total_count,
                            total_pages=total_pages,
                            status="FAILED",
                            error_message=f"{type(e).__name__}: {str(e)}"
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
                logger.exception(
                    "항구 코드 %s 처리 실패",
                    port_code
                )
                continue
        # =========================================
        # 전체 실행 결과
        # =========================================
        processed_count = success_count + empty_count

        if failure_count == 0:
            service_status = "SUCCESS"

        elif processed_count > 0:
            service_status = "PARTIAL_SUCCESS"

        else:
            service_status = "FAILED"

        return {
                "source_type": "SHIP_CALL",
                "status": service_status,
                "success_count": success_count,
                "empty_count": empty_count,
                "failure_count": failure_count,
                "total_ports": len(ports),
                "failed_items": failed_items,
            }
    except KeyboardInterrupt:
        logger.warning(
            "선박 입출항 데이터 수집 사용자 중단 - run_id=%s",
            run_id
        )
        raise

    except Exception as e:
        logger.exception(
            "선박 입출항 서비스 실행 실패 - run_id=%s, error=%s",
            run_id,
            e
        )
        raise
    