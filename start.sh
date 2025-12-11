#!/bin/bash
#===============================================================================
#  Vehicle Tracking System - Start Script
#  Copyright (c) 2024 - Enterprise Grade Microservices Project
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#-------------------------------------------------------------------------------
# Utility Functions
#-------------------------------------------------------------------------------

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}\n"
}

print_step() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

show_spinner() {
    local pid=$1
    local msg=$2
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] %s" "$spinstr" "$msg"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r\033[K"
    done
}

#-------------------------------------------------------------------------------
# Banner
#-------------------------------------------------------------------------------

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   🚗 Vehicle Tracking System - Starting Services                             ║
║                                                                              ║
║   Architecture:                                                              ║
║   ┌──────────┐    ┌─────────┐    ┌──────────┐    ┌────────────┐              ║
║   │  Flask   │───▶│ Artemis │───▶│  Bridge  │───▶│  RabbitMQ  │              ║
║   │  Client  │    │  (JMS)  │    │          │    │            │              ║
║   └──────────┘    └─────────┘    └────┬─────┘    └─────┬──────┘              ║
║                                       │                │                     ║
║                                       ▼                ▼                     ║
║                                  ┌─────────┐    ┌────────────┐               ║
║                                  │ MongoDB │◀───│ Consumers  │               ║
║                                  └─────────┘    └────────────┘               ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

#-------------------------------------------------------------------------------
# Pre-flight Checks
#-------------------------------------------------------------------------------

show_pre_status() {
    if [ -f "$PROJECT_ROOT/status.sh" ]; then
        source "$PROJECT_ROOT/status.sh"
        show_compact_status "Pre-Start"
    fi
}

preflight_checks() {
    print_header "Pre-flight Checks"
    
    # Check Docker
    if ! docker info &> /dev/null; then
        print_error "Docker is not running!"
        print_info "Start Docker: sudo systemctl start docker"
        exit 1
    fi
    print_step "Docker is running"
    
    # Check .env file
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        print_warning ".env file not found, running setup first..."
        "$PROJECT_ROOT/setup.sh" --skip-pull --skip-build
    fi
    print_step "Environment file exists"
    
    # Check docker-compose.yml
    if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found!"
        print_info "Run ./setup.sh first"
        exit 1
    fi
    print_step "Docker Compose file exists"
    
    # Source environment
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
    print_step "Environment loaded"
}

#-------------------------------------------------------------------------------
# Start Services
#-------------------------------------------------------------------------------

start_services() {
    print_header "Starting Services"
    
    cd "$PROJECT_ROOT"
    
    # Check if services are already running
    if docker compose ps --quiet 2>/dev/null | grep -q .; then
        print_warning "Some services are already running"
        read -p "Restart all services? (y/N): " restart
        if [[ "$restart" =~ ^[Yy]$ ]]; then
            print_info "Stopping existing services..."
            docker compose down --remove-orphans
        else
            print_info "Attaching to existing services..."
            docker compose logs -f
            exit 0
        fi
    fi
    
    # Start infrastructure services first
    print_info "Starting infrastructure services (MongoDB, RabbitMQ, Artemis)..."
    docker compose up -d mongodb rabbitmq artemis
    
    # Wait for infrastructure
    print_info "Waiting for infrastructure to be healthy..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local healthy=0
        
        # Check MongoDB
        if docker compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
            ((healthy++))
        fi
        
        # Check RabbitMQ
        if docker compose exec -T rabbitmq rabbitmq-diagnostics ping &>/dev/null; then
            ((healthy++))
        fi
        
        # Check Artemis (simple curl check)
        if curl -s http://localhost:8161 &>/dev/null; then
            ((healthy++))
        fi
        
        if [ $healthy -eq 3 ]; then
            break
        fi
        
        ((attempt++))
        echo -ne "\r  Waiting for services... ($attempt/$max_attempts) [MongoDB: $([[ $healthy -ge 1 ]] && echo '✓' || echo '○')] [RabbitMQ: $([[ $healthy -ge 2 ]] && echo '✓' || echo '○')] [Artemis: $([[ $healthy -eq 3 ]] && echo '✓' || echo '○')]"
        sleep 2
    done
    echo ""
    
    if [ $attempt -eq $max_attempts ]; then
        print_warning "Infrastructure took longer than expected, continuing anyway..."
    else
        print_step "Infrastructure services are healthy"
    fi
    
    # Start application services
    print_info "Starting application services..."
    docker compose up -d jms-bridge consumer-java consumer-node client-flask
    
    # Start monitoring
    print_info "Starting monitoring services..."
    docker compose up -d prometheus grafana
    
    print_step "All services started!"
}

