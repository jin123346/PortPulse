package com.portpulse.monitoring;

import java.math.BigDecimal;
import java.time.LocalDate;

public record MonitoringSummary(
        Long shipCalls,
        Long duplicateRows,
        Long unmatchedExpected,
        BigDecimal matchPct,
        Long rawEvents,
        Long factEvents,
        LocalDate firstDate,
        LocalDate lastDate,
        Long martDays,
        Long martArrivals,
        Long factArrivals,
        Long anomalies14d,
        Long missingDays
) {
}
