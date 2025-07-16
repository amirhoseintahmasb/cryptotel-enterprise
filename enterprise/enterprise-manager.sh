#!/bin/bash

# Enterprise Multi-Startup Management Script
# This script provides comprehensive management for all enterprise services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENTERPRISE_ROOT="/opt/cryptotel/enterprise"
DOMAIN="cryptotel.xyz"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check service health
check_service_health() {
    local service_name=$1
    local service_id=$(docker service ls --filter "name=$service_name" --format "{{.ID}}" 2>/dev/null)
    
    if [ -n "$service_id" ]; then
        local replicas=$(docker service ls --filter "name=$service_name" --format "{{.Replicas}}" 2>/dev/null)
        if [[ $replicas == *"1/1"* ]] || [[ $replicas == *"0/1"* ]]; then
            print_status "$service_name: $replicas"
        else
            print_warning "$service_name: $replicas"
        fi
    else
        print_error "$service_name: Not found"
    fi
}

# Function to check domain accessibility
check_domain() {
    local domain=$1
    local status=$(curl -s -o /dev/null -w "%{http_code}" "https://$domain" 2>/dev/null || echo "000")
    
    if [ "$status" = "200" ] || [ "$status" = "401" ]; then
        print_status "$domain: Accessible (HTTP $status)"
    else
        print_warning "$domain: Not accessible (HTTP $status)"
    fi
}

# Function to show enterprise status
show_status() {
    print_header "Enterprise Services Status"
    
    echo -e "\n${BLUE}Docker Swarm Services:${NC}"
    docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Ports}}"
    
    echo -e "\n${BLUE}Service Health Check:${NC}"
    check_service_health "enterprise-registry_registry"
    check_service_health "enterprise-registry_registry-ui"
    check_service_health "enterprise-monitoring_prometheus"
    check_service_health "enterprise-monitoring_grafana"
    check_service_health "enterprise-monitoring_alertmanager"
    check_service_health "enterprise-monitoring_node-exporter"
    check_service_health "enterprise-monitoring_cadvisor"
    
    echo -e "\n${BLUE}Domain Accessibility:${NC}"
    check_domain "traefik.$DOMAIN"
    check_domain "portainer.$DOMAIN"
    check_domain "registry.$DOMAIN"
    check_domain "registry-ui.$DOMAIN"
    check_domain "prometheus.$DOMAIN"
    check_domain "grafana.$DOMAIN"
    check_domain "alertmanager.$DOMAIN"
    check_domain "cadvisor.$DOMAIN"
    
    echo -e "\n${BLUE}System Resources:${NC}"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
    echo "Disk Usage: $(df / | tail -1 | awk '{print $5}')"
}

# Function to deploy a startup stack
deploy_startup() {
    local startup_name=$1
    local stack_file="$ENTERPRISE_ROOT/stacks/$startup_name/docker-compose.yml"
    
    if [ ! -f "$stack_file" ]; then
        print_error "Stack file not found: $stack_file"
        return 1
    fi
    
    print_status "Deploying startup: $startup_name"
    cd "$ENTERPRISE_ROOT/stacks/$startup_name"
    docker stack deploy -c docker-compose.yml "$startup_name"
    print_status "Startup $startup_name deployed successfully"
}

# Function to remove a startup stack
remove_startup() {
    local startup_name=$1
    
    print_status "Removing startup: $startup_name"
    docker stack rm "$startup_name"
    print_status "Startup $startup_name removed successfully"
}

# Function to backup enterprise data
backup_enterprise() {
    print_status "Starting enterprise backup..."
    cd "$ENTERPRISE_ROOT/backups"
    
    if [ -f "backup-scripts/daily-backup.sh" ]; then
        ./backup-scripts/daily-backup.sh
        print_status "Enterprise backup completed"
    else
        print_error "Backup script not found"
        return 1
    fi
}

# Function to show logs
show_logs() {
    local service_name=$1
    local lines=${2:-50}
    
    print_status "Showing logs for $service_name (last $lines lines):"
    docker service logs --tail $lines "$service_name" 2>/dev/null || print_error "Service not found"
}

# Function to scale service
scale_service() {
    local service_name=$1
    local replicas=$2
    
    print_status "Scaling $service_name to $replicas replicas"
    docker service scale "$service_name=$replicas"
    print_status "Service scaled successfully"
}

# Function to show help
show_help() {
    echo "Enterprise Multi-Startup Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status                    Show enterprise services status"
    echo "  deploy <startup>          Deploy a startup stack"
    echo "  remove <startup>          Remove a startup stack"
    echo "  backup                    Backup enterprise data"
    echo "  logs <service> [lines]    Show service logs"
    echo "  scale <service> <replicas> Scale a service"
    echo "  help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 deploy startup1"
    echo "  $0 logs enterprise-monitoring_grafana"
    echo "  $0 scale enterprise-monitoring_grafana 2"
}

# Main script logic
case "$1" in
    "status")
        show_status
        ;;
    "deploy")
        if [ -z "$2" ]; then
            print_error "Startup name required"
            exit 1
        fi
        deploy_startup "$2"
        ;;
    "remove")
        if [ -z "$2" ]; then
            print_error "Startup name required"
            exit 1
        fi
        remove_startup "$2"
        ;;
    "backup")
        backup_enterprise
        ;;
    "logs")
        if [ -z "$2" ]; then
            print_error "Service name required"
            exit 1
        fi
        show_logs "$2" "$3"
        ;;
    "scale")
        if [ -z "$2" ] || [ -z "$3" ]; then
            print_error "Service name and replicas required"
            exit 1
        fi
        scale_service "$2" "$3"
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac 