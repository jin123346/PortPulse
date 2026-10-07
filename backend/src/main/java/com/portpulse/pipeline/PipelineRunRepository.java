package com.portpulse.pipeline;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class PipelineRunRepository {

    private final JdbcClient jdbcClient;

    private static final String FIND_RECENT_SQL= """
                select run_id , pipeline_name, run_key, status,
                start_date, end_date, started_at,finished_at,
                error_message, trigger_source
                FROM audit.pipeline_run
                order by run_id desc
                limit :limit
            """;

    private static final String FIND_BY_TARGET_DATE_SQL= """
                select run_id , pipeline_name, run_key, status,
                start_date, end_date, started_at,finished_at,
                error_message, trigger_source
                FROM audit.pipeline_run
                where start_date <= :endDate
                and end_date   >= :startDate
                order by run_id desc
                limit :limit
            """;

    private static final String EXISTS_RUNNING_SQL= """
                select exists(
                    select 1
                    from audit.pipeline_run
                    where status='RUNNING'
                    and started_at > CURRENT_TIMESTAMP - INTERVAL '6 hours'
                )
            """;


    public List<PipelineRunResponse> findRecent(int limit){
        return jdbcClient.sql(FIND_RECENT_SQL)
                .param("limit",limit)
                .query(PipelineRunResponse.class)
                .list();
    }

    public boolean existsRunning(){
        return jdbcClient.sql(EXISTS_RUNNING_SQL)
                .query(Boolean.class)
                .single();
    }

    public List<PipelineRunResponse> findByTargetDate(LocalDate startDate , LocalDate endDate, int limit){
        LocalDate lastDate = (endDate == null) ? startDate : endDate;
        return jdbcClient.sql(FIND_BY_TARGET_DATE_SQL)
                .param("limit",limit)
                .param("startDate",startDate)
                .param("endDate",lastDate)
                .query(PipelineRunResponse.class)
                .list();
    }


}