#-------------------------------------------------------------------------------
# Health Check
#-------------------------------------------------------------------------------

health_check() {
    print_header "Service Health Check"
    
    local services=(
        "mongodb:27017:MongoDB"
        "artemis:8161:ActiveMQ Artemis"
        "rabbitmq:15672:RabbitMQ"
        "jms-bridge:8083:JMS Bridge"
        "consumer-java:8081:Consumer Java"
        "consumer-node:3003:Consumer Node"
        "client-flask:5000:Flask Client"
        "prometheus:9090:Prometheus"
        "grafana:3001:Grafana"
    )
    
    echo -e "\n${CYAN}┌────────────────────┬──────────┬────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ Service            │ Status   │ URL                            │${NC}"
    echo -e "${CYAN}├────────────────────┼──────────┼────────────────────────────────┤${NC}"
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r name port display <<< "$service_info"
        
        local status="Starting"
        local color=$YELLOW
        
        # Check container status
        local container_status=$(docker compose ps --format json "$name" 2>/dev/null | grep -o '"Status":"[^"]*"' | cut -d'"' -f4 || echo "")
        
        if [[ "$container_status" == *"Up"* ]]; then
            # Try HTTP check
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -qE "200|302|401"; then
                status="Running ✓"
                color=$GREEN
            else
                status="Up"
                color=$GREEN
            fi
        elif [[ "$container_status" == *"Exit"* ]]; then
            status="Failed ✗"
            color=$RED
        fi
        
        printf "${CYAN}│${NC} %-18s ${CYAN}│${NC} ${color}%-8s${NC} ${CYAN}│${NC} %-30s ${CYAN}│${NC}\n" \
            "$display" "$status" "http://localhost:$port"
    done
    
    echo -e "${CYAN}└────────────────────┴──────────┴────────────────────────────────┘${NC}"
}

#-------------------------------------------------------------------------------
# Show Credentials
#-------------------------------------------------------------------------------

show_credentials() {
    print_header "Access Credentials"
    
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ Service             │ Username │ Password                       │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} Artemis Console     ${CYAN}│${NC} admin    ${CYAN}│${NC} admin                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} RabbitMQ Management ${CYAN}│${NC} admin    ${CYAN}│${NC} admin                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} Grafana             ${CYAN}│${NC} admin    ${CYAN}│${NC} admin123                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} MongoDB             ${CYAN}│${NC} admin    ${CYAN}│${NC} admin123                       ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
}

#-------------------------------------------------------------------------------
# Show Logs Option
#-------------------------------------------------------------------------------

show_logs_option() {
    echo ""
    print_info "View logs:"
    echo -e "  ${CYAN}•${NC} All services:    ${GREEN}docker compose logs -f${NC}"
    echo -e "  ${CYAN}•${NC} Specific service: ${GREEN}docker compose logs -f <service>${NC}"
    echo -e "  ${CYAN}•${NC} Available: mongodb, artemis, rabbitmq, jms-bridge,"
    echo -e "            consumer-java, consumer-node, client-flask,"
    echo -e "            prometheus, grafana"
    echo ""
    
    read -p "Follow logs now? (y/N): " follow_logs
    if [[ "$follow_logs" =~ ^[Yy]$ ]]; then
        docker compose logs -f
    fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    show_banner
    show_pre_status
    preflight_checks
    start_services
    
    # Wait a bit for services to fully initialize
    sleep 5
    
    health_check
    show_credentials
    
    echo ""
    print_step "Vehicle Tracking System is running!"
    echo ""
    echo -e "Quick start:"
    echo -e "  ${CYAN}1.${NC} Open ${GREEN}http://localhost:5000${NC} to send vehicle events"
    echo -e "  ${CYAN}2.${NC} Open ${GREEN}http://localhost:5001${NC} to view the dashboard"
    echo -e "  ${CYAN}3.${NC} Open ${GREEN}http://localhost:3001${NC} to view Grafana metrics"
    echo ""
    
    show_logs_option
}

# Handle arguments
case "${1:-}" in
    --detach|-d)
        show_banner
        preflight_checks
        start_services
        health_check
        print_step "Services started in detached mode"
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -d, --detach   Start in detached mode (no log follow prompt)"
        echo "  -h, --help     Show this help message"
        ;;
    *)
        main
        ;;
esac
