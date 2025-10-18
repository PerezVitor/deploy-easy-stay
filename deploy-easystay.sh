#!/bin/bash

# EasyStay Production Deployment Script
# This script deploys the EasyStay application using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.easystay.yml"
ENV_FILE=".env"

echo -e "${GREEN}🚀 Starting EasyStay Production Deployment (WSL Ubuntu)${NC}"

# Check if running in WSL
if [[ ! -f /proc/version ]] || ! grep -q Microsoft /proc/version; then
    echo -e "${YELLOW}⚠️  Warning: This script is optimized for WSL Ubuntu${NC}"
fi

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file $ENV_FILE not found!${NC}"
    echo -e "${YELLOW}📋 Please copy env.example to .env and configure your variables:${NC}"
    echo "cp env.example .env"
    echo "nano .env"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if Docker Compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}❌ Docker Compose file $COMPOSE_FILE not found!${NC}"
    exit 1
fi

# Pull latest images
echo -e "${YELLOW}📥 Pulling latest images...${NC}"
docker-compose -f $COMPOSE_FILE pull

# Stop existing containers
echo -e "${YELLOW}🛑 Stopping existing containers...${NC}"
docker-compose -f $COMPOSE_FILE down

# Remove old volumes (optional - uncomment if you want to reset data)
# echo -e "${YELLOW}🗑️ Removing old volumes...${NC}"
# docker-compose -f $COMPOSE_FILE down -v

# Start services
echo -e "${YELLOW}🚀 Starting services...${NC}"
docker-compose -f $COMPOSE_FILE up -d

# Wait for services to be healthy
echo -e "${YELLOW}⏳ Waiting for services to be healthy...${NC}"
sleep 30

# Check service status
echo -e "${BLUE}📊 Service Status:${NC}"
docker-compose -f $COMPOSE_FILE ps

# Show logs
echo -e "${BLUE}📋 Recent logs:${NC}"
docker-compose -f $COMPOSE_FILE logs --tail=50

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${YELLOW}📋 Useful commands:${NC}"
echo "• View logs: docker-compose -f $COMPOSE_FILE logs -f"
echo "• Stop services: docker-compose -f $COMPOSE_FILE down"
echo "• Restart services: docker-compose -f $COMPOSE_FILE restart"
echo "• View service status: docker-compose -f $COMPOSE_FILE ps"
echo "• Access backend: http://localhost:8000"
echo "• Access frontend: http://localhost:3001"
