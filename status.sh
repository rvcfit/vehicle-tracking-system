#!/bin/bash
#===============================================================================
#  Vehicle Tracking System - Status Script
#  SRE-grade service health monitoring
#===============================================================================



# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#-------------------------------------------------------------------------------
# Service Definitions
#-------------------------------------------------------------------------------

declare -A SERVICES=(
    ["mongodb"]="27017|MongoDB|Database"
    ["artemis"]="8161|ActiveMQ Artemis|Message Broker (JMS)"
    ["rabbitmq"]="15672|RabbitMQ|Message Backend (AMQP)"
    ["jms-bridge"]="8083|JMS Bridge|Artemis → RabbitMQ"
    ["consumer-java"]="8081|Consumer Java|RabbitMQ → MongoDB"
    ["consumer-node"]="3003|Consumer Node|RabbitMQ → MongoDB"
    ["client-flask"]="5000|Flask Client|Web Interface"
    ["dashboard"]="5001|Dashboard|Monitoring UI"
    ["prometheus"]="9090|Prometheus|Metrics Collection"
    ["grafana"]="3001|Grafana|Metrics Visualization"
)

SERVICE_ORDER=(
    "mongodb"
    "artemis"
    "rabbitmq"
    "jms-bridge"
    "consumer-java"
    "consumer-node"
    "client-flask"
    "dashboard"
    "prometheus"
    "grafana"
)

#-------------------------------------------------------------------------------
# Utility Functions
#-------------------------------------------------------------------------------

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
}

print_subheader() {
    echo -e "\n${CYAN}─── $1 ───${NC}\n"
}

#-------------------------------------------------------------------------------
# Docker Status Check
#-------------------------------------------------------------------------------

check_docker() {
    if ! docker info &> /dev/null; then
        echo -e "${RED}[✗] Docker is not running!${NC}"
        return 1
    fi
    return 0
}

#-------------------------------------------------------------------------------
# Get Container Status
#-------------------------------------------------------------------------------

get_container_status() {
    local service=$1
    local container_name="vehicle-tracking-${service}"
    if [ "$service" = "client-flask" ]; then
        container_name="vehicle-tracking-client"
    fi
    
    # Try both naming conventions
    local status=$(docker ps -a --filter "name=${container_name}" --format "{{.Status}}" 2>/dev/null | head -1)
    
    if [ -z "$status" ]; then
        # Try without prefix
        status=$(docker ps -a --filter "name=${service}" --format "{{.Status}}" 2>/dev/null | head -1)
    fi
    
    echo "$status"
}

get_container_health() {
    local service=$1
    local container_name="vehicle-tracking-${service}"
    if [ "$service" = "client-flask" ]; then
        container_name="vehicle-tracking-client"
    fi
    
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
    
    if [ -z "$health" ]; then
        health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null)
    fi
    
    echo "$health"
}

get_container_uptime() {
    local service=$1
    local container_name="vehicle-tracking-${service}"
    if [ "$service" = "client-flask" ]; then
        container_name="vehicle-tracking-client"
    fi
    
    local started=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null)
    
    if [ -z "$started" ] || [ "$started" == "0001-01-01T00:00:00Z" ]; then
        echo "-"
        return
    fi
    
    # Calculate uptime
    local start_ts=$(date -d "$started" +%s 2>/dev/null || echo "0")
    local now_ts=$(date +%s)
    local diff=$((now_ts - start_ts))
    
    if [ $diff -lt 60 ]; then
        echo "${diff}s"
    elif [ $diff -lt 3600 ]; then
        echo "$((diff / 60))m"
    elif [ $diff -lt 86400 ]; then
        echo "$((diff / 3600))h $((diff % 3600 / 60))m"
    else
        echo "$((diff / 86400))d $((diff % 86400 / 3600))h"
    fi
}

get_container_memory() {
    local service=$1
    local container_name="vehicle-tracking-${service}"
    if [ "$service" = "client-flask" ]; then
        container_name="vehicle-tracking-client"
    fi
    
    local mem=$(docker stats --no-stream --format "{{.MemUsage}}" "$container_name" 2>/dev/null | cut -d'/' -f1)
    
    if [ -z "$mem" ]; then
        mem=$(docker stats --no-stream --format "{{.MemUsage}}" "$service" 2>/dev/null | cut -d'/' -f1)
    fi
    
    echo "${mem:-N/A}"
}

get_container_cpu() {
    local service=$1
    local container_name="vehicle-tracking-${service}"
    if [ "$service" = "client-flask" ]; then
        container_name="vehicle-tracking-client"
    fi
    
    local cpu=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container_name" 2>/dev/null)
    
    if [ -z "$cpu" ]; then
        cpu=$(docker stats --no-stream --format "{{.CPUPerc}}" "$service" 2>/dev/null)
    fi
    
    echo "${cpu:-N/A}"
}

