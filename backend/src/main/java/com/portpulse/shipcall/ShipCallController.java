package com.portpulse.shipcall;

import com.portpulse.control.ControlEventItem;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class ShipCallController {

    private final ShipCallRepository shipCallRepository;

    // GET /api/ships/D7000/calls?limit=20
    @GetMapping("/ships/{clsgn}/calls")
    public List<ShipCallItem> calls(@PathVariable("clsgn") String clsgn,
                                    @RequestParam(name = "limit", defaultValue = "20") int limit) {
        if (limit < 1 || limit > 100) {
            throw new IllegalArgumentException("limit은 1~100 사이여야 합니다.");
        }
        return shipCallRepository.findByClsgn(clsgn, limit);
    }

    // GET /api/ship-calls/123/events
    @GetMapping("/ship-calls/{shipCallId}/events")
    public List<ControlEventItem> events(@PathVariable("shipCallId") Long shipCallId) {
        return shipCallRepository.findEvents(shipCallId);
    }
}