package com.portpulse.dashboard;

import com.portpulse.shipcall.ShipCallItem;

import java.util.List;

public record PortDailyDetailResponse(
        DailyKpiResponse kpi,
        List<ShipCallItem> arrivalShips,
        List<ShipCallItem> departureShips
) {
}
