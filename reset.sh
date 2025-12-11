#!/bin/bash
#===============================================================================
#  Vehicle Tracking System - Reset Script
#  Copyright (c) 2024 - Enterprise Grade Microservices Project
#===============================================================================
#
#  This script completely resets the Vehicle Tracking System to a clean state.
#  WARNING: This will destroy all data!
#
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

#-------------------------------------------------------------------------------
# Banner
#-------------------------------------------------------------------------------

show_banner() {
    echo -e "${RED}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   ⚠️  Vehicle Tracking System - RESET                                        ║
║                                                                              ║
║   WARNING: This will destroy all data and reset to factory defaults!         ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

#-------------------------------------------------------------------------------
# Pre-Reset Status
#-------------------------------------------------------------------------------

show_pre_status() {
    if [ -f "$PROJECT_ROOT/status.sh" ]; then
        source "$PROJECT_ROOT/status.sh"
        show_compact_status "Pre-Reset"
    fi
}

#-------------------------------------------------------------------------------
# Confirm Reset
#-------------------------------------------------------------------------------

confirm_reset() {
    local reset_type=$1
    
    echo -e "${RED}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${RED}│                        ⚠️  WARNING ⚠️                           │${NC}"
    echo -e "${RED}├─────────────────────────────────────────────────────────────────┤${NC}"
    
    case $reset_type in
        "full")
            echo -e "${RED}│ This will:                                                      │${NC}"
            echo -e "${RED}│   • Stop all running containers                                 │${NC}"
            echo -e "${RED}│   • Remove all containers                                       │${NC}"
            echo -e "${RED}│   • Remove all Docker volumes (ALL DATA WILL BE LOST!)         │${NC}"
            echo -e "${RED}│   • Remove all Docker images                                    │${NC}"
            echo -e "${RED}│   • Remove all networks                                         │${NC}"
            echo -e "${RED}│   • Delete local data directories                               │${NC}"
            ;;
        "volumes")
            echo -e "${RED}│ This will:                                                      │${NC}"
            echo -e "${RED}│   • Stop all running containers                                 │${NC}"
            echo -e "${RED}│   • Remove all containers                                       │${NC}"
            echo -e "${RED}│   • Remove all Docker volumes (ALL DATA WILL BE LOST!)         │${NC}"
            echo -e "${RED}│   • Delete local data directories                               │${NC}"
            ;;
        "soft")
            echo -e "${YELLOW}│ This will:                                                      │${NC}"
            echo -e "${YELLOW}│   • Stop all running containers                                 │${NC}"
            echo -e "${YELLOW}│   • Remove all containers                                       │${NC}"
            echo -e "${YELLOW}│   • Preserve all data volumes                                   │${NC}"
            ;;
    esac
    
    echo -e "${RED}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    if [[ "${FORCE:-}" != "true" ]]; then
        echo -e "${YELLOW}Type 'RESET' to confirm (or anything else to cancel):${NC}"
        read -r confirmation
        
        if [ "$confirmation" != "RESET" ]; then
            print_info "Reset cancelled"
            exit 0
        fi
    fi
}

#-------------------------------------------------------------------------------
# Stop All Services
#-------------------------------------------------------------------------------

stop_all() {
    print_header "Stopping All Services"
    
    cd "$PROJECT_ROOT"
    
    print_info "Stopping containers..."
    docker compose down --remove-orphans 2>/dev/null || true
    
    # Force stop any remaining containers
    local containers=$(docker ps -aq --filter "name=vehicle" 2>/dev/null)
    if [ -n "$containers" ]; then
        print_info "Force stopping remaining containers..."
        echo "$containers" | xargs -r docker stop 2>/dev/null || true
        echo "$containers" | xargs -r docker rm -f 2>/dev/null || true
    fi
    
    print_step "All containers stopped"
}

#-------------------------------------------------------------------------------
# Remove Volumes
#-------------------------------------------------------------------------------

