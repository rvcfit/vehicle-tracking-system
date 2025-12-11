# Architecture Documentation

## System Overview

The Vehicle Tracking System follows a microservices architecture pattern with event-driven communication.

## Components

### 1. Message Brokers

#### ActiveMQ Artemis
- **Purpose**: Enterprise-grade JMS message broker
- **Protocols**: JMS 1.1/2.0, AMQP 1.0, MQTT 3.1.1, STOMP 1.2
- **Features**:
  - High availability clustering
  - Persistence with journal storage
  - Multi-protocol support
  - Web management console

#### RabbitMQ
- **Purpose**: High-performance message routing
- **Protocol**: AMQP 0.9.1
- **Features**:
  - Exchange-based routing
  - Dead letter queues
  - Message TTL
  - Management UI

### 2. Applications

#### JMS Bridge (Java/Spring Boot)
- Consumes from Artemis via JMS
- Persists events to MongoDB
- Publishes to RabbitMQ
- Exposes Prometheus metrics

#### Consumers
- **Java Consumer**: Spring Boot application
- **Node.js Consumer**: Express-based application
- Both process messages from RabbitMQ and store in MongoDB

#### Flask Client
- Web interface for sending events
- Uses STOMP protocol to connect to Artemis
- RESTful API endpoints

### 3. Data Storage

#### MongoDB
- Document-oriented storage
- Collections:
  - `vehicle_events`: Raw events from bridge
  - `processed_events_java`: Java consumer output
  - `processed_events_node`: Node.js consumer output
- Automatic TTL cleanup (30 days)

### 4. Monitoring

#### Prometheus
- Metrics collection from all services
- Alert rule evaluation
- 15-second scrape interval

#### Grafana
- Visualization dashboards
- Pre-configured data sources
- Real-time monitoring

## Data Flow

```
1. User submits event via Flask Client
   ↓
2. STOMP message sent to Artemis queue
   ↓
3. JMS Bridge consumes message
   ├── Persists to MongoDB (vehicle_events)
   └── Publishes to RabbitMQ exchange
       ↓
4. RabbitMQ routes to consumers
   ├── Java Consumer → MongoDB (processed_events_java)
   └── Node Consumer → MongoDB (processed_events_node)
```

## Network Architecture

All services communicate via Docker network `vehicle-tracking-network`.

| Service | Internal Port | External Port |
|---------|--------------|---------------|
| Artemis | 61616, 8161 | 61616, 8161 |
| RabbitMQ | 5672, 15672 | 5673, 15672 |
| MongoDB | 27017 | 27017 |
| JMS Bridge | 8080 | 8083 |
| Consumer Java | 8080 | 8081 |
| Consumer Node | 3000 | 3003 |
| Flask Client | 5000 | 5000 |
| Prometheus | 9090 | 9090 |
| Grafana | 3000 | 3001 |

## Scalability

### Horizontal Scaling
- Consumers can be scaled independently
- RabbitMQ handles load distribution
- MongoDB supports replica sets

### Vertical Scaling
- JVM heap configuration via environment variables
- Resource limits in docker-compose.yml

## Security Considerations

- All services run as non-root users
- Credentials managed via environment variables
- Network isolation via Docker networks
- No external network access by default
