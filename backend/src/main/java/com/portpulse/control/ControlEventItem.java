package com.portpulse.control;

import java.time.LocalDateTime;

public record ControlEventItem(
        Integer eventSeq,
        String eventCode,
        String eventName,
        LocalDateTime eventDt,
        String facilityName,
        Long minutesToNext,
        Boolean isLastEvent
) {
}
