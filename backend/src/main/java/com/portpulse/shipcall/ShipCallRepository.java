package com.portpulse.shipcall;


import com.portpulse.control.ControlEventItem;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

@Repository
@RequiredArgsConstructor
public class ShipCallRepository {

    private final JdbcClient jdbcClient;

    private static final String SELECT_COLUMNS= """
                select
                    fsc.ship_call_id, fsc.ship_call_raw_id, fsc.port_code, fsc.port_name,
                    fsc.etrypt_year, fsc.etrypt_co, fsc.clsgn, fsc.vessel_name, fsc.vessel_kind_cd,
                    COALESCE(vk.vssl_knd_nm, fsc.vessel_kind_cd) AS vessel_kind_name,
                    fsc.gross_tonnage, fsc.ibobprt_nm, fsc.arrival_dt, fsc.arrival_source, fsc.departure_dt,
                    fsc.departure_source,
                    nx.arrival_dt AS next_arrival_dt,
                    nx.port_name  AS next_port_name,
                    fsc.stay_minutes, fsc.last_control_event, fsc.last_control_event_dt,
                    fsc.last_facility_code, fsc.last_facility_sub_code, fsc.last_facility_name,
                    fsc.control_match_priority, fsc.suspected_duplicate, fsc.duplicate_of_ship_call_raw_id,
                    fsc.updated_at
                from fact.fact_ship_call fsc
                LEFT JOIN master.dim_mof_vessel_kind vk ON vk.vssl_knd_cd = fsc.vessel_kind_cd
                LEFT JOIN LATERAL (
                    SELECT n.arrival_dt, n.port_name
                      FROM fact.fact_ship_call n
                     WHERE n.clsgn = fsc.clsgn
                       AND n.arrival_dt > fsc.arrival_dt
                       AND n.duplicate_of_ship_call_raw_id IS NULL
                     ORDER BY n.arrival_dt
                     LIMIT 1
                ) nx ON true
            """;

    private static final String FIND_ARRIVALS_SQL=  SELECT_COLUMNS + """
            WHERE fsc.port_code = :portCode
              AND fsc.arrival_dt >= :startDate
              AND fsc.arrival_dt <  :endDate
              AND fsc.duplicate_of_ship_call_raw_id IS NULL
            ORDER BY fsc.arrival_dt
            """;

    private static final String FIND_DEPARTURES_SQL=  SELECT_COLUMNS + """
            WHERE fsc.port_code = :portCode
              AND fsc.departure_dt >= :startDate
              AND fsc.departure_dt <  :endDate
              AND fsc.duplicate_of_ship_call_raw_id IS NULL
            ORDER BY fsc.departure_dt
            """;

    public List<ShipCallItem>  findArrivals(String portCode, LocalDate date){
        return findByDateRange(FIND_ARRIVALS_SQL,portCode,date,date);
    }
    public List<ShipCallItem>  findArrivals(String portCode, LocalDate startDate,LocalDate endDate){
        return findByDateRange(FIND_ARRIVALS_SQL,portCode,startDate,endDate);
    }

    public List<ShipCallItem> findDepartures(String portCode,LocalDate date){
        return findByDateRange(FIND_DEPARTURES_SQL,portCode,date,date);
    }
    public List<ShipCallItem> findDepartures(String portCode,LocalDate startDate,LocalDate endDate){
        return findByDateRange(FIND_DEPARTURES_SQL,portCode,startDate,endDate);
    }


    private List<ShipCallItem> findByDateRange(String sql, String portCode, LocalDate startDate, LocalDate endDate){

        LocalDate lastDate = (endDate == null) ? startDate : endDate;

        if(lastDate.isBefore(startDate)){
            throw new IllegalStateException("endDate는 startDate보다 빠를 수 없습니다.");
        }

        return jdbcClient.sql(sql)
                .param("portCode",portCode)
                .param("startDate",startDate.atStartOfDay())
                .param("endDate",lastDate.plusDays(1).atStartOfDay())  //종료일 다음날 00시까지
                .query(ShipCallItem.class)
                .list();

    }

    private static final String FIND_BY_CLSGN_SQL = SELECT_COLUMNS + """
                   WHERE fsc.clsgn = :clsgn
                     AND fsc.duplicate_of_ship_call_raw_id IS NULL
                               ORDER BY fsc.arrival_dt DESC NULLS LAST
                   LIMIT :limit
        """;

    private static final String FIND_EVENTS_SQL = """
        SELECT e.event_seq, e.event_code, e.event_name, e.event_dt,
               e.facility_name, e.minutes_to_next, e.is_last_event
          FROM fact.fact_ship_call s
          JOIN fact.fact_control_event e
            ON e.control_call_raw_id = s.control_call_raw_id
         WHERE s.ship_call_id = :shipCallId
         ORDER BY e.event_seq
        """;

    public List<ShipCallItem> findByClsgn(String clsgn, int limit) {
        return jdbcClient.sql(FIND_BY_CLSGN_SQL)
                .param("clsgn", clsgn)
                .param("limit", limit)
                .query(ShipCallItem.class)
                .list();
    }

    public List<ControlEventItem> findEvents(Long shipCallId) {
        return jdbcClient.sql(FIND_EVENTS_SQL)
                .param("shipCallId", shipCallId)
                .query(ControlEventItem.class)
                .list();
    }
}
