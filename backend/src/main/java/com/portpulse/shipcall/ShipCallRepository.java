package com.portpulse.shipcall;


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
                ship_call_id, ship_call_raw_id, port_code, port_name,
                etrypt_year, etrypt_co, clsgn, vessel_name,vessel_kind_cd,
                gross_tonnage, ibobprt_nm,arrival_dt, arrival_source, departure_dt,
                departure_source, stay_minutes, last_control_event, last_control_event_dt,
                last_facility_code, last_facility_sub_code, last_facility_name,
                control_match_priority, suspected_duplicate, duplicate_of_ship_call_raw_id,
                updated_at
                from fact.fact_ship_call fsc
            """;

    private static final String FIND_ARRIVALS_SQL=  SELECT_COLUMNS + """
            WHERE port_code=:portCode
                AND arrival_dt >= :startDate
                AND arrival_dt < :endDate
                AND duplicate_of_ship_call_raw_id IS NULL
            ORDER BY arrival_dt
            """;

    private static final String FIND_DEPARTURES_SQL=  SELECT_COLUMNS + """
            WHERE port_code=:portCode
                AND departure_dt >= :startDate
                AND departure_dt < :endDate
                AND duplicate_of_ship_call_raw_id IS NULL
            ORDER BY departure_dt
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
                .param("starDate",startDate.atStartOfDay())
                .param("endDate",startDate.plusDays(1).atStartOfDay())  //종료일 다음날 00시까지
                .query(ShipCallItem.class)
                .list();

    }
}
