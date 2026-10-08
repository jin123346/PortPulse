import pendulum
from airflow.sdk import dag
from airflow.providers.standard.operators.bash import BashOperator


KST = pendulum.timezone("Asia/Seoul")
BASE = "(logical_date or dag_run.run_after).in_timezone('Asia/Seoul')"

# 스케쥴 예시
# 00:30	어제 ~ 오늘 (10/08~10/09)	전날 마감분 정리
# 06:30	어제 ~ 오늘 (10/07~10/08)	밤사이 들어온 전날 확정 신고 반영
# 12:30	오늘 ~ 오늘 (10/08~10/08)	당일 갱신
# 18:30	오늘 ~ 오늘 (10/08~10/08)	당일 갱신

@dag(
    dag_id = "port_pulse_daily",
    schedule="30 0,6,12,18 * * *",          # 00:30, 06:30, 12:30, 18:30 (KST)
    start_date=pendulum.datetime(2026,10,1,tz=KST),
    catchup=False,   # 켜는 순간 과거 날짜를 몰아서 돌리지 않게
    max_active_runs=1,
    default_args={"retries":2,"retry_delay":pendulum.duration(minutes=20)},
    tags=["port_pulse"],
)
def port_pulse_daily():
    BashOperator(
       task_id="run_pipeline",
       cwd="/opt/airflow/pipeline",
       env={"TZ": "Asia/Seoul"},
       append_env=True,
       bash_command=(
                   "{% set base = (logical_date or dag_run.run_after).in_timezone('Asia/Seoul') %}"
                   "{% set start = base.subtract(days=1) if base.hour < 7 else base %}"
                   "python main.py"
                   " --mode ALL"
                   " --date-type I"
                   " --start-date {{ start.strftime('%Y%m%d') }}"
                   " --end-date {{ base.strftime('%Y%m%d') }}"
                   " --trigger-source AIRFLOW"
       )
    )


port_pulse_daily()

