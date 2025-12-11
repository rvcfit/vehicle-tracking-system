package com.vehicletracking.bridge.config;

import org.apache.activemq.artemis.jms.client.ActiveMQConnectionFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.annotation.EnableJms;
import org.springframework.jms.config.DefaultJmsListenerContainerFactory;
import org.springframework.jms.core.JmsTemplate;
import jakarta.jms.ConnectionFactory;
import jakarta.jms.JMSException;

@Configuration
@EnableJms
public class ArtemisConfig {

    @Value("${artemis.broker-url:tcp://localhost:61616}")
    private String brokerUrl;

    @Value("${artemis.user:admin}")
    private String user;

    @Value("${artemis.password:admin}")
    private String password;

    @Bean
    public ConnectionFactory connectionFactory() throws JMSException {
        ActiveMQConnectionFactory factory = new ActiveMQConnectionFactory();
        factory.setBrokerURL(brokerUrl);
        factory.setUser(user);
        factory.setPassword(password);
        factory.setRetryInterval(1000);
        factory.setRetryIntervalMultiplier(1.5);
        factory.setMaxRetryInterval(60000);
        factory.setReconnectAttempts(-1);
        return factory;
    }

    @Bean
    public JmsTemplate jmsTemplate(ConnectionFactory connectionFactory) {
        JmsTemplate template = new JmsTemplate(connectionFactory);
        template.setReceiveTimeout(5000);
        return template;
    }

    @Bean
    public DefaultJmsListenerContainerFactory jmsListenerContainerFactory(
            ConnectionFactory connectionFactory) {
        DefaultJmsListenerContainerFactory factory = new DefaultJmsListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setConcurrency("1-5");
        factory.setErrorHandler(t -> System.err.println("JMS Error: " + t.getMessage()));
        return factory;
    }
}
