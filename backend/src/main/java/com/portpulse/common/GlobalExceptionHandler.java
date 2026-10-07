package com.portpulse.common;

import com.portpulse.pipeline.PipelineLaunchException;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;

import java.time.format.DateTimeParseException;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    // 400: 잘못된 값 (날짜 역전, portCode 형식 등)
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorResponse> handleBadRequest(IllegalArgumentException e, HttpServletRequest request) {
        return build(HttpStatus.BAD_REQUEST, e.getMessage(), request);
    }

    // 400: JSON 본문을 읽지 못함 (형식 오류, 날짜 형식, record 검증 실패)
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleNotReadable(HttpMessageNotReadableException e, HttpServletRequest request) {
        Throwable root = NestedExceptionUtils.getMostSpecificCause(e);

        String message;
        if (root instanceof IllegalArgumentException) {
            message = root.getMessage();                       // record compact 생성자의 검증 메시지
        } else if (root instanceof DateTimeParseException) {
            message = "날짜 형식은 yyyyMMdd 입니다. 예: 20261007";
        } else {
            message = "요청 본문 형식이 올바르지 않습니다.";
        }
        return build(HttpStatus.BAD_REQUEST, message, request);
    }

    // 400: URL 파라미터 타입 오류 (?date=abc)
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorResponse> handleTypeMismatch(MethodArgumentTypeMismatchException e, HttpServletRequest request) {
        String message = String.format("파라미터 '%s' 값이 올바르지 않습니다: %s", e.getName(), e.getValue());
        return build(HttpStatus.BAD_REQUEST, message, request);
    }

    // 404 등: 코드에서 상태를 직접 지정한 경우
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ErrorResponse> handleResponseStatus(ResponseStatusException e, HttpServletRequest request) {
        return build(e.getStatusCode(), e.getReason(), request);
    }

    // 409: 지금 상태에서 할 수 없음 (중복 실행 등)
    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ErrorResponse> handleConflict(IllegalStateException e, HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, e.getMessage(), request);
    }

    // 500: 예상 못 한 에러 → 로그에는 전체, 응답에는 일반 메시지만
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception e, HttpServletRequest request) {
        log.error("처리되지 않은 예외 - path={}", request.getRequestURI(), e);
        return build(HttpStatus.INTERNAL_SERVER_ERROR, "서버 내부 오류가 발생했습니다.", request);
    }
    // 500: 파이프라인 프로세스를 띄우지 못함 (서버 설정 문제)
    @ExceptionHandler(PipelineLaunchException.class)
    public ResponseEntity<ErrorResponse> handlePipelineLaunch(PipelineLaunchException e, HttpServletRequest request) {
        log.error("파이프라인 실행 실패", e);
        return build(HttpStatus.INTERNAL_SERVER_ERROR,
                "파이프라인을 실행할 수 없습니다. 서버의 Python 설정을 확인하세요.", request);
    }

    private ResponseEntity<ErrorResponse> build(HttpStatusCode status, String message, HttpServletRequest request) {
        return ResponseEntity.status(status)
                .body(ErrorResponse.of(status, message, request.getRequestURI()));
    }
}