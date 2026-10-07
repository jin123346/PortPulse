package com.portpulse.pipeline;

import com.portpulse.common.DateType;
import com.portpulse.common.Mode;

import java.time.LocalDate;

public record PipelineRunRequest(
        Mode mode,
        LocalDate startDate,
        LocalDate endDate,
        String portCode,
        DateType dateType,
        Integer runId
) {

    public PipelineRunRequest{
        if (mode == null) mode = Mode.ALL;

        if(runId ==null){
            if (startDate == null || endDate==null){
                throw new IllegalArgumentException("신규실행은 startDate, endDate가 필수 입니다.");
            }
            if(startDate.isAfter(endDate)) {
                throw new IllegalStateException("startDate가 endDate보다 늦습니다.");
            }
        }
        if(portCode != null && !portCode.matches("\\d{3}")){
            throw new IllegalArgumentException("portCode는 3자리 숫자입니다. 예: 020");
        }
    }
}
