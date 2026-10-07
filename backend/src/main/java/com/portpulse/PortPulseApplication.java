package com.portpulse;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class PortPulseApplication {

	public static void main(String[] args) {
		SpringApplication.run(PortPulseApplication.class, args);
	}

}
