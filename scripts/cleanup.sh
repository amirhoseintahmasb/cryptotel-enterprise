#!/bin/bash

# Enterprise Platform Cleanup Script
# Removes unused Docker resources to free up space

echo "=== Enterprise Platform Cleanup ==="
echo "Started at: $(date)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check disk usage before
echo -e "${YELLOW}Disk usage before cleanup:${NC}"
df -h /

# Remove images older than 7 days (not just unused)
echo -e "${YELLOW}Removing images older than 7 days...${NC}"
docker image prune -a -f --filter "until=168h"

# Remove stopped containers
echo -e "${YELLOW}Removing stopped containers...${NC}"
docker container prune -f

# Remove unused volumes
echo -e "${YELLOW}Removing unused volumes...${NC}"
docker volume prune -f

# Remove unused networks
echo -e "${YELLOW}Removing unused networks...${NC}"
docker network prune -f

# Clean up build cache
echo -e "${YELLOW}Cleaning build cache...${NC}"
docker builder prune -f

# Remove dangling images
echo -e "${YELLOW}Removing dangling images...${NC}"
docker image prune -f

# Check disk usage after
echo -e "${YELLOW}Disk usage after cleanup:${NC}"
df -h /

# Show Docker system info
echo -e "${YELLOW}Docker system info:${NC}"
docker system df

echo -e "${GREEN}Cleanup completed at: $(date)${NC}" 