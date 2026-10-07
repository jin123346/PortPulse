package com.portpulse.dashboard;

import com.portpulse.shipcall.ShipCallItem;
import com.portpulse.shipcall.ShipCallRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly= true)
public class DashboardService {

    private final DashboardRepository dashboardRepository;
    private final ShipCallRepository shipCallRepository;

    public List<DailyKpiResponse> getDailyKpi(LocalDate kpiDate){
        LocalDate targetDate = resolveDate(kpiDate);

        return dashboardRepository.findDailyKpiByDate(targetDate);
    }

    public PortDailyDetailResponse getPortDailyDetail(String portCode, LocalDate kpiDate){
        LocalDate targetDate = resolveDate(kpiDate);
        DailyKpiResponse kpi = dashboardRepository.findDailyKpiByPortAndDate(portCode,kpiDate)
                .orElseThrow(()-> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,"해당 항만의 KPI가 없습니다 : "+portCode+", "+targetDate
                ));
        List<ShipCallItem> arrivals = shipCallRepository.findArrivals(portCode,kpiDate);
        List<ShipCallItem> departures = shipCallRepository.findDepartures(portCode,kpiDate);

        return new PortDailyDetailResponse(kpi,arrivals,departures);
    }


    public LocalDate resolveDate(LocalDate date){
        if (date != null){
            return date;
        }
        return dashboardRepository.findLatestCompleteDate().orElseThrow(()-> new IllegalStateException("조회할 KPI 데이터가 없습니다."));
    }
}
