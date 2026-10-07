package com.portpulse.pipeline;


import com.portpulse.common.Mode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.RestController;

import java.io.File;
import java.nio.file.Path;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
@Component
@RequiredArgsConstructor
public class PipelineLauncher {

    private static final DateTimeFormatter YYYYMMDD= DateTimeFormatter.BASIC_ISO_DATE;
    private final PipelineProperties properties;
    private final PipelineRunRepository pipelineRunRepository;
    private final AtomicBoolean launching = new AtomicBoolean(false);

    public void launch(PipelineRunRequest request){
        if(!launching.compareAndSet(false,true)){
            throw new IllegalStateException("파이프라인이 이미 실행 중입니다.");
        }
        try{
            if(pipelineRunRepository.existsRunning()){
                launching.set(false);
                throw new IllegalStateException("다른 파이프라인이 실행 중입니다.");
            }
            startProcess(buildCommand(request));
        }catch (RuntimeException e){
            launching.set(false);
            throw e;
        }
    }

    private List<String> buildCommand(PipelineRunRequest request){
        String python = Path.of(properties.pythonPath()).toAbsolutePath().toString();

        List<String> command = new ArrayList<>(List.of(
                python,"main.py",
                "--mode",request.mode().name()
        ));

        if(request.runId() != null){
            command.add("--run-id");
            command.add(String.valueOf(request.runId()));
        }else{
            command.add("--start-date");
            command.add(request.startDate().format(YYYYMMDD));
            command.add("--end-date");
            command.add(request.endDate().format(YYYYMMDD));
        }

        if(request.portCode() !=null){
            command.add("--port-code");
            command.add(request.portCode());
        }

        if(request.dateType() !=null && request.mode() != Mode.CONTROL){
            command.add("--date-type");
            command.add(request.dateType().name());
        }
        return command;
    }

    private void startProcess(List<String> command){
        File workDir = Path.of(properties.workingDir()).toAbsolutePath().toFile();

        ProcessBuilder builder= new ProcessBuilder(command)
                .directory(workDir)
                .redirectErrorStream(true)
                .redirectOutput(ProcessBuilder.Redirect.DISCARD);
        builder.environment().put("PYTHONIOENCODING","utf-8");

        try{
            Process process = builder.start();
            log.info("파이프라인 시작 - pid={} , workDir={}, command={}", process.pid(), workDir, command);
            process.onExit().thenAccept(p->{
                log.info("파이프라인 종료 - pid={} , exitCode={}", p.pid(), p.exitValue());
            });

        }catch (Exception e){
            throw new IllegalStateException("파이프라인 실행 실패: "+e.getMessage(),e);
        }
    }

}
