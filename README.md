# 🚗 Vehicle Tracking System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Java](https://img.shields.io/badge/Java-17-orange.svg)](https://openjdk.java.net/)
[![Node.js](https://img.shields.io/badge/Node.js-20-green.svg)](https://nodejs.org/)
[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)

Enterprise-grade microservices architecture for real-time vehicle tracking and event processing. Built with ActiveMQ Artemis, RabbitMQ, MongoDB, Spring Boot, and Node.js.

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Quick Start](#-quick-start)
- [Components](#-components)
- [Configuration](#-configuration)
- [API Reference](#-api-reference)
- [Monitoring](#-monitoring)
- [Development](#-development)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

## 🎯 Overview

The Vehicle Tracking System is a production-ready microservices platform designed for:

- **Real-time vehicle event processing** - Track vehicle detections, entries, exits, and alerts
- **Multi-protocol messaging** - JMS 1.1/2.0, AMQP, MQTT, STOMP support via ActiveMQ Artemis
- **Scalable architecture** - Independent consumers in Java and Node.js
- **Full observability** - Prometheus metrics and Grafana dashboards
- **Enterprise reliability** - Health checks, automatic recovery, and data persistence

### Key Features

✅ One-command setup and deployment  
✅ Multi-language consumer support (Java, Node.js)  
✅ Full observability stack (Prometheus + Grafana)  
✅ Automatic message routing and persistence  
✅ RESTful API with real-time dashboard  
✅ Docker-based deployment  
✅ Production-ready configurations  

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Vehicle Tracking System                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐        │
│  │    Flask     │  STOMP  │   ActiveMQ   │   JMS   │     JMS      │        │
│  │   Client     │────────▶│   Artemis    │────────▶│    Bridge    │        │
│  │  (Port 5000) │         │ (Port 61616) │         │ (Port 8083)  │        │
│  └──────────────┘         └──────────────┘         └──────┬───────┘        │
│                                                           │                 │
│                                                    ┌──────┴───────┐        │
│                                                    │              │        │
│                                                    ▼              ▼        │
│                                            ┌───────────┐  ┌───────────┐   │
│                                            │  MongoDB  │  │ RabbitMQ  │   │
│                                            │   (27017) │  │  (5672)   │   │
│                                            └─────┬─────┘  └─────┬─────┘   │
│                                                  │              │         │
│                                                  │       ┌──────┴──────┐  │
│                                                  │       │             │  │
│                                                  │       ▼             ▼  │
│                                                  │ ┌──────────┐ ┌──────────┐
│                                                  │ │ Consumer │ │ Consumer │
│                                                  │ │   Java   │ │   Node   │
│                                                  │ │  (8081)  │ │  (3003)  │
│                                                  │ └────┬─────┘ └────┬─────┘
│                                                  │      │            │     │
│                                                  └──────┴────────────┘     │
│                                                         │                  │
│  ┌──────────────┐         ┌──────────────┐             │                  │
│  │   Grafana    │◀────────│  Prometheus  │◀────────────┘                  │
│  │  (Port 3001) │         │  (Port 9090) │     Metrics                    │
│  └──────────────┘         └──────────────┘                                │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Flask Client** sends vehicle events via STOMP protocol
2. **ActiveMQ Artemis** receives and queues messages (JMS 1.1 compatible)
3. **JMS Bridge** consumes from Artemis, persists to MongoDB, publishes to RabbitMQ
4. **RabbitMQ** routes messages to consumers
5. **Consumers** (Java/Node.js) process and store events
6. **Prometheus** collects metrics from all services
7. **Grafana** visualizes system health and performance

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- 10GB disk space

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/vehicle-tracking-system.git
cd vehicle-tracking-system

# Run setup (checks dependencies, creates configs, builds images)
./setup.sh

# Start all services
./start.sh
```

### Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Flask Client | http://localhost:5000 | - |
| Dashboard | http://localhost:5001 | - |
| Artemis Console | http://localhost:8161 | admin / admin |
| RabbitMQ Management | http://localhost:15672 | admin / admin |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3001 | admin / admin123 |

### Test the System

```bash
# Send a test vehicle event
curl -X POST http://localhost:5000/api/send \
  -H "Content-Type: application/json" \
  -d '{"licensePlate": "ABC-1234", "vehicleType": "CAR", "eventType": "DETECTION"}'

# Check the dashboard
open http://localhost:5001
```

## 📦 Components

### ActiveMQ Artemis (Message Broker)
- **Role**: Primary message broker with JMS 1.1/2.0 support
- **Protocols**: Core, AMQP, STOMP, MQTT, OpenWire
- **Port**: 61616 (Core), 8161 (Console)

### RabbitMQ (Message Backend)
- **Role**: High-performance message routing
- **Protocol**: AMQP 0.9.1
- **Port**: 5672 (AMQP), 15672 (Management)

### JMS Bridge (Spring Boot)
- **Role**: Consumes from Artemis, persists to MongoDB, publishes to RabbitMQ
- **Technology**: Spring Boot 3.2, Java 17
- **Port**: 8083

### Consumer Java (Spring Boot)
- **Role**: Processes messages from RabbitMQ
- **Technology**: Spring Boot 3.2, Java 17
- **Port**: 8081

### Consumer Node (Node.js)
- **Role**: Alternative consumer implementation
- **Technology**: Node.js 20, Express
- **Port**: 3003

### Flask Client
- **Role**: Web interface for sending vehicle events
- **Technology**: Python 3.11, Flask
- **Port**: 5000

### MongoDB
- **Role**: Document storage for vehicle events
- **Port**: 27017

## ⚙️ Configuration

### Environment Variables

All configuration is managed through the `.env` file:

```bash
# Artemis Configuration
ARTEMIS_USER=admin
ARTEMIS_PASSWORD=admin
ARTEMIS_PORT=61616

# RabbitMQ Configuration
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=admin
RABBITMQ_PORT=5672

# MongoDB Configuration
MONGODB_USER=admin
MONGODB_PASSWORD=admin123
MONGODB_PORT=27017

# Service Ports
CLIENT_FLASK_PORT=5000
JMS_BRIDGE_PORT=8083
GRAFANA_PORT=3001
```

### Customization

Edit `.env` before running `./start.sh` to customize:
- Service ports
- Credentials
- JVM memory settings
- Log levels

## 📡 API Reference

### Flask Client API

#### Send Vehicle Event
```http
POST /api/send
Content-Type: application/json

{
  "licensePlate": "ABC-1234",
  "vehicleType": "CAR",
  "eventType": "DETECTION",
  "latitude": -23.5505,
  "longitude": -46.6333,
  "speed": 60,
  "direction": "N"
}
```

#### Send Batch Events
```http
POST /api/send/batch
Content-Type: application/json

[
  {"licensePlate": "ABC-1234", "vehicleType": "CAR"},
  {"licensePlate": "XYZ-5678", "vehicleType": "TRUCK"}
]
```

#### Check Status
```http
GET /api/status
```

## 📊 Monitoring

### Prometheus Metrics

All services expose Prometheus metrics:

- `bridge_messages_received_total` - Messages received from Artemis
- `bridge_messages_published_total` - Messages published to RabbitMQ
- `bridge_messages_failed_total` - Failed message processing
- `consumer_*_messages_processed_total` - Consumer processing counts

### Grafana Dashboards

Pre-configured dashboards available at http://localhost:3001:

1. **Vehicle Tracking Overview** - System-wide metrics
2. **Message Flow** - Real-time message rates
3. **Consumer Performance** - Processing latency and throughput

## 🛠 Development

### Project Structure

```
vehicle-tracking-system/
├── artemis/                 # ActiveMQ Artemis configuration
├── client-flask/            # Flask web client
├── consumer-java/           # Java consumer (Spring Boot)
├── consumer-node/           # Node.js consumer
├── jms-bridge/              # JMS Bridge service
├── monitoring/              # Prometheus & Grafana configs
│   ├── grafana/
│   └── prometheus/
├── proto/                   # Protocol buffer definitions
├── scripts/                 # Utility scripts
├── docs/                    # Documentation
├── docker-compose.yml       # Service orchestration
├── setup.sh                 # Setup script
├── start.sh                 # Start script
├── stop.sh                  # Stop script
└── reset.sh                 # Reset script
```

### Building Individual Services

```bash
# Build specific service
docker compose build jms-bridge

# Build all services
docker compose build

# Build without cache
docker compose build --no-cache
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f jms-bridge

# Last 100 lines
docker compose logs --tail=100 consumer-java
```

## 🔧 Troubleshooting

### Common Issues

#### Services not starting
```bash
# Check service status
docker compose ps

# View logs for failed service
docker compose logs <service-name>
```

#### Port conflicts
```bash
# Check what's using a port
sudo lsof -i :5000

# Change ports in .env file
CLIENT_FLASK_PORT=5100
```

#### Out of memory
```bash
# Increase Docker memory limit
# Docker Desktop: Settings > Resources > Memory

# Or reduce JVM memory in .env
JMS_BRIDGE_JAVA_OPTS=-Xms256m -Xmx512m
```

### Reset Everything

```bash
# Soft reset (keep data)
./reset.sh --soft

# Full reset (delete all data)
./reset.sh --full
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ActiveMQ Artemis](https://activemq.apache.org/components/artemis/)
- [RabbitMQ](https://www.rabbitmq.com/)
- [Spring Boot](https://spring.io/projects/spring-boot)
- [MongoDB](https://www.mongodb.com/)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)

---

<p align="center">
  Made with ❤️ for the DevOps/SRE community
</p>
