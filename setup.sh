#!/bin/bash
#===============================================================================
#  Vehicle Tracking System - Setup Script
#  Copyright (c) 2024 - Enterprise Grade Microservices Project
#===============================================================================
#
#  This script prepares the environment for running the Vehicle Tracking System.
#  It checks dependencies, creates necessary directories, and configures the system.
#
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#-------------------------------------------------------------------------------
# Utility Functions
#-------------------------------------------------------------------------------

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_step "$1 is installed ($(command -v $1))"
        return 0
    else
        print_error "$1 is NOT installed"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Banner
#-------------------------------------------------------------------------------

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   ██╗   ██╗███████╗██╗  ██╗██╗ ██████╗██╗     ███████╗                       ║
║   ██║   ██║██╔════╝██║  ██║██║██╔════╝██║     ██╔════╝                       ║
║   ██║   ██║█████╗  ███████║██║██║     ██║     █████╗                         ║
║   ╚██╗ ██╔╝██╔══╝  ██╔══██║██║██║     ██║     ██╔══╝                         ║
║    ╚████╔╝ ███████╗██║  ██║██║╚██████╗███████╗███████╗                       ║
║     ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝ ╚═════╝╚══════╝╚══════╝                       ║
║                                                                              ║
║   ████████╗██████╗  █████╗  ██████╗██╗  ██╗██╗███╗   ██╗ ██████╗             ║
║   ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██║████╗  ██║██╔════╝             ║
║      ██║   ██████╔╝███████║██║     █████╔╝ ██║██╔██╗ ██║██║  ███╗            ║
║      ██║   ██╔══██╗██╔══██║██║     ██╔═██╗ ██║██║╚██╗██║██║   ██║            ║
║      ██║   ██║  ██║██║  ██║╚██████╗██║  ██╗██║██║ ╚████║╚██████╔╝            ║
║      ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝             ║
║                                                                              ║
║   Enterprise Microservices Architecture                                      ║
║   ActiveMQ Artemis • RabbitMQ • MongoDB • Spring Boot • Node.js              ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

#-------------------------------------------------------------------------------
# System Requirements Check
#-------------------------------------------------------------------------------

check_system_requirements() {
    print_header "Checking System Requirements"
    
    local all_ok=true
    
    # Check Docker
    if check_command "docker"; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_info "Docker version: $docker_version"
    else
        all_ok=false
        print_error "Docker is required. Install: https://docs.docker.com/engine/install/"
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        print_step "Docker Compose (plugin) is installed"
        local compose_version=$(docker compose version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_info "Docker Compose version: $compose_version"
    elif check_command "docker-compose"; then
        print_warning "Using standalone docker-compose (deprecated)"
    else
        all_ok=false
        print_error "Docker Compose is required"
    fi
    
    # Check Docker daemon
    if docker info &> /dev/null; then
        print_step "Docker daemon is running"
    else
        all_ok=false
        print_error "Docker daemon is NOT running"
        print_info "Start Docker: sudo systemctl start docker"
    fi
    
    # Check user permissions
    if groups | grep -q docker; then
        print_step "User is in docker group"
    else
        print_warning "User not in docker group (may need sudo)"
        print_info "Add user to docker group: sudo usermod -aG docker \$USER"
    fi
    
    # Check available disk space
    local available_space=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$available_space" -ge 10 ]; then
        print_step "Sufficient disk space available (${available_space}GB)"
    else
        print_warning "Low disk space: ${available_space}GB (recommend 10GB+)"
    fi
    
    # Check available memory
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -ge 4 ]; then
        print_step "Sufficient memory available (${total_mem}GB)"
    else
        print_warning "Low memory: ${total_mem}GB (recommend 4GB+)"
    fi
    
    # Optional tools
    echo ""
    print_info "Optional tools check:"
    check_command "curl" || true
    check_command "jq" || true
    check_command "git" || true
    
    if [ "$all_ok" = false ]; then
        echo ""
        print_error "Some requirements are missing. Please install them and run setup again."
        exit 1
    fi
    
    print_step "All system requirements satisfied!"
}

#-------------------------------------------------------------------------------
# Port Availability Check
#-------------------------------------------------------------------------------

