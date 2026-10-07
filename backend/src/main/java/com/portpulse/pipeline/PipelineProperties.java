package com.portpulse.pipeline;


import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "portpulse.pipeline")
public record PipelineProperties(
        String pythonPath,
        String workingDir
) {
    public PipelineProperties {
        if (pythonPath == null || pythonPath.isBlank()) {
            throw new IllegalStateException("portpulse.pipeline.python-path 설정이 없습니다.");
        }
        if (workingDir == null || workingDir.isBlank()) {
            throw new IllegalStateException("portpulse.pipeline.working-dir 설정이 없습니다.");
        }
    }
}
