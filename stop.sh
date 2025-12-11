#!/bin/bash
#===============================================================================
#  Vehicle Tracking System - Stop Script
#  Copyright (c) 2024 - Enterprise Grade Microservices Project
#===============================================================================



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

#-------------------------------------------------------------------------------
# Banner
#-------------------------------------------------------------------------------

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   🛑 Vehicle Tracking System - Stopping Services                             ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

#-------------------------------------------------------------------------------
# Pre-Stop Status
#-------------------------------------------------------------------------------

show_pre_status() {
    if [ -f "$PROJECT_ROOT/status.sh" ]; then
        source "$PROJECT_ROOT/status.sh"
        show_compact_status "Pre-Stop"
    fi
}

#-------------------------------------------------------------------------------
# Show Current Status
#-------------------------------------------------------------------------------

show_status() {
    print_header "Current Service Status"
    
    cd "$PROJECT_ROOT"
    
    local running=$(docker compose ps --format "{{.Name}}" 2>/dev/null | wc -l)
    
    if [ "$running" -eq 0 ]; then
        print_info "No services are currently running"
        return 1
    fi
    
    echo -e "${CYAN}Running containers:${NC}"
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
    echo ""
    
    return 0
}

#-------------------------------------------------------------------------------
# Stop Services
#-------------------------------------------------------------------------------

stop_services() {
    print_header "Stopping Services"
    
    cd "$PROJECT_ROOT"
    
    print_info "Stopping all containers gracefully..."
    
    # Stop in reverse order (monitoring -> apps -> infrastructure)
    local stop_order=(
        "grafana"
        "prometheus"
        "client-flask"
        "consumer-node"
        "consumer-java"
        "jms-bridge"
        "rabbitmq"
        "artemis"
        "mongodb"
    )
    
    for service in "${stop_order[@]}"; do
        if docker compose ps --quiet "$service" 2>/dev/null | grep -q .; then
            echo -ne "  Stopping ${service}..."
            docker compose stop "$service" --timeout 30 &>/dev/null && \
                echo -e " ${GREEN}stopped${NC}" || \
                echo -e " ${YELLOW}skipped${NC}"
        fi
    done
    
    print_step "All services stopped"
}

#-------------------------------------------------------------------------------
# Remove Containers
#-------------------------------------------------------------------------------

remove_containers() {
    print_header "Removing Containers"
    
    cd "$PROJECT_ROOT"
    
    print_info "Removing stopped containers..."
    docker compose down --remove-orphans 2>/dev/null || true
    
    print_step "Containers removed"
}

#-------------------------------------------------------------------------------
# Clean Networks
#-------------------------------------------------------------------------------

clean_networks() {
    print_info "Cleaning up networks..."
    
    # Remove project network
    docker network rm vehicle-tracking_vehicle-network 2>/dev/null || true
    docker network rm vehicle-network 2>/dev/null || true
    
    # Prune unused networks
    docker network prune -f &>/dev/null || true
    
    print_step "Networks cleaned"
}

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------

show_summary() {
    print_header "Stop Complete"
    
    echo -e "${GREEN}All services have been stopped.${NC}"
    echo ""
    echo -e "Options:"
    echo -e "  ${CYAN}•${NC} Start again:     ${GREEN}./start.sh${NC}"
    echo -e "  ${CYAN}•${NC} Full reset:      ${GREEN}./reset.sh${NC}"
    echo -e "  ${CYAN}•${NC} View status:     ${GREEN}docker compose ps${NC}"
    echo ""
    
    # Check if data volumes exist
    local volumes=$(docker volume ls --quiet --filter "name=vehicle-tracking" 2>/dev/null | wc -l)
    if [ "$volumes" -gt 0 ]; then
        print_info "Data volumes preserved ($volumes volumes)"
        echo -e "  To remove data: ${GREEN}./reset.sh --volumes${NC}"
    fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    show_banner
    show_pre_status
    
    if ! show_status; then
        echo ""
        print_step "Nothing to stop - all services are already down"
        exit 0
    fi
    
    # Check for force flag
    if [[ "${1:-}" != "-f" && "${1:-}" != "--force" ]]; then
        echo ""
        read -p "Stop all services? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            exit 0
        fi
    fi
    
    stop_services
    remove_containers
    clean_networks
    show_summary
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -f, --force    Stop without confirmation"
        echo "  -h, --help     Show this help message"
        echo ""
        echo "This script gracefully stops all Vehicle Tracking System services."
        echo "Data volumes are preserved by default. Use ./reset.sh to clear data."
        ;;
    *)
        main "$@"
        ;;
esac
