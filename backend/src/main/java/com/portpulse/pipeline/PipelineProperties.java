package com.portpulse.pipeline;


import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "portpulse.pipeline")
public record PipelineProperties(
        String pythonPath,
        String workingDir
) {
}
