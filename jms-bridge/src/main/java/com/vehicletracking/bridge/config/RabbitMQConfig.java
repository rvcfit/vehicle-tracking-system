package com.vehicletracking.bridge.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    @Value("${rabbitmq.exchange:vehicle-exchange}")
    private String exchangeName;

    @Value("${rabbitmq.queue:vehicle.events}")
    private String queueName;

    @Value("${rabbitmq.routing-key:vehicle.events}")
    private String routingKey;

    @Bean
    public TopicExchange vehicleExchange() {
        return new TopicExchange(exchangeName, true, false);
    }

    @Bean
    public Queue vehicleQueue() {
        return QueueBuilder.durable(queueName)
                .withArgument("x-message-ttl", 86400000) // 24 hours
                .build();
    }

    @Bean
    public Binding binding(Queue vehicleQueue, TopicExchange vehicleExchange) {
        return BindingBuilder
                .bind(vehicleQueue)
                .to(vehicleExchange)
                .with(routingKey);
    }

    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setMessageConverter(jsonMessageConverter());
        template.setExchange(exchangeName);
        template.setRoutingKey(routingKey);
        return template;
    }
}
