package com.portpulse.pipeline;


import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

public record PipelineRunResponse(
        Long runId,
        String pipelineName,
        String runKey,
        String status,
        LocalDate startDate,
        LocalDate endDate,
        LocalDateTime startedAt,
        LocalDateTime finishedAt,
        String errorMessage,
        String triggerSource
) {
}