#-------------------------------------------------------------------------------
# HTTP Health Check
#-------------------------------------------------------------------------------

check_http_endpoint() {
    local port=$1
    local path=${2:-"/"}
    local timeout=${3:-2}
    
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $timeout "http://localhost:${port}${path}" 2>/dev/null)
    
    echo "$http_code"
}

#-------------------------------------------------------------------------------
# Port Check
#-------------------------------------------------------------------------------

check_port() {
    local port=$1
    
    if ss -tuln 2>/dev/null | grep -q ":${port} " || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        return 0
    fi
    return 1
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------

show_system_info() {
    print_subheader "System Information"
    
    echo -e "  ${GRAY}Hostname:${NC}     $(hostname)"
    echo -e "  ${GRAY}Date:${NC}         $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e "  ${GRAY}Docker:${NC}       $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
    echo -e "  ${GRAY}Compose:${NC}      $(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    
    # Memory
    local total_mem=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}')
    local used_mem=$(free -h 2>/dev/null | awk '/^Mem:/{print $3}')
    echo -e "  ${GRAY}Memory:${NC}       ${used_mem} / ${total_mem}"
    
    # Disk
    local disk_usage=$(df -h "$PROJECT_ROOT" 2>/dev/null | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}')
    echo -e "  ${GRAY}Disk:${NC}         ${disk_usage}"
}

show_services_status() {
    print_subheader "Services Status"
    
    # Header
    printf "${CYAN}%-18s %-12s %-10s %-8s %-10s %-8s %-20s${NC}\n" \
        "SERVICE" "STATUS" "HEALTH" "UPTIME" "MEMORY" "CPU" "ENDPOINT"
    echo -e "${GRAY}──────────────────────────────────────────────────────────────────────────────────────────${NC}"
    
    local running=0
    local stopped=0
    local unhealthy=0
    
    for service in "${SERVICE_ORDER[@]}"; do
        IFS='|' read -r port name description <<< "${SERVICES[$service]}"
        
        local status=$(get_container_status "$service")
        local health=$(get_container_health "$service")
        local uptime=$(get_container_uptime "$service")
        local memory=$(get_container_memory "$service")
        local cpu=$(get_container_cpu "$service")
        
        # Determine status display
        local status_display
        local status_color
        
        if [[ "$status" == *"Up"* ]]; then
            status_display="Running"
            status_color=$GREEN
            ((running++))
        elif [[ "$status" == *"Exited"* ]]; then
            status_display="Stopped"
            status_color=$RED
            ((stopped++))
        elif [[ "$status" == *"Restarting"* ]]; then
            status_display="Restarting"
            status_color=$YELLOW
        else
            status_display="Not Found"
            status_color=$GRAY
            ((stopped++))
        fi
        
        # Determine health display
        local health_display
        local health_color
        
        case "$health" in
            "healthy")
                health_display="✓ Healthy"
                health_color=$GREEN
                ;;
            "unhealthy")
                health_display="✗ Unhealthy"
                health_color=$RED
                ((unhealthy++))
                ;;
            "starting")
                health_display="◐ Starting"
                health_color=$YELLOW
                ;;
            *)
                health_display="-"
                health_color=$GRAY
                ;;
        esac
        
        # Check HTTP endpoint
        local endpoint_status=""
        if [[ "$status_display" == "Running" ]]; then
            local http_code=$(check_http_endpoint "$port" "/" 1)
            if [[ "$http_code" =~ ^(200|301|302|401|403)$ ]]; then
                endpoint_status="${GREEN}:${port} ✓${NC}"
            else
                endpoint_status="${YELLOW}:${port} ?${NC}"
            fi
        else
            endpoint_status="${GRAY}:${port}${NC}"
        fi
        
        printf "%-18s ${status_color}%-12s${NC} ${health_color}%-10s${NC} %-8s %-10s %-8s %-20b\n" \
            "$service" "$status_display" "$health_display" "$uptime" "$memory" "$cpu" "$endpoint_status"
    done
    
    echo -e "${GRAY}──────────────────────────────────────────────────────────────────────────────────────────${NC}"
    
    # Summary
    echo ""
    echo -e "  ${GREEN}Running:${NC} $running  ${RED}Stopped:${NC} $stopped  ${YELLOW}Unhealthy:${NC} $unhealthy  ${GRAY}Total:${NC} ${#SERVICE_ORDER[@]}"
}

