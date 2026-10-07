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
               ... (기존 32개 컬럼 그대로) ...
               departures_yoy_pct
          FROM mart.port_daily_kpi
        """;
    private static final String FIND_DAILY_KPI_SQL=KPI_SELECT+ """
                where kpi_date = :kpiDate
                ORDER BY arrivals desc, port_code
            """;
    private static final String FIND_PORT_DAILY_KPI_SQL = """
                where port_code = :portCode
                AND kpi_date = :kpiDate
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
