package com.vehicletracking.bridge.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import java.time.Instant;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "vehicle_events")
public class VehicleEvent {
    
    @Id
    private String id;
    
    private String licensePlate;
    private String vehicleType;
    private String eventType;
    
    private Double latitude;
    private Double longitude;
    private Double speed;
    private String direction;
    
    private String source;
    private String processedBy;
    
    private Map<String, Object> metadata;
    
    private Instant timestamp;
    private Instant processedAt;
    private Instant receivedAt;
    
    @Builder.Default
    private String status = "RECEIVED";
}
