package com.vehicletracking.consumer.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Service;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
public class ConsumerService {

    private final MongoTemplate mongoTemplate;
    private final ObjectMapper objectMapper;
    
    private final Counter messagesConsumed;
    private final Counter messagesProcessed;
    private final Counter messagesFailed;
    private final Timer processingTimer;

    public ConsumerService(MongoTemplate mongoTemplate, 
                          ObjectMapper objectMapper,
                          MeterRegistry meterRegistry) {
        this.mongoTemplate = mongoTemplate;
        this.objectMapper = objectMapper;
        
        this.messagesConsumed = Counter.builder("consumer.java.messages.consumed")
                .description("Messages consumed from RabbitMQ")
                .register(meterRegistry);
        this.messagesProcessed = Counter.builder("consumer.java.messages.processed")
                .description("Messages successfully processed")
                .register(meterRegistry);
        this.messagesFailed = Counter.builder("consumer.java.messages.failed")
                .description("Failed message processing")
                .register(meterRegistry);
        this.processingTimer = Timer.builder("consumer.java.processing.time")
                .description("Message processing time")
                .register(meterRegistry);
    }

    @RabbitListener(queues = "${rabbitmq.queue:vehicle.events}")
    public void consumeMessage(Object message) {
        Timer.Sample sample = Timer.start();
        messagesConsumed.increment();
        
        try {
            log.info("Received message from RabbitMQ (Java Consumer): {}", message);
            
            Map<String, Object> eventData = parseMessage(message);
            eventData.put("processedBy", "consumer-java");
            eventData.put("processedAt", Instant.now().toString());
            eventData.put("consumerId", UUID.randomUUID().toString());
            
            mongoTemplate.save(eventData, "processed_events_java");
            
            messagesProcessed.increment();
            log.info("Processed and saved event: {}", eventData.get("licensePlate"));
            
            sample.stop(processingTimer);
            
        } catch (Exception e) {
            messagesFailed.increment();
            log.error("Error processing message: {}", e.getMessage(), e);
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseMessage(Object message) {
        try {
            if (message instanceof Map) {
                return new HashMap<>((Map<String, Object>) message);
            }
            if (message instanceof String) {
                return objectMapper.readValue((String) message, Map.class);
            }
            return objectMapper.convertValue(message, Map.class);
        } catch (Exception e) {
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("rawMessage", message.toString());
            fallback.put("parseError", e.getMessage());
            return fallback;
        }
    }
}