remove_volumes() {
    print_header "Removing Docker Volumes"
    
    cd "$PROJECT_ROOT"
    
    # Remove compose volumes
    docker compose down -v 2>/dev/null || true
    
    # Remove any remaining project volumes
    local volumes=$(docker volume ls -q --filter "name=vehicle" 2>/dev/null)
    if [ -n "$volumes" ]; then
        print_info "Removing project volumes..."
        echo "$volumes" | xargs -r docker volume rm 2>/dev/null || true
    fi
    
    # Remove local data directories
    print_info "Removing local data directories..."
    rm -rf "$PROJECT_ROOT/data/mongodb"/* 2>/dev/null || true
    rm -rf "$PROJECT_ROOT/data/rabbitmq"/* 2>/dev/null || true
    rm -rf "$PROJECT_ROOT/data/artemis"/* 2>/dev/null || true
    rm -rf "$PROJECT_ROOT/data/prometheus"/* 2>/dev/null || true
    rm -rf "$PROJECT_ROOT/data/grafana"/* 2>/dev/null || true
    rm -rf "$PROJECT_ROOT/logs"/* 2>/dev/null || true
    
    print_step "All volumes and data removed"
}

#-------------------------------------------------------------------------------
# Remove Images
#-------------------------------------------------------------------------------

remove_images() {
    print_header "Removing Docker Images"
    
    # List of project images
    local images=(
        "vehicle-tracking-artemis"
        "vehicle-tracking-jms-bridge"
        "vehicle-tracking-consumer-java"
        "vehicle-tracking-consumer-node"
        "vehicle-tracking-client-flask"
        "vehicle-tracking_artemis"
        "vehicle-tracking_jms-bridge"
        "vehicle-tracking_consumer-java"
        "vehicle-tracking_consumer-node"
        "vehicle-tracking_client-flask"
    )
    
    for image in "${images[@]}"; do
        if docker images -q "$image" 2>/dev/null | grep -q .; then
            print_info "Removing image: $image"
            docker rmi -f "$image" 2>/dev/null || true
        fi
    done
    
    # Prune dangling images
    print_info "Pruning dangling images..."
    docker image prune -f &>/dev/null || true
    
    print_step "Project images removed"
}

#-------------------------------------------------------------------------------
# Remove Networks
#-------------------------------------------------------------------------------

remove_networks() {
    print_header "Removing Networks"
    
    docker network rm vehicle-tracking_vehicle-network 2>/dev/null || true
    docker network rm vehicle-network 2>/dev/null || true
    docker network prune -f &>/dev/null || true
    
    print_step "Networks removed"
}

#-------------------------------------------------------------------------------
# Clean Build Cache
#-------------------------------------------------------------------------------

clean_build_cache() {
    print_header "Cleaning Build Cache"
    
    print_info "Removing Docker build cache..."
    docker builder prune -f &>/dev/null || true
    
    print_step "Build cache cleaned"
}

#-------------------------------------------------------------------------------
# Reset Configuration
#-------------------------------------------------------------------------------

reset_config() {
    print_header "Resetting Configuration"
    
    # Backup existing .env if it has custom values
    if [ -f "$PROJECT_ROOT/.env" ]; then
        cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup.$(date +%Y%m%d%H%M%S)"
        print_info "Backed up .env file"
    fi
    
    # Remove .env to force regeneration
    rm -f "$PROJECT_ROOT/.env" 2>/dev/null || true
    
    print_step "Configuration reset (will regenerate on next setup)"
}

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------

show_summary() {
    local reset_type=$1
    
    print_header "Reset Complete"
    
    echo -e "${GREEN}The Vehicle Tracking System has been reset.${NC}"
    echo ""
    
    case $reset_type in
        "full")
            echo -e "What was cleaned:"
            echo -e "  ${CYAN}✓${NC} All containers removed"
            echo -e "  ${CYAN}✓${NC} All volumes removed"
            echo -e "  ${CYAN}✓${NC} All images removed"
            echo -e "  ${CYAN}✓${NC} All networks removed"
            echo -e "  ${CYAN}✓${NC} Build cache cleared"
            echo -e "  ${CYAN}✓${NC} Local data directories cleared"
            echo ""
            print_info "Run ${GREEN}./setup.sh${NC} to rebuild everything from scratch"
            ;;
        "volumes")
            echo -e "What was cleaned:"
            echo -e "  ${CYAN}✓${NC} All containers removed"
            echo -e "  ${CYAN}✓${NC} All volumes removed (data cleared)"
            echo -e "  ${CYAN}✓${NC} Local data directories cleared"
            echo ""
            print_info "Run ${GREEN}./start.sh${NC} to start with fresh data"
            ;;
        "soft")
            echo -e "What was cleaned:"
            echo -e "  ${CYAN}✓${NC} All containers removed"
            echo ""
            print_info "Data volumes preserved. Run ${GREEN}./start.sh${NC} to restart"
            ;;
    esac
    
    echo ""
    echo -e "Commands:"
    echo -e "  ${CYAN}•${NC} Full setup:  ${GREEN}./setup.sh${NC}"
    echo -e "  ${CYAN}•${NC} Quick start: ${GREEN}./start.sh${NC}"
}

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Reset the Vehicle Tracking System to a clean state."
    echo ""
    echo "Options:"
    echo "  --soft        Remove containers only, preserve data (default)"
    echo "  --volumes     Remove containers and data volumes"
    echo "  --full        Full reset: containers, volumes, images, cache"
    echo "  --force       Skip confirmation prompt"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --soft     # Quick restart, keep data"
    echo "  $0 --volumes  # Fresh start with no data"
    echo "  $0 --full     # Complete rebuild from scratch"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    local reset_type="soft"
    export FORCE="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --soft)
                reset_type="soft"
                shift
                ;;
            --volumes|-v)
                reset_type="volumes"
                shift
                ;;
            --full|-f)
                reset_type="full"
                shift
                ;;
            --force)
                export FORCE="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    show_banner
    show_pre_status
    confirm_reset "$reset_type"
    
    stop_all
    
    case $reset_type in
        "full")
            remove_volumes
            remove_images
            remove_networks
            clean_build_cache
            reset_config
            ;;
        "volumes")
            remove_volumes
            remove_networks
            ;;
        "soft")
            remove_networks
            ;;
    esac
    
    show_summary "$reset_type"
}

main "$@"
