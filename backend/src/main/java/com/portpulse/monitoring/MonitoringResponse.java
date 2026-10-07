package com.portpulse.monitoring;

import java.util.List;

public record MonitoringResponse(
        String status,                  // OK / WARN
        MonitoringSummary summary,
        List<String> warnings
) {
}
