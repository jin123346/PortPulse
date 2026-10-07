package com.portpulse.pipeline;


import com.portpulse.common.DateType;
import com.portpulse.common.Mode;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.ZoneId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Component
public class PipelineScheduler {
    private static final Logger log = LoggerFactory.getLogger(PipelineScheduler.class);
    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    private final PipelineLauncher launcher;

    public PipelineScheduler(PipelineLauncher launcher) {
        this.launcher = launcher;
    }

    @Scheduled(cron = "${portpulse.pipeline.schedule-cron}", zone = "Asia/Seoul")
    public void runDaily() {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Seoul"));
        LocalDate yesterday = today.minusDays(1);
        PipelineRunRequest request = new PipelineRunRequest(Mode.ALL,yesterday, today,null, DateType.I,null,"AIRFLOW");// D-3 ~ D-1 다시 수집

        try {
            launcher.launch(request);
            log.info("스케줄 실행 시작: {} ~ {}", yesterday, today);
        } catch (PipelineLaunchException e) {
            log.warn("스케줄 실행 건너뜀: {}", e.getMessage());   // 이미 실행 중이면 여기로
        }
    }
}
