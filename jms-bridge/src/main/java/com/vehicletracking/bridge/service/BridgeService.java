package com.vehicletracking.bridge.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vehicletracking.bridge.model.VehicleEvent;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.stereotype.Service;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
public class BridgeService {

    private final RabbitTemplate rabbitTemplate;
    private final MongoTemplate mongoTemplate;
    private final ObjectMapper objectMapper;
    
    private final Counter messagesReceived;
    private final Counter messagesPublished;
    private final Counter messagesPersisted;
    private final Counter messagesFailed;
    private final Timer processingTimer;

    @Value("${rabbitmq.exchange:vehicle-exchange}")
    private String exchangeName;

    @Value("${rabbitmq.routing-key:vehicle.events}")
    private String routingKey;

    public BridgeService(RabbitTemplate rabbitTemplate, 
                        MongoTemplate mongoTemplate,
                        ObjectMapper objectMapper,
                        MeterRegistry meterRegistry) {
        this.rabbitTemplate = rabbitTemplate;
        this.mongoTemplate = mongoTemplate;
        this.objectMapper = objectMapper;
        
        this.messagesReceived = Counter.builder("bridge.messages.received")
                .description("Messages received from Artemis")
                .register(meterRegistry);
        this.messagesPublished = Counter.builder("bridge.messages.published")
                .description("Messages published to RabbitMQ")
                .register(meterRegistry);
        this.messagesPersisted = Counter.builder("bridge.messages.persisted")
                .description("Messages persisted to MongoDB")
                .register(meterRegistry);
        this.messagesFailed = Counter.builder("bridge.messages.failed")
                .description("Failed message processing")
                .register(meterRegistry);
        this.processingTimer = Timer.builder("bridge.processing.time")
                .description("Message processing time")
                .register(meterRegistry);
    }

    @JmsListener(destination = "${jms.queue:vehicle.events}")
    public void receiveMessage(String messageBody) {
        Timer.Sample sample = Timer.start();
        messagesReceived.increment();
        
        try {
            log.info("Received message from Artemis: {}", messageBody);
            
            VehicleEvent event = parseMessage(messageBody);
            event.setReceivedAt(Instant.now());
            event.setProcessedBy("jms-bridge");
            
            // Persist to MongoDB
            VehicleEvent saved = mongoTemplate.save(event);
            messagesPersisted.increment();
            log.info("Persisted event to MongoDB: {}", saved.getId());
            
            // Publish to RabbitMQ
            rabbitTemplate.convertAndSend(exchangeName, routingKey, event);
            messagesPublished.increment();
            log.info("Published event to RabbitMQ: {}", event.getLicensePlate());
            
            sample.stop(processingTimer);
            
        } catch (Exception e) {
            messagesFailed.increment();
            log.error("Error processing message: {}", e.getMessage(), e);
        }
    }

    @SuppressWarnings("unchecked")
    private VehicleEvent parseMessage(String messageBody) {
        try {
            Map<String, Object> data = objectMapper.readValue(messageBody, Map.class);
            
            return VehicleEvent.builder()
                    .id(UUID.randomUUID().toString())
                    .licensePlate((String) data.getOrDefault("licensePlate", 
                            data.getOrDefault("license_plate", "UNKNOWN")))
                    .vehicleType((String) data.getOrDefault("vehicleType", 
                            data.getOrDefault("vehicle_type", "CAR")))
                    .eventType((String) data.getOrDefault("eventType", 
                            data.getOrDefault("event_type", "DETECTION")))
                    .latitude(parseDouble(data.get("latitude")))
                    .longitude(parseDouble(data.get("longitude")))
                    .speed(parseDouble(data.get("speed")))
                    .direction((String) data.get("direction"))
                    .source((String) data.getOrDefault("source", "flask-client"))
                    .timestamp(Instant.now())
                    .metadata(data)
                    .status("PROCESSED")
                    .build();
        } catch (Exception e) {
            log.warn("Could not parse as JSON, treating as simple plate: {}", messageBody);
            return VehicleEvent.builder()
                    .id(UUID.randomUUID().toString())
                    .licensePlate(messageBody.trim())
                    .vehicleType("CAR")
                    .eventType("DETECTION")
                    .source("flask-client")
                    .timestamp(Instant.now())
                    .status("PROCESSED")
                    .build();
        }
    }

    private Double parseDouble(Object value) {
        if (value == null) return null;
        if (value instanceof Number) return ((Number) value).doubleValue();
        try {
            return Double.parseDouble(value.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