show_network_status() {
    print_subheader "Network Status"
    
    local network_name="vehicle-tracking-network"
    local network_exists=$(docker network ls --filter "name=${network_name}" --format "{{.Name}}" 2>/dev/null)
    
    if [ -n "$network_exists" ]; then
        echo -e "  ${GREEN}[✓]${NC} Network '${network_name}' exists"
        
        local connected=$(docker network inspect "$network_name" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null)
        if [ -n "$connected" ]; then
            echo -e "  ${GRAY}Connected containers:${NC} $(echo $connected | wc -w)"
        fi
    else
        echo -e "  ${YELLOW}[!]${NC} Network '${network_name}' not found"
    fi
}

show_volumes_status() {
    print_subheader "Volumes Status"
    
    local volumes=(
        "vehicle-tracking-artemis-data"
        "vehicle-tracking-rabbitmq-data"
        "vehicle-tracking-mongodb-data"
        "vehicle-tracking-prometheus-data"
        "vehicle-tracking-grafana-data"
    )
    
    printf "  ${CYAN}%-35s %-15s${NC}\n" "VOLUME" "SIZE"
    echo -e "  ${GRAY}─────────────────────────────────────────────────${NC}"
    
    for vol in "${volumes[@]}"; do
        local exists=$(docker volume ls --filter "name=${vol}" --format "{{.Name}}" 2>/dev/null)
        if [ -n "$exists" ]; then
            local size=$(docker system df -v 2>/dev/null | grep "$vol" | awk '{print $3}' | head -1)
            printf "  %-35s ${GREEN}%-15s${NC}\n" "$vol" "${size:-exists}"
        else
            printf "  %-35s ${GRAY}%-15s${NC}\n" "$vol" "not created"
        fi
    done
}

show_quick_links() {
    print_subheader "Quick Access URLs"
    
    echo -e "  ${CYAN}Flask Client:${NC}        http://localhost:5000"
    echo -e "  ${CYAN}Dashboard:${NC}           http://localhost:5001"
    echo -e "  ${CYAN}Artemis Console:${NC}     http://localhost:8161  ${GRAY}(admin/admin)${NC}"
    echo -e "  ${CYAN}RabbitMQ Management:${NC} http://localhost:15672 ${GRAY}(admin/admin)${NC}"
    echo -e "  ${CYAN}Prometheus:${NC}          http://localhost:9090"
    echo -e "  ${CYAN}Grafana:${NC}             http://localhost:3001  ${GRAY}(admin/admin123)${NC}"
}

#-------------------------------------------------------------------------------
# Compact Status (for embedding in other scripts)
#-------------------------------------------------------------------------------

show_compact_status() {
    local context=${1:-"Current"}
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  📊 ${context} Service Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
    
    printf "${CYAN}%-18s %-12s %-12s %-10s${NC}\n" "SERVICE" "STATUS" "HEALTH" "PORT"
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
    
    local running=0
    local total=0
    
    for service in "${SERVICE_ORDER[@]}"; do
        IFS='|' read -r port name description <<< "${SERVICES[$service]}"
        ((total++))
        
        local status=$(get_container_status "$service")
        local health=$(get_container_health "$service")
        
        local status_display status_color health_display health_color
        
        if [[ "$status" == *"Up"* ]]; then
            status_display="● Running"
            status_color=$GREEN
            ((running++))
        elif [[ "$status" == *"Exited"* ]]; then
            status_display="○ Stopped"
            status_color=$RED
        else
            status_display="○ N/A"
            status_color=$GRAY
        fi
        
        case "$health" in
            "healthy") health_display="✓ OK"; health_color=$GREEN ;;
            "unhealthy") health_display="✗ Fail"; health_color=$RED ;;
            "starting") health_display="◐ Wait"; health_color=$YELLOW ;;
            *) health_display="-"; health_color=$GRAY ;;
        esac
        
        printf "%-18s ${status_color}%-12s${NC} ${health_color}%-12s${NC} %-10s\n" \
            "$service" "$status_display" "$health_display" ":$port"
    done
    
    echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}Running:${NC} $running / $total"
    echo ""
}

#-------------------------------------------------------------------------------
# Export function for other scripts
#-------------------------------------------------------------------------------

# This can be sourced by other scripts
export -f show_compact_status 2>/dev/null || true

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    local mode=${1:-"full"}
    
    if ! check_docker; then
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    
    case "$mode" in
        --compact|-c)
            show_compact_status "${2:-Current}"
            ;;
        --services|-s)
            print_header "Services Status"
            show_services_status
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (none)         Full status report"
            echo "  -c, --compact  Compact status view"
            echo "  -s, --services Services only"
            echo "  -h, --help     Show this help"
            ;;
        *)
            print_header "Vehicle Tracking System - Status Report"
            show_system_info
            show_services_status
            show_network_status
            show_volumes_status
            show_quick_links
            ;;
    esac
}

# Allow sourcing without running
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
