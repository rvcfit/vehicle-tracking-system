package com.vehicletracking.bridge;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class JmsBridgeApplication {
    public static void main(String[] args) {
        SpringApplication.run(JmsBridgeApplication.class, args);
    }
}
