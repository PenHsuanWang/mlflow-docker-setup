#!/bin/bash
# Validation script for MLflow Platform

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   MLflow Platform - Configuration Validation              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$SCRIPT_DIR/platform"
ERRORS=0

# Check platform structure
echo "Checking directory structure..."
REQUIRED_DIRS=(
    "platform/compose"
    "platform/env"
    "platform/services/db"
    "platform/services/artifact"
    "platform/services/tracking"
    "platform/services/proxy"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$SCRIPT_DIR/$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir"
    else
        echo -e "${RED}✗${NC} $dir (missing)"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "Checking required files..."
REQUIRED_FILES=(
    "platform/compose/docker-compose.core.yml"
    "platform/compose/docker-compose.proxy.yml"
    "platform/env/dev.env"
    "platform/services/db/Dockerfile"
    "platform/services/artifact/Dockerfile"
    "platform/services/tracking/Dockerfile"
    "platform/services/proxy/Dockerfile"
    "quick-start.sh"
    "MIGRATION.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (missing)"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "Validating Docker Compose configurations..."

cd "$PLATFORM_DIR/compose"

# Validate core compose file
if docker-compose -f docker-compose.core.yml --env-file ../env/dev.env config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} docker-compose.core.yml is valid"
else
    echo -e "${RED}✗${NC} docker-compose.core.yml has errors"
    ERRORS=$((ERRORS + 1))
fi

# Validate proxy compose file
if docker-compose -f docker-compose.proxy.yml --env-file ../env/dev.env config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} docker-compose.proxy.yml is valid"
else
    echo -e "${RED}✗${NC} docker-compose.proxy.yml has errors"
    ERRORS=$((ERRORS + 1))
fi

# Validate combined configuration
if docker-compose -f docker-compose.core.yml -f docker-compose.proxy.yml --env-file ../env/dev.env config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Combined configuration is valid"
else
    echo -e "${RED}✗${NC} Combined configuration has errors"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Checking environment files..."

# Check for required variables in dev.env
REQUIRED_VARS=(
    "MYSQL_ROOT_PASSWORD"
    "MYSQL_PASSWORD"
    "MLFLOW_BACKEND_STORE_URI"
    "MLFLOW_ARTIFACT_ROOT"
    "MLFLOW_TRACKING_USERNAME"
    "MLFLOW_TRACKING_PASSWORD"
)

source "$PLATFORM_DIR/env/dev.env"

for var in "${REQUIRED_VARS[@]}"; do
    if [ -n "${!var}" ]; then
        echo -e "${GREEN}✓${NC} $var is set"
    else
        echo -e "${RED}✗${NC} $var is not set"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "Checking Docker prerequisites..."

if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓${NC} Docker is installed: $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} Docker is not installed"
    ERRORS=$((ERRORS + 1))
fi

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✓${NC} Docker Compose v2: $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo -e "${YELLOW}⚠${NC} Using docker-compose (legacy): $COMPOSE_VERSION"
    echo -e "${YELLOW}  ${NC} Consider upgrading to Docker Compose v2"
else
    echo -e "${RED}✗${NC} Docker Compose is not installed"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Platform is ready to deploy.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./quick-start.sh"
    echo "  2. Select deployment mode (1 or 2 recommended for first test)"
    echo "  3. Access MLflow UI and test"
    echo ""
    echo "For more information:"
    echo "  - platform/README.md - Operational guide"
    echo "  - MIGRATION.md - Upgrade from legacy"
    echo "  - IMPLEMENTATION_SUMMARY.md - What was built"
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s)${NC}"
    echo ""
    echo "Please fix the errors above before proceeding."
    exit 1
fi
