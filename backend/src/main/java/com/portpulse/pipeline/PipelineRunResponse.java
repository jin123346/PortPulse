package com.portpulse.pipeline;


import java.time.LocalDateTime;
import java.time.LocalTime;

public record PipelineRunResponse(
        Long runId,
        String pipelineName,
        String runKey,
        String Status,
        LocalTime startDate,
        LocalTime endDate,
        LocalDateTime startedAt,
        LocalDateTime finishedAt,
        String errorMessage,
        String triggerSource
) {
}