check_ports() {
    print_header "Checking Port Availability"
    
    local ports=(
        "5000:Flask Client"
        "5001:Dashboard"
        "8161:Artemis Console"
        "61616:Artemis Core"
        "5672:Artemis AMQP"
        "5673:RabbitMQ AMQP"
        "15672:RabbitMQ Management"
        "27017:MongoDB"
        "8083:JMS Bridge"
        "8081:Consumer Java"
        "3003:Consumer Node"
        "9090:Prometheus"
        "3001:Grafana"
    )
    
    local ports_in_use=()
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"
        
        if ss -tuln | grep -q ":${port} " 2>/dev/null || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            print_warning "Port $port ($service) is in use"
            ports_in_use+=("$port")
        else
            print_step "Port $port ($service) is available"
        fi
    done
    
    if [ ${#ports_in_use[@]} -gt 0 ]; then
        echo ""
        print_warning "Some ports are in use. You may need to stop conflicting services."
        print_info "Use: sudo lsof -i :PORT to identify the process"
        print_info "Or modify ports in docker-compose.yml"
    fi
}

#-------------------------------------------------------------------------------
# Create Configuration Files
#-------------------------------------------------------------------------------

create_env_file() {
    print_header "Creating Environment Configuration"
    
    local env_file="$PROJECT_ROOT/.env"
    
    if [ -f "$env_file" ]; then
        print_warning ".env file already exists"
        read -p "Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_info "Keeping existing .env file"
            return
        fi
        cp "$env_file" "${env_file}.backup.$(date +%Y%m%d%H%M%S)"
        print_info "Backup created"
    fi
    
    cat > "$env_file" << 'ENVFILE'
#===============================================================================
# Vehicle Tracking System - Environment Configuration
#===============================================================================

# Project Settings
PROJECT_NAME=vehicle-tracking
COMPOSE_PROJECT_NAME=vehicle-tracking

#-------------------------------------------------------------------------------
# ActiveMQ Artemis Configuration
#-------------------------------------------------------------------------------
ARTEMIS_USER=admin
ARTEMIS_PASSWORD=admin
ARTEMIS_HOST=artemis
ARTEMIS_PORT=61616
ARTEMIS_CONSOLE_PORT=8161

#-------------------------------------------------------------------------------
# RabbitMQ Configuration
#-------------------------------------------------------------------------------
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=admin
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_EXCHANGE=vehicle-exchange
RABBITMQ_QUEUE=vehicle.events
RABBITMQ_ROUTING_KEY=vehicle.events

#-------------------------------------------------------------------------------
# MongoDB Configuration
#-------------------------------------------------------------------------------
MONGODB_USER=admin
MONGODB_PASSWORD=admin123
MONGODB_HOST=mongodb
MONGODB_PORT=27017
MONGODB_DATABASE=vehicle_tracking
MONGODB_URI=mongodb://admin:admin123@mongodb:27017/vehicle_tracking?authSource=admin

#-------------------------------------------------------------------------------
# Application Ports (External)
#-------------------------------------------------------------------------------
CLIENT_FLASK_PORT=5000
DASHBOARD_PORT=5001
JMS_BRIDGE_PORT=8083
CONSUMER_JAVA_PORT=8081
CONSUMER_NODE_PORT=3003

#-------------------------------------------------------------------------------
# Monitoring Configuration
#-------------------------------------------------------------------------------
PROMETHEUS_PORT=9090
GRAFANA_PORT=3001
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin123

#-------------------------------------------------------------------------------
# JVM Configuration (use quotes for multiple arguments)
#-------------------------------------------------------------------------------
JMS_BRIDGE_JAVA_OPTS="-Xms512m -Xmx1024m"
CONSUMER_JAVA_OPTS="-Xms256m -Xmx512m"

#-------------------------------------------------------------------------------
# Log Level
#-------------------------------------------------------------------------------
LOG_LEVEL=INFO
ENVFILE

    print_step "Created .env file"
    print_info "Edit .env to customize passwords and ports"
}

#-------------------------------------------------------------------------------
# Create Data Directories
#-------------------------------------------------------------------------------

create_directories() {
    print_header "Creating Data Directories"
    
    local dirs=(
        "data/mongodb"
        "data/rabbitmq"
        "data/artemis"
        "data/prometheus"
        "data/grafana"
        "logs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$PROJECT_ROOT/$dir"
        print_step "Created $dir"
    done
    
    # Set permissions for Grafana (runs as user 472)
    chmod 777 "$PROJECT_ROOT/data/grafana" 2>/dev/null || true
    
    print_step "All directories created"
}

#-------------------------------------------------------------------------------
# Pull Docker Images
#-------------------------------------------------------------------------------

pull_images() {
    print_header "Pulling Base Docker Images"
    
    local images=(
        "eclipse-temurin:17-jre-alpine"
        "maven:3.9-eclipse-temurin-17"
        "node:20-alpine"
        "python:3.11-slim"
        "mongo:7"
        "rabbitmq:3.12-management-alpine"
        "prom/prometheus:latest"
        "grafana/grafana:latest"
    )
    
    for image in "${images[@]}"; do
        print_info "Pulling $image..."
        if docker pull "$image" > /dev/null 2>&1; then
            print_step "Pulled $image"
        else
            print_warning "Failed to pull $image (will be pulled during build)"
        fi
    done
}

#-------------------------------------------------------------------------------
# Build Docker Images
#-------------------------------------------------------------------------------

build_images() {
    print_header "Building Docker Images"
    
    cd "$PROJECT_ROOT"
    
    print_info "This may take 5-15 minutes on first run..."
    echo ""
    
    if docker compose build --parallel 2>&1 | tee "$PROJECT_ROOT/logs/build.log"; then
        print_step "All images built successfully!"
    else
        print_error "Build failed! Check logs/build.log for details"
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# Verify Setup
#-------------------------------------------------------------------------------

verify_setup() {
    print_header "Verifying Setup"
    
    local all_ok=true
    
    # Check required files
    local required_files=(
        "docker-compose.yml"
        ".env"
        "artemis/Dockerfile"
        "jms-bridge/Dockerfile"
        "consumer-java/Dockerfile"
        "consumer-node/Dockerfile"
        "client-flask/Dockerfile"
        "monitoring/prometheus/prometheus.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$PROJECT_ROOT/$file" ]; then
            print_step "Found $file"
        else
            print_error "Missing $file"
            all_ok=false
        fi
    done
    
    # Check Docker images
    echo ""
    print_info "Checking built images..."
    
    local expected_images=(
        "vehicle-tracking-artemis"
        "vehicle-tracking-jms-bridge"
        "vehicle-tracking-consumer-java"
        "vehicle-tracking-consumer-node"
        "vehicle-tracking-client-flask"
    )
    
    for image in "${expected_images[@]}"; do
        if docker images | grep -q "$image"; then
            print_step "Image $image exists"
        else
            print_warning "Image $image not found (will be built on start)"
        fi
    done
    
    if [ "$all_ok" = true ]; then
        echo ""
        print_step "Setup verification complete!"
    else
        echo ""
        print_warning "Some files are missing, but setup will continue"
    fi
}

#-------------------------------------------------------------------------------
# Print Summary
#-------------------------------------------------------------------------------

print_summary() {
    print_header "Setup Complete!"
    
    echo -e "${GREEN}The Vehicle Tracking System is ready to start!${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  ${CYAN}1.${NC} Start the system:    ${GREEN}./start.sh${NC}"
    echo -e "  ${CYAN}2.${NC} Stop the system:     ${GREEN}./stop.sh${NC}"
    echo -e "  ${CYAN}3.${NC} Reset everything:    ${GREEN}./reset.sh${NC}"
    echo ""
    echo -e "Service URLs (after starting):"
    echo -e "  ${CYAN}•${NC} Flask Client:        http://localhost:5000"
    echo -e "  ${CYAN}•${NC} Dashboard:           http://localhost:5001"
    echo -e "  ${CYAN}•${NC} Artemis Console:     http://localhost:8161 (admin/admin)"
    echo -e "  ${CYAN}•${NC} RabbitMQ Management: http://localhost:15672 (admin/admin)"
    echo -e "  ${CYAN}•${NC} Prometheus:          http://localhost:9090"
    echo -e "  ${CYAN}•${NC} Grafana:             http://localhost:3001 (admin/admin123)"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------

main() {
    show_banner
    
    echo -e "${GREEN}Starting setup process...${NC}\n"
    
    # Parse arguments
    local skip_pull=false
    local skip_build=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-pull)
                skip_pull=true
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-pull   Skip pulling base Docker images"
                echo "  --skip-build  Skip building Docker images"
                echo "  -h, --help    Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Run setup steps
    check_system_requirements
    check_ports
    create_env_file
    create_directories
    
    if [ "$skip_pull" = false ]; then
        pull_images
    else
        print_info "Skipping image pull (--skip-pull)"
    fi
    
    if [ "$skip_build" = false ]; then
        build_images
    else
        print_info "Skipping image build (--skip-build)"
    fi
    
    verify_setup
    print_summary
}

# Run main function
main "$@"
