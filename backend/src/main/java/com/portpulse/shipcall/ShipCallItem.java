package com.portpulse.shipcall;


import java.math.BigDecimal;
import java.time.LocalDateTime;

public record ShipCallItem(
        Long shipCallId,
        Long shipCallRawId,
        String portCode,
        String portName,
        String etryptYear,
        String etryptCo,
        String clsgn,
        String vesselName,
        String vesselKindCd,
        String vesselKindName,
        BigDecimal grossTonnage,
        String ibobprtNm,  // 이전/다음 항구명
        LocalDateTime arrivalDt,
        String arrivalSource,
        LocalDateTime departureDt,
        String departureSource,
        LocalDateTime nextArrivalDt,
        String nextPortName,
        Long stayMinutes,
        String lastControlEvent,
        String lastControlEventDt,
        String lastFacilityCode,
        String lastFacilitySubCode,
        String lastFacilityName,
        Short controlMatchPriority,
        Boolean suspectedDuplicate,
        Long duplicateOfShipCallRawId,
        LocalDateTime updatedAt


        ) { }
