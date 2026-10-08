package com.portpulse.dashboard;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import javax.swing.text.html.Option;
import java.time.LocalDate;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

@Repository
public class DashboardRepository {

    private final JdbcClient jdbcClient;

    //생성자 주입
    public DashboardRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
    }
    private static final String KPI_SELECT = """
        
            SELECT port_code,
               kpi_date,
               port_name,
               region_key,
               arrivals,
               departures,
               arrivals_with_tonnage,
               sum_gross_tonnage,
               avg_gross_tonnage,
               arrivals_avg_7d              AS arrivals_avg7d,
               arrivals_chg_pct_7d          AS arrivals_chg_pct7d,
               departures_avg_7d            AS departures_avg7d,
               departures_chg_pct_7d        AS departures_chg_pct7d,
               avg_gross_tonnage_7d         AS avg_gross_tonnage7d,
               avg_gross_tonnage_chg_pct_7d AS avg_gross_tonnage_chg_pct7d,
               history_days,
               arrivals_zscore,
               departures_zscore,
               is_complete_day,
               is_anomaly,
               anomaly_reason,
               refreshed_at,
               day_of_week,
               is_weekend,
               is_holiday,
               holiday_name,
               ly_date,
               ly_holiday_name,
               arrivals_ly,
               departures_ly,
               arrivals_yoy_pct,
               departures_yoy_pct
          FROM mart.port_daily_kpi
        """;
    private static final String FIND_DAILY_KPI_SQL=KPI_SELECT+ """
                where kpi_date = :kpiDate
                ORDER BY arrivals desc, port_code
            """;
    private static final String FIND_PORT_DAILY_KPI_SQL =KPI_SELECT+ """
                where port_code = :portCode AND kpi_date = :kpiDate
            """;
    private static final String FIND_LATEST_COMPLETE_DATE_SQL= """
                select max(kpi_date) from mart.port_daily_kpi pdk
            """;

    private static final String FIND_HOURLY_KPI_SQL= """
            WITH calls AS (
                SELECT fsc.ship_call_id,
                       fsc.arrival_dt,
                       COALESCE(fsc.departure_dt, nx.arrival_dt) AS leave_dt   -- 출항, 없으면 다음 입항
                FROM fact.fact_ship_call fsc
                LEFT JOIN LATERAL (
                    SELECT n.arrival_dt
                    FROM fact.fact_ship_call n
                    WHERE n.clsgn = fsc.clsgn
                      AND n.arrival_dt > fsc.arrival_dt
                    ORDER BY n.arrival_dt
                    LIMIT 1
                ) nx ON true
                WHERE fsc.port_code = :portCode
                  AND fsc.arrival_dt <  CAST(:day AS timestamp) + interval '1 day'
                  AND fsc.arrival_dt >= CAST(:day AS timestamp) - interval '30 day'
                  -- AND 대표 신고만 (중복 제외 조건)
            )
            SELECT h.hour_ts,
                   count(c.ship_call_id) FILTER (WHERE c.leave_dt IS NOT NULL) AS ships,
                   count(c.ship_call_id) FILTER (WHERE c.leave_dt IS NULL)     AS unknown_departure
            FROM generate_series(CAST(:day AS timestamp),
                                 CAST(:day AS timestamp) + interval '23 hour',
                                 interval '1 hour') AS h(hour_ts)
            LEFT JOIN calls c
                   ON c.arrival_dt <= h.hour_ts
                  AND (c.leave_dt IS NULL OR c.leave_dt > h.hour_ts)
            GROUP BY h.hour_ts
            ORDER BY h.hour_ts;
            """;
    public List<DailyKpiResponse> findDailyKpiByDate(LocalDate kpiDate){
        return jdbcClient.sql(FIND_DAILY_KPI_SQL)
                .param("kpiDate",kpiDate)
                .query(DailyKpiResponse.class)
                .list();
    }

    public Optional<LocalDate> findLatestCompleteDate(){
        return Optional.of(
                jdbcClient.sql(FIND_LATEST_COMPLETE_DATE_SQL)
                        .query(LocalDate.class)
                        .single()
        );
    }

    public Optional<DailyKpiResponse> findDailyKpiByPortAndDate(String portCode, LocalDate date){
        return jdbcClient.sql(FIND_PORT_DAILY_KPI_SQL)
                .param("portCode",portCode)
                .param("kpiDate",date)
                .query(DailyKpiResponse.class)
                .optional();

    }

    public List<HourlyOccupancyResponse> findHourlyKpiByPortAndDate(String portCode, LocalDate date){
        return jdbcClient.sql(FIND_HOURLY_KPI_SQL)
                .param("portCode",portCode)
                .param("day",date)
                .query(HourlyOccupancyResponse.class)
                .list();

    }




}
