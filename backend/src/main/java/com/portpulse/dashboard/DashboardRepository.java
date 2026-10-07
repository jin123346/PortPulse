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



}
