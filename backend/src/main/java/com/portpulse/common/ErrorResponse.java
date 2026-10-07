package com.portpulse.common;

import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;

import java.time.LocalDateTime;

public record ErrorResponse(
        int status,
        String code,
        String message,
        String path,
        LocalDateTime timestamp
) {
    public static ErrorResponse of(HttpStatusCode status, String message, String path) {
        HttpStatus resolved = HttpStatus.resolve(status.value());
        String code = (resolved != null) ? resolved.name() : String.valueOf(status.value());
        return new ErrorResponse(status.value(), code, message, path, LocalDateTime.now());
    }
}
