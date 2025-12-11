package com.vehicletracking.bridge.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class BridgeController {

    private final MongoTemplate mongoTemplate;

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        Map<String, Object> status = new HashMap<>();
        status.put("service", "jms-bridge");
        status.put("status", "running");
        status.put("timestamp", Instant.now().toString());
        
        try {
            long count = mongoTemplate.getCollection("vehicle_events").countDocuments();
            status.put("totalEvents", count);
            status.put("mongodb", "connected");
        } catch (Exception e) {
            status.put("mongodb", "error: " + e.getMessage());
        }
        
        return ResponseEntity.ok(status);
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> health = new HashMap<>();
        health.put("status", "UP");
        return ResponseEntity.ok(health);
    }
}
