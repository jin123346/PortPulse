package com.portpulse.monitoring;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/monitoring")
@RequiredArgsConstructor
public class MonitoringController {
    private final MonitoringService monitoringService;

    // GET /api/monitoring/summary
    @GetMapping("/summary")
    public MonitoringResponse summary() {
        return monitoringService.getSummary();
    }
}
