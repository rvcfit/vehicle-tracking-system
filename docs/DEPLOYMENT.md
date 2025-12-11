# Deployment Guide

## Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / macOS 12+
- **RAM**: 4GB minimum, 8GB recommended
- **Disk**: 10GB minimum free space
- **CPU**: 2 cores minimum

### Software Requirements
- Docker Engine 20.10+
- Docker Compose 2.0+ (plugin or standalone)

## Installation

### 1. Install Docker (Ubuntu/Debian)

```bash
# Update packages
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Clone Repository

```bash
git clone https://github.com/yourusername/vehicle-tracking-system.git
cd vehicle-tracking-system
```

### 3. Run Setup

```bash
# Make scripts executable
chmod +x setup.sh start.sh stop.sh reset.sh

# Run setup
./setup.sh
```

### 4. Start Services

```bash
./start.sh
```

## Configuration

### Environment Variables

Copy and customize the environment file:

```bash
cp .env.example .env
nano .env
```

Key configurations:

| Variable | Default | Description |
|----------|---------|-------------|
| ARTEMIS_USER | admin | Artemis username |
| ARTEMIS_PASSWORD | admin | Artemis password |
| MONGODB_PASSWORD | admin123 | MongoDB password |
| GRAFANA_PASSWORD | admin123 | Grafana password |

### Port Mapping

Default port mappings can be changed in `.env`:

```bash
CLIENT_FLASK_PORT=5000
GRAFANA_PORT=3001
```

## Operations

### Starting Services

```bash
# Interactive mode
./start.sh

# Detached mode
./start.sh --detach
```

### Stopping Services

```bash
# Graceful stop
./stop.sh

# Force stop
./stop.sh --force
```

### Resetting

```bash
# Soft reset (keep data)
./reset.sh --soft

# Remove data volumes
./reset.sh --volumes

# Full reset (remove everything)
./reset.sh --full
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f jms-bridge

# Last N lines
docker compose logs --tail=100 consumer-java
```

## Health Checks

All services include health checks. View status:

```bash
docker compose ps
```

Check individual service health:

```bash
# Flask Client
curl http://localhost:5000/health

# JMS Bridge
curl http://localhost:8083/actuator/health

# Consumer Java
curl http://localhost:8081/actuator/health

# Consumer Node
curl http://localhost:3003/health
```

## Backup & Restore

### Backup MongoDB

```bash
# Create backup
docker exec vehicle-tracking-mongodb mongodump \
  --username admin \
  --password admin123 \
  --authenticationDatabase admin \
  --out /tmp/backup

# Copy to host
docker cp vehicle-tracking-mongodb:/tmp/backup ./backup-$(date +%Y%m%d)
```

### Restore MongoDB

```bash
# Copy backup to container
docker cp ./backup-20240101 vehicle-tracking-mongodb:/tmp/backup

# Restore
docker exec vehicle-tracking-mongodb mongorestore \
  --username admin \
  --password admin123 \
  --authenticationDatabase admin \
  /tmp/backup
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
docker compose logs <service-name>

# Rebuild service
docker compose build --no-cache <service-name>
```

### Port Already in Use

```bash
# Find process using port
sudo lsof -i :5000

# Kill process or change port in .env
```

### Out of Memory

Reduce JVM heap in `.env`:

```bash
JMS_BRIDGE_JAVA_OPTS=-Xms256m -Xmx512m
CONSUMER_JAVA_OPTS=-Xms128m -Xmx256m
```

### Network Issues

```bash
# Recreate network
docker network rm vehicle-tracking-network
docker compose up -d
```

## Production Considerations

1. **Change all default passwords**
2. **Configure TLS/SSL for external access**
3. **Set up log rotation**
4. **Configure monitoring alerts**
5. **Regular backup schedule**
6. **Resource limits in docker-compose.yml**
