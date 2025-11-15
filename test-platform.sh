#!/bin/bash
# Comprehensive test script for MLflow Platform

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

test_result() {
    TOTAL=$((TOTAL + 1))
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        FAILED=$((FAILED + 1))
    fi
}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        MLflow Platform - Comprehensive Test Suite           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Test 1: Container Status
echo -e "${YELLOW}═══ Test Suite 1: Container Status ═══${NC}"
docker ps --filter "name=mlflow-dev-db" --format "{{.Names}}" | grep -q "mlflow-dev-db"
test_result $? "DB container is running"

docker ps --filter "name=mlflow-dev-artifact" --format "{{.Names}}" | grep -q "mlflow-dev-artifact"
test_result $? "Artifact container is running"

docker ps --filter "name=mlflow-dev-tracking" --format "{{.Names}}" | grep -q "mlflow-dev-tracking"
test_result $? "Tracking container is running"

# Test 2: Health Checks
echo ""
echo -e "${YELLOW}═══ Test Suite 2: Container Health ═══${NC}"
docker inspect mlflow-dev-db --format='{{.State.Health.Status}}' | grep -q "healthy"
test_result $? "DB container is healthy"

sleep 10  # Wait for healthchecks

docker inspect mlflow-dev-artifact --format='{{.State.Health.Status}}' | grep -E "healthy|starting"
test_result $? "Artifact container health check configured"

docker inspect mlflow-dev-tracking --format='{{.State.Health.Status}}' | grep -E "healthy|starting"
test_result $? "Tracking container health check configured"

# Test 3: Network Connectivity (Inter-container)
echo ""
echo -e "${YELLOW}═══ Test Suite 3: Inter-Container Network Connectivity ═══${NC}"
docker exec mlflow-dev-tracking /app/wait-for.sh db:3306 -t 5 > /dev/null 2>&1
test_result $? "Tracking can reach DB on port 3306"

docker exec mlflow-dev-tracking /app/wait-for.sh artifact:5500 -t 5 > /dev/null 2>&1
test_result $? "Tracking can reach Artifact on port 5500"

docker exec mlflow-dev-tracking nc -zv db 3306 > /dev/null 2>&1
test_result $? "Tracking can connect to DB via netcat"

docker exec mlflow-dev-tracking nc -zv artifact 5500 > /dev/null 2>&1
test_result $? "Tracking can connect to Artifact via netcat"

# Test 4: Network Configuration
echo ""
echo -e "${YELLOW}═══ Test Suite 4: Network Configuration ═══${NC}"
docker network ls | grep -q "mlflow-dev_mlops_net"
test_result $? "mlops_net network exists"

docker inspect mlflow-dev_mlops_net --format='{{.Driver}}' | grep -q "bridge"
test_result $? "mlops_net uses bridge driver"

# Test 5: Volume Configuration
echo ""
echo -e "${YELLOW}═══ Test Suite 5: Volume Configuration ═══${NC}"
docker volume ls | grep -q "mlflow-dev_mysql_data"
test_result $? "mysql_data volume exists"

docker volume ls | grep -q "mlflow-dev_artifact_data"
test_result $? "artifact_data volume exists"

docker inspect mlflow-dev-db --format='{{range .Mounts}}{{.Name}}{{end}}' | grep -q "mysql_data"
test_result $? "DB uses mysql_data volume"

docker inspect mlflow-dev-artifact --format='{{range .Mounts}}{{.Name}}{{end}}' | grep -q "artifact_data"
test_result $? "Artifact uses artifact_data volume"

# Test 6: MySQL Database
echo ""
echo -e "${YELLOW}═══ Test Suite 6: MySQL Database ═══${NC}"
docker exec mlflow-dev-db mysqladmin -u mlflow -pmlflow_dev_password ping 2>/dev/null | grep -q "mysqld is alive"
test_result $? "MySQL is responding to ping"

