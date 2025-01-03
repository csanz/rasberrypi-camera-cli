#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for config files and create them if they don't exist
if [ ! -f "config_deploy.env" ]; then
    echo -e "${YELLOW}config_deploy.env not found. Creating from template...${NC}"
    if [ -f "config_deploy.env-template" ]; then
        cp config_deploy.env-template config_deploy.env
        echo -e "${YELLOW}Please edit config_deploy.env with your settings before continuing.${NC}"
        exit 1
    else
        echo -e "${RED}Error: config_deploy.env-template not found!${NC}"
        exit 1
    fi
fi

if [ ! -f "config_app.env" ]; then
    echo -e "${YELLOW}config_app.env not found. Creating from template...${NC}"
    if [ -f "config_app.env-template" ]; then
        cp config_app.env-template config_app.env
    else
        echo -e "${RED}Error: config_app.env-template not found!${NC}"
        exit 1
    fi
fi

# Load deployment configuration
export $(cat config_deploy.env | grep -v '#' | xargs)

# Default Target Raspberry Pi details
PI_USER="pi"
PI_HOST="raspberrypi.local"
DEFAULT_BASE_DIR="/home/pi"

echo -e "${YELLOW}Raspberry Pi Connection Setup${NC}"
read -p "Enter Raspberry Pi username (default: pi): " input_user
PI_USER=${input_user:-$PI_USER}

read -p "Enter Raspberry Pi hostname/IP (default: raspberrypi.local): " input_host
PI_HOST=${input_host:-$PI_HOST}

# Check SSH connection
echo "Testing SSH connection..."
if ! ssh -q ${PI_USER}@${PI_HOST} exit; then
    echo -e "${RED}Failed to connect to Raspberry Pi!${NC}"
    echo "Please check:"
    echo "1. SSH is enabled on your Raspberry Pi"
    echo "2. The hostname/IP is correct"
    echo "3. The username is correct"
    exit 1
fi

# Check and prompt for installation directory
echo "Checking available home directories..."
AVAILABLE_DIRS=$(ssh ${PI_USER}@${PI_HOST} "ls -d /home/*/")
echo -e "${YELLOW}Available home directories:${NC}"
echo "$AVAILABLE_DIRS"

read -p "Enter base installation directory (default: $DEFAULT_BASE_DIR): " input_base_dir
BASE_DIR=${input_base_dir:-$DEFAULT_BASE_DIR}

# Verify the directory exists or create it
if ! ssh ${PI_USER}@${PI_HOST} "[ -d ${BASE_DIR} ]"; then
    echo -e "${YELLOW}Directory ${BASE_DIR} does not exist.${NC}"
    read -p "Would you like to create it? (y/n): " create_dir
    if [[ $create_dir =~ ^[Yy]$ ]]; then
        ssh ${PI_USER}@${PI_HOST} "sudo mkdir -p ${BASE_DIR} && sudo chown ${PI_USER}:${PI_USER} ${BASE_DIR}"
    else
        echo -e "${RED}Installation cancelled.${NC}"
        exit 1
    fi
fi

INSTALL_DIR="${BASE_DIR}/camera-cli"

echo -e "${GREEN}Deploying camera-cli to Raspberry Pi...${NC}"
echo "Installation directory: ${INSTALL_DIR}"

# Create directory structure on Raspberry Pi
ssh ${PI_USER}@${PI_HOST} "mkdir -p ${INSTALL_DIR}/src"

# Copy files to Raspberry Pi
echo "Copying files..."
scp -r src/camera.py ${PI_USER}@${PI_HOST}:${INSTALL_DIR}/src/
scp config.env ${PI_USER}@${PI_HOST}:${INSTALL_DIR}/
scp setup.py ${PI_USER}@${PI_HOST}:${INSTALL_DIR}/
scp requirements.txt ${PI_USER}@${PI_HOST}:${INSTALL_DIR}/

# Install dependencies and set up the tool
echo "Installing dependencies and setting up the tool..."
ssh ${PI_USER}@${PI_HOST} "cd ${INSTALL_DIR} && \
    sudo apt-get update && \
    sudo apt-get install -y python3-picamera2 libcamera-tools && \
    python3 -m pip install --user -r requirements.txt && \
    python3 -m pip install --user -e ."

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Deployment successful!${NC}"
    echo -e "${YELLOW}Usage examples:${NC}"
    echo "  camera --take-photo photo.jpg"
    echo "  camera --take-video video.mp4 --duration 30"
    
    # Add to .bashrc if not already added
    echo "Updating PATH in .bashrc..."
    ssh ${PI_USER}@${PI_HOST} "grep -qxF 'export PATH=\$PATH:\$HOME/.local/bin' \$HOME/.bashrc || echo 'export PATH=\$PATH:\$HOME/.local/bin' >> \$HOME/.bashrc"
    echo -e "${YELLOW}Note: You may need to log out and log back in or run 'source ~/.bashrc' for the command to be available${NC}"
else
    echo -e "${RED}Deployment failed!${NC}"
    exit 1
fi
