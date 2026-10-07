package com.portpulse.dashboard;


import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;


//recode DTO(응답형태)
public record DailyKpiResponse(
        String portCode,
        LocalDate kpiDate,
        String portName,
        String regionKey,
        Integer arrivals,
        Integer departures,
        Integer arrivalsWithTonnage,
        BigDecimal sumGrossTonnage,
        BigDecimal avgGrossTonnage,
        BigDecimal arrivalsAvg7d,
        BigDecimal arrivalsChgPct7d,
        BigDecimal departuresAvg7d,
        BigDecimal departuresChgPct7d,
        BigDecimal avgGrossTonnage7d,
        BigDecimal avgGrossTonnageChgPct7d,
        Integer historyDays,
        BigDecimal arrivalsZscore,
        BigDecimal departuresZscore,
        Boolean isCompleteDay,
        Boolean isAnomaly,
        String anomalyReason,
        LocalDateTime refreshedAt,
        Integer dayOfWeek,
        Boolean isWeekend,
        Boolean isHoliday,
        String holidayName,
        LocalDate lyDate,
        String lyHolidayName,
        Integer arrivalsLy,
        Integer departuresLy,
        BigDecimal arrivalsYoyPct,
        BigDecimal departuresYoyPct
) { }