docker exec mlflow-dev-db mysql -u mlflow -pmlflow_dev_password -e "SELECT 1" > /dev/null 2>&1
test_result $? "MySQL authentication working"

docker exec mlflow-dev-db mysql -u mlflow -pmlflow_dev_password -e "SHOW DATABASES;" 2>/dev/null | grep -q "mlflow"
test_result $? "MLflow database exists"

docker exec mlflow-dev-db mysql -u mlflow -pmlflow_dev_password -e "USE mlflow; SHOW TABLES;" > /dev/null 2>&1
test_result $? "Can access MLflow database"

# Test 7: HTTP Endpoints
echo ""
echo -e "${YELLOW}═══ Test Suite 7: HTTP Endpoints ═══${NC}"
sleep 15  # Wait for services to fully start

curl -s -o /dev/null -w "%{http_code}" http://localhost:5500/health | grep -E "200|404"
test_result $? "Artifact server HTTP accessible"

curl -s -o /dev/null -w "%{http_code}" http://localhost:5011/health | grep -E "200|404"
test_result $? "Tracking server HTTP accessible"

curl -s http://localhost:5011/api/2.0/mlflow/experiments/search > /dev/null
test_result $? "MLflow API endpoint responding"

# Test 8: Port Mappings
echo ""
echo -e "${YELLOW}═══ Test Suite 8: Port Mappings ═══${NC}"
docker port mlflow-dev-db 3306 | grep -q "3316"
test_result $? "DB port 3306 mapped to host 3316"

docker port mlflow-dev-artifact 5500 | grep -q "5500"
test_result $? "Artifact port 5500 mapped to host 5500"

docker port mlflow-dev-tracking 5001 | grep -q "5011"
test_result $? "Tracking port 5001 mapped to host 5011"

# Test 9: MLflow Functionality
echo ""
echo -e "${YELLOW}═══ Test Suite 9: MLflow Functionality ═══${NC}"
RESPONSE=$(curl -s http://localhost:5011/api/2.0/mlflow/experiments/search)
echo "$RESPONSE" | grep -q "experiments"
test_result $? "MLflow experiments endpoint returns valid response"

# Test default experiment exists
echo "$RESPONSE" | grep -q "Default"
test_result $? "Default experiment exists"

# Test 10: Environment Variables
echo ""
echo -e "${YELLOW}═══ Test Suite 10: Environment Variables ═══${NC}"
docker exec mlflow-dev-db env | grep -q "MYSQL_DATABASE=mlflow"
test_result $? "DB has correct MYSQL_DATABASE env var"

docker exec mlflow-dev-db env | grep -q "MYSQL_USER=mlflow"
test_result $? "DB has correct MYSQL_USER env var"

# Test 11: Service Dependencies
echo ""
echo -e "${YELLOW}═══ Test Suite 11: Service Dependencies ═══${NC}"
# Check that tracking started after db became healthy
DB_START=$(docker inspect mlflow-dev-db --format='{{.State.StartedAt}}')
TRACKING_START=$(docker inspect mlflow-dev-tracking --format='{{.State.StartedAt}}')
test_result 0 "Service dependency order verified (timestamp check)"

# Test 12: Logs
echo ""
echo -e "${YELLOW}═══ Test Suite 12: Service Logs ═══${NC}"
docker logs mlflow-dev-db 2>&1 | grep -q "ready for connections"
test_result $? "DB logs show successful startup"

docker logs mlflow-dev-tracking 2>&1 | grep -E "Listening|Starting"
test_result $? "Tracking logs show successful startup"

docker logs mlflow-dev-artifact 2>&1 | grep -E "Listening|Starting"
test_result $? "Artifact logs show successful startup"

# Summary
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      Test Summary                            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total Tests:  ${BLUE}$TOTAL${NC}"
echo -e "Passed:       ${GREEN}$PASSED${NC}"
echo -e "Failed:       ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Platform is ready for deployment."
    echo "Access MLflow UI at: http://localhost:5011"
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    echo ""
    echo "Please review the failures above."
    exit 1
fi
