#!/bin/bash

# Enterprise Platform Project Deployment Script
# Usage: ./deploy-project.sh <project-name> [image-tag]

PROJECT_NAME=$1
IMAGE_TAG=${2:-latest}
REGISTRY_URL="registry.cryptotel.xyz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if project name is provided
if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name> [image-tag]"
    exit 1
fi

echo -e "${YELLOW}=== Deploying Project: $PROJECT_NAME ===${NC}"
echo "Image tag: $IMAGE_TAG"
echo "Registry: $REGISTRY_URL"

# Check if project directory exists
PROJECT_DIR="/opt/cryptotel/projects/$PROJECT_NAME"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Error: Project directory not found: $PROJECT_DIR${NC}"
    exit 1
fi

cd "$PROJECT_DIR"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found in $PROJECT_DIR${NC}"
    exit 1
fi

# Build and push image if Dockerfile exists
if [ -f "Dockerfile" ]; then
    echo -e "${YELLOW}Building Docker image...${NC}"
    docker build -t $REGISTRY_URL/$PROJECT_NAME:$IMAGE_TAG .
    docker build -t $REGISTRY_URL/$PROJECT_NAME:latest .
    
    echo -e "${YELLOW}Pushing to registry...${NC}"
    docker push $REGISTRY_URL/$PROJECT_NAME:$IMAGE_TAG
    docker push $REGISTRY_URL/$PROJECT_NAME:latest
fi

# Deploy to swarm
echo -e "${YELLOW}Deploying to Docker Swarm...${NC}"
docker stack deploy -c docker-compose.yml $PROJECT_NAME

# Wait for deployment
echo -e "${YELLOW}Waiting for deployment to complete...${NC}"
sleep 10

# Check service status
echo -e "${YELLOW}Service status:${NC}"
docker service ls --filter "name=$PROJECT_NAME"

echo -e "${GREEN}Project $PROJECT_NAME deployed successfully!${NC}"
echo -e "${YELLOW}Access your project at: https://$PROJECT_NAME.cryptotel.xyz${NC}" 