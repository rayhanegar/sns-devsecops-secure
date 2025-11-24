#!/bin/bash

# Script to switch between vulnerable and secured versions of the application
# by changing the 'src' symbolic link

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_LINK="${SCRIPT_DIR}/src"
VULNERABLE_SRC="/home/dso505/twitah-devsecops/src"
SECURED_SRC="/home/dso505/twitah-devsecops-secured/src"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [--vulnerable|--secured]"
    echo ""
    echo "Options:"
    echo "  --vulnerable    Switch to the vulnerable version"
    echo "  --secured       Switch to the secured version"
    echo ""
    echo "Examples:"
    echo "  $0 --vulnerable"
    echo "  $0 --secured"
    exit 1
}

# Function to check if Docker containers are running
check_containers() {
    if docker ps --format '{{.Names}}' | grep -qE 'sns-dso-(app|web)'; then
        return 0  # Containers are running
    else
        return 1  # No containers running
    fi
}

# Function to restart Docker containers
restart_containers() {
    echo -e "${YELLOW}Restarting affected Docker containers...${NC}"
    cd "${SCRIPT_DIR}"
    
    # Check which containers are running and restart only app and web
    local containers_to_restart=()
    
    if docker ps --format '{{.Names}}' | grep -q 'sns-dso-app'; then
        containers_to_restart+=("sns-dso-app")
    fi
    
    if docker ps --format '{{.Names}}' | grep -q 'sns-dso-web'; then
        containers_to_restart+=("web")
    fi
    
    if [ ${#containers_to_restart[@]} -gt 0 ]; then
        echo "Restarting containers: ${containers_to_restart[*]}"
        docker compose restart "${containers_to_restart[@]}"
        echo -e "${GREEN}✓ Docker containers restarted successfully${NC}"
    else
        echo -e "${YELLOW}⚠ No running containers found. Start them with: docker compose up -d${NC}"
    fi
}

# Function to switch to a version
switch_version() {
    local target_src=$1
    local version_name=$2
    
    # Verify target directory exists
    if [ ! -d "${target_src}" ]; then
        echo -e "${RED}Error: Target directory '${target_src}' does not exist${NC}"
        exit 1
    fi
    
    # Check current symlink
    if [ -L "${SRC_LINK}" ]; then
        current_target=$(readlink -f "${SRC_LINK}")
        target_full=$(readlink -f "${target_src}")
        
        if [ "${current_target}" = "${target_full}" ]; then
            echo -e "${YELLOW}Already using ${version_name} version (${target_src})${NC}"
            exit 0
        fi
        
        echo -e "${YELLOW}Current version: ${current_target}${NC}"
    fi
    
    # Remove existing symlink or directory
    if [ -L "${SRC_LINK}" ]; then
        echo "Removing existing symlink..."
        rm "${SRC_LINK}"
    elif [ -e "${SRC_LINK}" ]; then
        echo -e "${RED}Error: '${SRC_LINK}' exists but is not a symlink${NC}"
        exit 1
    fi
    
    # Create new symlink
    echo "Creating symlink to ${version_name} version..."
    ln -s "${target_src}" "${SRC_LINK}"
    
    # Verify symlink was created successfully
    if [ -L "${SRC_LINK}" ]; then
        new_target=$(readlink -f "${SRC_LINK}")
        echo -e "${GREEN}✓ Successfully switched to ${version_name} version${NC}"
        echo -e "${GREEN}  Symlink: ${SRC_LINK} -> ${target_src}${NC}"
        
        # Restart containers if they're running
        if check_containers; then
            restart_containers
        else
            echo -e "${YELLOW}⚠ No Docker containers are currently running${NC}"
            echo -e "${YELLOW}  Start them with: cd ${SCRIPT_DIR} && docker compose up -d${NC}"
        fi
    else
        echo -e "${RED}Error: Failed to create symlink${NC}"
        exit 1
    fi
}

# Main script logic
main() {
    if [ $# -eq 0 ]; then
        usage
    fi
    
    case "$1" in
        --vulnerable)
            switch_version "${VULNERABLE_SRC}" "vulnerable"
            ;;
        --secured)
            switch_version "${SECURED_SRC}" "secured"
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Invalid option '$1'${NC}"
            echo ""
            usage
            ;;
    esac
}

main "$@"
