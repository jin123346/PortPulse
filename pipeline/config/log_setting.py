import logging
from datetime import datetime

from config.setting import LOG_DIR


def setup_logging():
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    # 날짜별 로그 파일 1개
    log_file = LOG_DIR / f"portpulse_{datetime.now():%Y%m%d}.log"

    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(
                log_file,
                mode="a",          # 기존 파일에 이어쓰기
                encoding="utf-8"
            )
        ],
        force=True
    )

    logging.getLogger(__name__).info(
        "로그 파일 사용: %s",
        log_file
    )


# import logging
# from pathlib import Path
# from datetime import datetime
# from config.setting import LOG_DIR

# def setup_logging():
#     LOG_DIR.mkdir(parents=True, exist_ok=True)

#     log_file = LOG_DIR / f"portpulse_{datetime.now():%Y%m%d_%H%M%S}.log"

#     logging.basicConfig(
#         level=logging.DEBUG,
#         format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
#         handlers=[
#             logging.StreamHandler(),
#             logging.FileHandler(
#                 log_file,
#                 encoding="utf-8"
#             )
#         ],
#         force=True
#     )

#     logging.getLogger(__name__).info(
#         "로그 파일 생성: %s",
#         log_file
#     )