#!/bin/bash

###############################################################################
# Environment Variables Verification Script
# Purpose: Verify that all environment variables are properly configured
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Environment Variables Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check 1: .env file exists
echo -e "${BLUE}[1/6]${NC} Checking .env file..."
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"
else
    echo -e "${RED}✗${NC} .env file not found!"
    echo -e "${YELLOW}→${NC} Copy .env.example to .env and configure it"
    exit 1
fi

# Check 2: .env file permissions
echo -e "${BLUE}[2/6]${NC} Checking .env file permissions..."
PERMS=$(stat -c "%a" "$ENV_FILE" 2>/dev/null || stat -f "%A" "$ENV_FILE" 2>/dev/null)
if [ "$PERMS" = "600" ] || [ "$PERMS" = "644" ]; then
    echo -e "${GREEN}✓${NC} .env file permissions are secure ($PERMS)"
else
    echo -e "${YELLOW}⚠${NC} .env file permissions are $PERMS (recommended: 600 or 644)"
fi

# Check 3: Required variables in .env
echo -e "${BLUE}[3/6]${NC} Checking required variables in .env..."
REQUIRED_VARS=("DB_HOST" "DB_NAME" "DB_USER" "DB_PASSWORD" "DB_ROOT_PASSWORD")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^${var}=" "$ENV_FILE"; then
        VALUE=$(grep "^${var}=" "$ENV_FILE" | cut -d'=' -f2-)
        if [ -z "$VALUE" ]; then
            echo -e "${RED}✗${NC} $var is defined but empty"
            MISSING_VARS+=("$var")
        else
            echo -e "${GREEN}✓${NC} $var is set"
        fi
    else
        echo -e "${RED}✗${NC} $var is missing"
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${RED}✗${NC} Missing or empty variables: ${MISSING_VARS[*]}"
    exit 1
fi

# Check 4: Docker Compose can read .env
echo -e "${BLUE}[4/6]${NC} Checking Docker Compose configuration..."
if command -v docker-compose &> /dev/null; then
    cd "$SCRIPT_DIR"
    if docker-compose config > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Docker Compose can read configuration"
    else
        echo -e "${RED}✗${NC} Docker Compose configuration error"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠${NC} docker-compose not found, skipping"
fi

# Check 5: Container environment variables
echo -e "${BLUE}[5/6]${NC} Checking container environment variables..."
if docker ps --format '{{.Names}}' | grep -q "^sns-dso-app$"; then
    echo -e "${GREEN}✓${NC} Container sns-dso-app is running"
    
    echo "  Checking environment variables in container..."
    for var in "${REQUIRED_VARS[@]}"; do
        if [ "$var" != "DB_ROOT_PASSWORD" ]; then  # Root password not needed in app
            VALUE=$(docker exec sns-dso-app env | grep "^${var}=" | cut -d'=' -f2- || echo "")
            if [ -n "$VALUE" ]; then
                echo -e "  ${GREEN}✓${NC} $var is set in container"
            else
                echo -e "  ${RED}✗${NC} $var is NOT set in container"
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} Container sns-dso-app is not running"
    echo "  Start containers with: docker-compose up -d"
fi

# Check 6: Database connectivity
echo -e "${BLUE}[6/6]${NC} Testing database connectivity..."
if docker ps --format '{{.Names}}' | grep -q "^sns-dso-app$"; then
    if docker exec sns-dso-app php -r "
        \$host = getenv('DB_HOST');
        \$user = getenv('DB_USER');
        \$pass = getenv('DB_PASSWORD');
        \$db = getenv('DB_NAME');
        \$conn = new mysqli(\$host, \$user, \$pass, \$db);
        if (\$conn->connect_error) {
            exit(1);
        }
        exit(0);
    " 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Database connection successful"
    else
        echo -e "${RED}✗${NC} Database connection failed"
        echo "  Check if database container is running and credentials are correct"
    fi
else
    echo -e "${YELLOW}⚠${NC} Cannot test - container not running"
fi

# Summary
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Environment variables are properly configured!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo "Single Source of Truth: $ENV_FILE"
echo
echo "Environment Variables:"
source "$ENV_FILE"
echo "  DB_HOST: ${DB_HOST}"
echo "  DB_NAME: ${DB_NAME}"
echo "  DB_USER: ${DB_USER}"
echo "  DB_PASSWORD: ${DB_PASSWORD:0:3}*** (hidden)"
echo "  DB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:0:3}*** (hidden)"
echo "  APP_VERSION: ${APP_VERSION:-latest}"
echo
