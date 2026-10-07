package com.portpulse.common;

import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.format.FormatterRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    public void addFormatters(FormatterRegistry registry){
        registry.addConverter(String.class, LocalDate.class,(Converter<? super String, LocalDate>) source ->{
            String value = source.trim();
            if(value.matches("\\d{8}")){ //20261007
                return LocalDate.parse(value, DateTimeFormatter.BASIC_ISO_DATE);
            }  //2026-10-07
            return LocalDate.parse(value);
        });
    }
}
