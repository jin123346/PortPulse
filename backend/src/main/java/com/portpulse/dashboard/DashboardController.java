package com.portpulse.dashboard;

import jakarta.websocket.server.PathParam;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/kpi")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;

    @GetMapping("/daily")
    public List<DailyKpiResponse> getDailyKpi(
            @RequestParam(name="date", required = false)
            @DateTimeFormat(iso=DateTimeFormat.ISO.DATE)
            LocalDate date
    ){
        return dashboardService.getDailyKpi(date);
    }
    @GetMapping("/{portCode}/daily")
    public PortDailyDetailResponse getPortDailyDetail(
            @PathVariable("portCode") String portCode,
            @RequestParam(name="date",required = false)
            @DateTimeFormat(iso=DateTimeFormat.ISO.DATE)
            LocalDate date
    ){
        return dashboardService.getPortDailyDetail(portCode,date);
    }


}
