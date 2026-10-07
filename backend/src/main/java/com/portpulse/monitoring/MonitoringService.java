package com.portpulse.monitoring;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MonitoringService {
    private static final BigDecimal MIN_MATCH_PCT = new BigDecimal("90.0");
    private static final long MAX_MISSING_DAYS = 2;

    private final MonitoringRepository monitoringRepository;

    public MonitoringResponse getSummary() {
        MonitoringSummary s = monitoringRepository.findSummary();
        List<String> warnings = checkWarnings(s);
        String status = warnings.isEmpty() ? "OK" : "WARN";
        return new MonitoringResponse(status, s, warnings);
    }

    private List<String> checkWarnings(MonitoringSummary s) {
        List<String> warnings = new ArrayList<>();

        if (s.matchPct() != null && s.matchPct().compareTo(MIN_MATCH_PCT) < 0) {
            warnings.add("매칭률 " + s.matchPct() + "% (< " + MIN_MATCH_PCT + "%) — 관제 미수집 기간이 있는지 확인");
        }
        if (!Objects.equals(s.rawEvents(), s.factEvents())) {
            warnings.add("관제 이벤트 raw " + s.rawEvents() + " ≠ fact " + s.factEvents());
        }
        if (!Objects.equals(s.martArrivals(), s.factArrivals())) {
            warnings.add("mart 입항 합계 " + s.martArrivals() + " ≠ fact " + s.factArrivals());
        }
        if (s.missingDays() != null && s.missingDays() > MAX_MISSING_DAYS) {
            warnings.add("mart에서 빠진 날 " + s.missingDays() + "일");
        }
        return warnings;
    }
}
