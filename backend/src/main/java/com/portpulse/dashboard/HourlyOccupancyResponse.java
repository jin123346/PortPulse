package com.portpulse.dashboard;

import java.time.LocalDateTime;

public record HourlyOccupancyResponse(
        LocalDateTime hourTs,
        int ships,
        int unknownDeparture
) {
}
