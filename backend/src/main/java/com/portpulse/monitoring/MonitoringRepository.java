package com.portpulse.monitoring;

import com.portpulse.pipeline.PipelineProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

@Repository
@RequiredArgsConstructor
public class MonitoringRepository {

    private final JdbcClient jdbcClient;
    private final PipelineProperties pipelineProperties;

    public MonitoringSummary findSummary() {
        String sql = loadSql("monitoring_summary.sql")
                .strip()
                .replaceAll(";\\s*$", "");      // 끝의 세미콜론 제거 (서브쿼리 안에 ; 가 있으면 문법 에러)

        String wrapped = """
            SELECT s.ship_calls,
                  s.duplicate_rows,
                  s.unmatched_expected,
                  s.match_pct,
                  s.raw_events,
                  s.fact_events,
                  s.first_date,
                  s.last_date,
                  s.mart_days,
                  s.mart_arrivals,
                  s.fact_arrivals,
                  s.anomalies_14d AS anomalies14d,
                  s.missing_days
              FROM (
            %s
              ) s
            """.formatted(sql);

        return jdbcClient.sql(wrapped)
                .query(MonitoringSummary.class)
                .single();
    }
    // Python 파이프라인과 같은 SQL 파일을 읽어서 사용
    private String loadSql(String fileName) {
        Path path = Path.of(pipelineProperties.workingDir(), "sql", fileName).toAbsolutePath();
        try {
            return Files.readString(path, StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException("SQL 파일을 읽을 수 없습니다: " + path, e);
        }
    }
}