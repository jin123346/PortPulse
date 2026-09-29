import psycopg2

from config.setting import DB_CONFIG


def get_connection():
    """
    PostgreSQL DB Connection 생성
    """
    return psycopg2.connect(**DB_CONFIG)


def test_connection():
    """
    PostgreSQL 연결 테스트
    """
    conn = None

    try:
        conn = get_connection()

        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    current_database(),
                    version();
                """
            )

            db_name, version = cursor.fetchone()

            print(f"DB 연결 성공: {db_name}")
            print(f"PostgreSQL Version: {version}")

    except Exception as e:
        print(f"DB 연결 실패: {e}")
        raise

    finally:
        if conn is not None:
            conn.close()
            
            
def get_target_ports():
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT prt_ag_cd
                FROM master.dim_mof_port_code
                ORDER BY prt_ag_cd
                """
            )

            rows = cursor.fetchall()

            return [row[0] for row in rows]

    finally:
        conn.close()