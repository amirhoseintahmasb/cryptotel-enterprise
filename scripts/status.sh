#!/bin/bash

# Enterprise Platform Status Script
# Shows comprehensive system status

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Enterprise Platform Status${NC}"
echo -e "${BLUE}================================${NC}"
echo "Time: $(date)"
echo ""

# System Resources
echo -e "${YELLOW}=== System Resources ===${NC}"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
echo "Disk Usage: $(df / | tail -1 | awk '{print $5}')"
echo ""

# Docker Swarm Status
echo -e "${YELLOW}=== Docker Swarm Services ===${NC}"
docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Ports}}"
echo ""

# Network Status
echo -e "${YELLOW}=== Networks ===${NC}"
docker network ls --filter "scope=swarm" --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
echo ""

# Service Health Check
echo -e "${YELLOW}=== Service Health ===${NC}"
services=("traefik_traefik" "enterprise-registry_registry" "enterprise-registry_registry-ui" "enterprise-monitoring_prometheus" "enterprise-monitoring_grafana" "enterprise-monitoring_alertmanager" "portainer_portainer")

for service in "${services[@]}"; do
    replicas=$(docker service ls --filter "name=$service" --format "{{.Replicas}}" 2>/dev/null)
    if [ -n "$replicas" ]; then
        if [[ $replicas == *"1/1"* ]]; then
            echo -e "${GREEN}✅ $service: $replicas${NC}"
        else
            echo -e "${RED}❌ $service: $replicas${NC}"
        fi
    else
        echo -e "${RED}❌ $service: Not found${NC}"
    fi
done
echo ""

# Domain Accessibility
echo -e "${YELLOW}=== Domain Status ===${NC}"
domains=("traefik.cryptotel.xyz" "registry.cryptotel.xyz" "registry-ui.cryptotel.xyz" "prometheus.cryptotel.xyz" "grafana.cryptotel.xyz" "alertmanager.cryptotel.xyz")

for domain in "${domains[@]}"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "https://$domain" 2>/dev/null || echo "000")
    if [ "$status" = "200" ] || [ "$status" = "401" ]; then
        echo -e "${GREEN}✅ $domain: HTTP $status${NC}"
    else
        echo -e "${RED}❌ $domain: HTTP $status${NC}"
    fi
done
echo ""

# Docker System Info
echo -e "${YELLOW}=== Docker System Info ===${NC}"
docker system df
echo ""

# Recent Logs
echo -e "${YELLOW}=== Recent Traefik Logs ===${NC}"
docker service logs traefik_traefik --tail 5 2>/dev/null | grep -E "(ERROR|WARN)" || echo "No recent errors"
echo ""

echo -e "${GREEN}Status check completed at: $(date)${NC}" 