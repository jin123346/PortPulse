package com.portpulse.pipeline;

import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/pipeline")
@RequiredArgsConstructor
public class PipelineController {
    private final PipelineLauncher pipelineLauncher;
    private final PipelineRunRepository pipelineRunRepository;

    @PostMapping("/runs")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String,String> run (@RequestBody PipelineRunRequest request){
        pipelineLauncher.launch(request);
        return Map.of("Message","파이프라인 실행을 시작했습니다. 상태는 GET /api/pipeline/runs 에서 확인하세요");

    }

//    @GetMapping("/runs")
//    public List<PipelineRunResponse> recentRuns(@RequestParam(name="limit",defaultValue = "10") int limit){
//        return pipelineRunRepository.findRecent(limit);
//    }

    @GetMapping("/runs")
    public List<PipelineRunResponse> recentRuns(@RequestParam(name="startDate", required = false) LocalDate startDate,
                                                @RequestParam(name="endDate", required = false) LocalDate endDate,
                                                @RequestParam(name="limit",defaultValue = "10") int limit
                                                ){
        if (startDate != null){
            return pipelineRunRepository.findByTargetDate(startDate,endDate,limit);
        }
        return pipelineRunRepository.findRecent(limit);
    }


}
