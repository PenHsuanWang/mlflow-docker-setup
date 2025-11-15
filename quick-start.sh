#!/bin/bash
# Quick start script for MLflow Platform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$SCRIPT_DIR/platform"
COMPOSE_DIR="$PLATFORM_DIR/compose"
ENV_DIR="$PLATFORM_DIR/env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         MLflow Platform - Quick Start                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose v2 is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"
echo ""

# Menu
echo "Select deployment mode:"
echo "  1) Development (direct access, host ports exposed)"
echo "  2) Development with Proxy (NGINX auth, recommended)"
echo "  3) Production (requires .env.local configuration)"
echo "  4) Stop all services"
echo "  5) Clean up (remove containers and volumes)"
echo ""
read -p "Enter choice [1-5]: " choice

case $choice in
    1)
        echo -e "${YELLOW}Starting Development Mode (Direct Access)...${NC}"
        cd "$COMPOSE_DIR"
        docker compose -f docker-compose.core.yml -f docker-compose.dev.override.yml \
            --env-file ../env/dev.env up -d
        
        echo ""
        echo -e "${GREEN}✓ Services started!${NC}"
        echo ""
        echo "Access MLflow UI at: http://localhost:5011"
        echo "MySQL port: 3316"
        echo "Artifact server port: 5500"
        echo ""
        echo "To view logs: cd platform/compose && docker compose -f docker-compose.core.yml logs -f"
        ;;
    
    2)
        echo -e "${YELLOW}Starting Development Mode with Proxy...${NC}"
        cd "$COMPOSE_DIR"
        docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
            --env-file ../env/dev.env --profile proxy up -d
        
        echo ""
        echo -e "${GREEN}✓ Services started!${NC}"
        echo ""
        echo "Access MLflow UI at: http://localhost:7777"
        echo "Username: admin"
        echo "Password: admin123"
        echo ""
        echo "Direct access (bypass proxy): http://localhost:5011"
        echo ""
        echo "To view logs: cd platform/compose && docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml logs -f"
        ;;
    
    3)
        if [ ! -f "$ENV_DIR/.env.local" ]; then
            echo -e "${RED}Error: Production requires $ENV_DIR/.env.local${NC}"
            echo ""
            echo "Create it by copying and editing:"
            echo "  cp $ENV_DIR/prod.env $ENV_DIR/.env.local"
            echo "  # Edit .env.local with production credentials"
            exit 1
        fi
        
        echo -e "${YELLOW}Starting Production Mode...${NC}"
        echo -e "${RED}Warning: Ensure you've configured strong passwords in .env.local${NC}"
        read -p "Continue? (y/N): " confirm
        
        if [[ $confirm == [yY] ]]; then
            cd "$COMPOSE_DIR"
            docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
                --env-file ../env/.env.local --profile proxy up -d
            
            echo ""
            echo -e "${GREEN}✓ Services started!${NC}"
            echo ""
            echo "Access MLflow UI at: http://localhost:7777"
            echo "Use credentials from .env.local"
            echo ""
            echo "To enable HTTPS, see: platform/services/proxy/certs/README.md"
        else
            echo "Cancelled."
        fi
        ;;
    
    4)
        echo -e "${YELLOW}Stopping all services...${NC}"
        cd "$COMPOSE_DIR"
        
        # Try to stop with different configurations
        docker compose -f docker-compose.core.yml down 2>/dev/null || true
        docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml --profile proxy down 2>/dev/null || true
        
        echo -e "${GREEN}✓ Services stopped${NC}"
        ;;
    
    5)
        echo -e "${RED}Warning: This will remove all containers and volumes (data will be lost!)${NC}"
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        
        if [[ $confirm == "yes" ]]; then
            echo -e "${YELLOW}Cleaning up...${NC}"
            cd "$COMPOSE_DIR"
            
            docker compose -f docker-compose.core.yml down -v 2>/dev/null || true
            docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml --profile proxy down -v 2>/dev/null || true
            
            # Clean up dev volumes if they exist
            rm -rf "$PLATFORM_DIR/volumes"/*
            
            echo -e "${GREEN}✓ Cleanup complete${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "For more information, see: platform/README.md"
