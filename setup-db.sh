#!/bin/bash

###############################################################################
# SNS DevSecOps Database Setup Script
# Purpose: Initialize/Update database schema and verify connection
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yaml"

###############################################################################
# Functions
###############################################################################

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

###############################################################################
# Load Environment Variables
###############################################################################

load_env() {
    print_header "Loading Environment Configuration"
    
    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found at $ENV_FILE"
        print_info "Creating default .env file..."
        
        cat > "$ENV_FILE" << 'ENVEOF'
# Database Configuration
DB_HOST=sns-dso-db
DB_NAME=twita_db
DB_USER=sns_user
DB_PASSWORD=devsecops-admin
DB_ROOT_PASSWORD=devsecops-admin

# Application Configuration
APP_VERSION=latest
ENVEOF
        print_success ".env file created with default values"
    fi
    
    # Load environment variables
    export $(grep -v '^#' "$ENV_FILE" | xargs)
    
    print_success "Environment variables loaded"
    echo "  DB_HOST: ${DB_HOST:-sns-dso-db}"
    echo "  DB_NAME: ${DB_NAME:-twita_db}"
    echo "  DB_USER: ${DB_USER:-sns_user}"
}

###############################################################################
# Check Docker Containers
###############################################################################

check_containers() {
    print_header "Checking Docker Containers"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^sns-dso-db$"; then
        print_error "Database container 'sns-dso-db' is not running"
        print_info "Starting containers with docker-compose..."
        
        cd "$SCRIPT_DIR"
        docker-compose up -d sns-dso-db
        
        print_info "Waiting for database to be ready (30 seconds)..."
        sleep 30
    else
        print_success "Database container is running"
    fi
    
    if ! docker ps --format '{{.Names}}' | grep -q "^sns-dso-app$"; then
        print_warning "Application container 'sns-dso-app' is not running"
    else
        print_success "Application container is running"
    fi
}

###############################################################################
# Test Database Connection
###############################################################################

test_connection() {
    print_header "Testing Database Connection"
    
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec sns-dso-db mysql \
            -u"${DB_USER}" \
            -p"${DB_PASSWORD}" \
            -e "SELECT 1;" > /dev/null 2>&1; then
            print_success "Database connection successful"
            return 0
        fi
        
        print_warning "Connection attempt $attempt/$max_attempts failed"
        sleep 5
        ((attempt++))
    done
    
    print_error "Failed to connect to database after $max_attempts attempts"
    exit 1
}

###############################################################################
# Check Current Schema
###############################################################################

check_schema() {
    print_header "Checking Current Database Schema"
    
    echo "Current users table structure:"
    docker exec sns-dso-db mysql \
        -u"${DB_USER}" \
        -p"${DB_PASSWORD}" \
        "${DB_NAME}" \
        -e "DESCRIBE users;" 2>/dev/null | column -t
    
    echo -e "\nCurrent tweets table structure:"
    docker exec sns-dso-db mysql \
        -u"${DB_USER}" \
        -p"${DB_PASSWORD}" \
        "${DB_NAME}" \
        -e "DESCRIBE tweets;" 2>/dev/null | column -t
}

###############################################################################
# Apply Schema Updates
###############################################################################

apply_schema() {
    print_header "Applying Schema Updates"
    
    # Check if failed_attempts column exists
    local has_failed_attempts=$(docker exec sns-dso-db mysql \
        -u"${DB_USER}" \
        -p"${DB_PASSWORD}" \
        "${DB_NAME}" \
        -sN -e "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='${DB_NAME}' AND TABLE_NAME='users' AND COLUMN_NAME='failed_attempts';" 2>/dev/null)
    
    if [ "$has_failed_attempts" -eq "0" ]; then
        print_info "Adding missing columns for brute force protection..."
        
        docker exec sns-dso-db mysql \
            -u"${DB_USER}" \
            -p"${DB_PASSWORD}" \
            "${DB_NAME}" \
            -e "ALTER TABLE users 
                ADD COLUMN failed_attempts INT DEFAULT 0 AFTER role,
                ADD COLUMN last_attempt DATETIME DEFAULT NULL AFTER failed_attempts,
                ADD COLUMN locked_until DATETIME DEFAULT NULL AFTER last_attempt;" 2>/dev/null
        
        print_success "Schema updated successfully"
    else
        print_success "Schema is already up to date"
    fi
    
    # Add indexes for performance
    print_info "Creating indexes..."
    docker exec sns-dso-db mysql \
        -u"${DB_USER}" \
        -p"${DB_PASSWORD}" \
        "${DB_NAME}" << 'SQLEOF' 2>/dev/null || true
CREATE INDEX IF NOT EXISTS idx_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_locked_until ON users(locked_until);
CREATE INDEX IF NOT EXISTS idx_user_tweets ON tweets(user_id);
CREATE INDEX IF NOT EXISTS idx_created_at ON tweets(created_at);
SQLEOF
    
    print_success "Indexes created"
}

###############################################################################
# Verify Schema
###############################################################################

verify_schema() {
    print_header "Verifying Updated Schema"
    
    local required_columns=("failed_attempts" "last_attempt" "locked_until")
    local all_present=true
    
    for column in "${required_columns[@]}"; do
        local exists=$(docker exec sns-dso-db mysql \
            -u"${DB_USER}" \
            -p"${DB_PASSWORD}" \
            "${DB_NAME}" \
            -sN -e "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='${DB_NAME}' AND TABLE_NAME='users' AND COLUMN_NAME='$column';" 2>/dev/null)
        
        if [ "$exists" -eq "1" ]; then
            print_success "Column '$column' exists"
        else
            print_error "Column '$column' is missing"
            all_present=false
        fi
    done
    
    if [ "$all_present" = true ]; then
        print_success "All required columns are present"
    else
        print_error "Schema verification failed"
        exit 1
    fi
}

###############################################################################
# Display Summary
###############################################################################

display_summary() {
    print_header "Setup Summary"
    
    echo -e "${GREEN}Database setup completed successfully!${NC}\n"
    
    echo "Connection Details:"
    echo "  Host: ${DB_HOST}"
    echo "  Database: ${DB_NAME}"
    echo "  User: ${DB_USER}"
    echo "  Container: sns-dso-db"
    
    echo -e "\nTables:"
    echo "  - users (with brute force protection columns)"
    echo "  - tweets"
    
    echo -e "\nUseful Commands:"
    echo "  # Connect to database"
    echo "  docker exec -it sns-dso-db mysql -u${DB_USER} -p${DB_PASSWORD} ${DB_NAME}"
    
    echo -e "\n  # View logs"
    echo "  docker logs sns-dso-app --tail 50"
    
    echo -e "\n  # Restart application"
    echo "  docker-compose restart sns-dso-app"
}

###############################################################################
# Main Execution
###############################################################################

main() {
    echo -e "${BLUE}"
    cat << 'BANNER'
╔═══════════════════════════════════════════════════════════════╗
║         SNS DevSecOps - Database Setup Script                ║
╚═══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    
    load_env
    check_containers
    test_connection
    check_schema
    apply_schema
    verify_schema
    display_summary
}

# Run main function
main "$@"
