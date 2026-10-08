## ⏱ 운영 자동화 (Airflow)

Spring `@Scheduled`로 일일 수집을 먼저 구현한 뒤, 재시도·실행 이력·과거 구간 재처리를 위해 **Apache Airflow 3 (Docker Compose)** 로 이전했습니다.
Airflow는 기존 `pipeline/main.py`를 그대로 실행하고, 결과는 `audit.pipeline_run`에 `trigger_source = AIRFLOW`로 기록되어
대시보드의 실행 이력·중복 실행 방지 로직을 그대로 사용합니다.

```
[Airflow (Docker)] ──00:30 / 06:30 / 12:30 / 18:30 KST──▶ python main.py --trigger-source AIRFLOW
                                                              │
                                                              ▼
                                         PostgreSQL (host:5433) ◀── Spring Boot API / Dashboard
```

### 스케줄 설계

| 실행 시각 (KST) | 수집 범위 | 목적 |
| --- | --- | --- |
| 00:30 | 어제 ~ 오늘 | 전날 마감분 정리 |
| 06:30 | 어제 ~ 오늘 | 밤사이 들어온 전날 확정 신고 반영 |
| 12:30 | 오늘 | 당일 갱신 |
| 18:30 | 오늘 | 당일 갱신 |

확정 신고가 늦게 들어오는 특성 때문에 새벽·아침 실행만 전날을 다시 수집하고, 낮 실행은 당일만 받아 API 호출을 줄였습니다.

```python
"{% set base = (logical_date or dag_run.run_after).in_timezone('Asia/Seoul') %}"
"{% set start = base.subtract(days=1) if base.hour < 7 else base %}"
"python main.py --mode ALL --start-date {{ start.strftime('%Y%m%d') }} --end-date {{ base.strftime('%Y%m%d') }} --trigger-source AIRFLOW"
```

- `max_active_runs=1` — 동시 실행 방지
- `retries=2` — 실패 시 자동 재시도
- `catchup=False` — DAG 활성화 시 과거 구간 일괄 실행 방지 (필요 시 Backfill로 재처리)

### 이전하며 해결한 문제

- **UTC 기준 날짜**: Airflow의 `ds`는 UTC라 한국 06:30 실행이 전날로 계산되는 문제를 확인하고, 실행 시각을 KST로 변환해 수집 범위를 계산
- **컨테이너 → 호스트 DB 접속**: 컨테이너 안의 `localhost`는 자기 자신이므로 `host.docker.internal`로 접속.
  `load_dotenv()`가 기존 환경변수를 덮어쓰지 않는 점을 이용해, 코드 수정 없이 로컬(`pipeline/.env`)과 Airflow(`airflow/.env`)의 접속 정보를 분리
- **Windows 가상환경 분리**: `.venv`는 Windows 전용이라 컨테이너에서는 `_PIP_ADDITIONAL_REQUIREMENTS`로 의존성을 설치
- **손상된 소스 파일 발견**: 컨테이너에서 처음 실행하자 일부 `.py`가 바이트코드·로그로 덮여 있던 것이 드러남.
  로컬은 파일 크기·수정 시각이 같아 `__pycache__`를 계속 사용해 몰랐던 상황으로, `compileall -f`로 전체를 강제 검사해 손상 파일을 찾고 git에서 복구
- **포트 정리**: 로컬 Oracle(8080)과 Spring(8081)을 피해 Airflow UI는 8090으로 노출

### 실행

```bash
cd airflow
docker compose up airflow-init
docker compose up -d
# http://localhost:8090  (DAG: port_pulse_daily)
```

> `airflow/.env`에 `DB_HOST=host.docker.internal`, `DB_PORT=5433` 등 접속 정보를 설정합니다. (`.env`는 커밋하지 않음)