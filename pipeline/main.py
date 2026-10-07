import argparse
from config.log_setting import setup_logging
import logging
from services.pipeline_service import run_pipeline
from utils.report_writer import save_pipeline_report
# 로직 순서 
# collect_ship_call
#         ↓
# collect_control_event
#         ↓
# transform_fact
#         ↓
# build_mart

setup_logging()

logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(
        description="""
Port Pulse - 항만 데이터 수집 파이프라인

해양수산부(MOF) API를 이용하여
선박 입출항 정보 및 관제정보를 수집하고 RAW 영역에 저장합니다.

실행 모드:
  ALL        선박 입출항 → 관제정보 순서로 전체 파이프라인 실행
  SHIP_CALL  선박 입출항 데이터만 수집
  CONTROL    관제정보 데이터만 수집

항구 코드:
  --port-code를 지정하면 해당 항구만 수집합니다.
  지정하지 않으면 DB에 등록된 수집 대상 항구 전체를 대상으로 실행합니다.

예:
  부산항 코드: 020
  인천항 코드: 030
""",
        epilog="""
사용 예시:

  # 전체 파이프라인 실행
  python main.py --mode ALL --start-date 20260901 --end-date 20260929

  # 부산항 전체 파이프라인 실행
  python main.py --mode ALL --start-date 20260901 --end-date 20260929 --port-code 020

  # 입항 데이터만 수집
  python main.py --mode SHIP_CALL --start-date 20260901 --end-date 20260929 --date-type I

  # 출항 데이터만 수집
  python main.py --mode SHIP_CALL --start-date 20260901 --end-date 20260929 --date-type O

  # 부산항 관제정보만 수집
  python main.py --mode CONTROL --start-date 20260901 --end-date 20260929 --port-code 020

  # 전체 대상 항구의 관제정보 수집
  python main.py --mode CONTROL --start-date 20260901 --end-date 20260929

주의:
  - 날짜 형식은 YYYYMMDD입니다.
  - 항구 코드는 앞자리 0을 유지해야 하므로 문자열로 처리합니다.
  - CONTROL 모드에서는 --date-type 값이 사용되지 않습니다.
""",
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument(
        "--mode",
        choices=["ALL", "SHIP_CALL", "CONTROL"],
        default="ALL",
        help="""
            실행할 파이프라인 모드
            ALL        : 입출항 + 관제정보
            SHIP_CALL  : 입출항 정보만
            CONTROL    : 관제정보만
            기본값: ALL
        """
    )
    parser.add_argument(
        "--start-date",
        required=False,
        help="조회 시작일 (YYYYMMDD)"
    )

    parser.add_argument(
        "--end-date",
        required=False,
        help="조회 종료일 (YYYYMMDD)"
    )

    parser.add_argument(
        "--run-id",
        type=int,
        required=False,
        help="기존 pipeline 실행 재개용 run_id"
    )
    parser.add_argument(
        "--date-type",
        choices=["I", "O"],
        default="I",
        help="""
                입출항 조회 기준
                I : 입항
                O : 출항
                기본값: I
                ※ CONTROL 모드에서는 사용하지 않음
                """
            )

    parser.add_argument(
        "--num-of-rows",
        type=int,
        default=50,
        help="API 페이지당 조회 건수 (기본값: 50)"
    )

    parser.add_argument(
        "--port-code",
        type=str,
        default=None,
        help="""
            MOF 항구 코드
            예: 부산 020 / 인천 030
            미지정 시 전체 수집 대상 항구 실행
            """
    )

    parser.add_argument(
        "--trigger-source",
        type=str,
        default="AIRFLOW",
        help="""
            MANUAL_CLI: 터미널에서 직접 실행
            DASHBOARD: Java API로 실행
            AIRFLOW: 스케줄 실행
            """
    )


    return parser.parse_args()


def main():
    args = parse_args()

    try:
        report = run_pipeline(
            mode=args.mode,
            start_date=args.start_date,
            end_date=args.end_date,
            date_type=args.date_type,
            num_of_rows=args.num_of_rows,
            port_code=args.port_code,
            run_id=args.run_id,
            trigger= args.trigger_source
        )
        save_pipeline_report(report)

        

        logger.info(
            "Pipeline 종료 - run_key=%s, status=%s",
            report["run_key"],
            report["status"]
        )
        

    except KeyboardInterrupt:
        logger.warning("프로그램 실행이 사용자에 의해 중단되었습니다.")


if __name__ == "__main__":
    main()