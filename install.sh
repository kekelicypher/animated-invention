#!/usr/bin/env bash

# Install script for Mentor CLI
# This script will install mentor.sh system-wide as 'mentor'

set -e

# Define installation path
INSTALL_DIR="/usr/local/bin"
INSTALL_NAME="mentor"
SCRIPT_SOURCE="mentor.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Mentor CLI...${NC}"

# Check for dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
MISSING_DEPS=()
for cmd in jq glow gum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}Error: The following dependencies are missing: ${MISSING_DEPS[*]}${NC}"
    echo -e "Please install them before running mentor."
    # We continue with installation anyway, as the user might install them later
fi

# Check if script exists in current directory
if [ ! -f "$SCRIPT_SOURCE" ]; then
    echo -e "${RED}Error: $SCRIPT_SOURCE not found in the current directory.${NC}"
    exit 1
fi

# Use sudo if not root and installing to a system directory
SUDO=""
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
    echo -e "${YELLOW}Requesting administrative privileges to install to $INSTALL_DIR...${NC}"
fi

# Copy the script to the installation directory
echo -e "${YELLOW}Copying $SCRIPT_SOURCE to $INSTALL_DIR/$INSTALL_NAME...${NC}"
$SUDO cp "$SCRIPT_SOURCE" "$INSTALL_DIR/$INSTALL_NAME"

# Make the script executable
echo -e "${YELLOW}Making $INSTALL_NAME executable...${NC}"
$SUDO chmod +x "$INSTALL_DIR/$INSTALL_NAME"

echo -e "${GREEN}Installation complete!${NC}"
echo -e "You can now run mentor by typing '${INSTALL_NAME}' in your terminal."

# Remind user about API key
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "\n${YELLOW}Reminder:${NC} You need to set the GEMINI_API_KEY environment variable."
    echo -e "Add this to your shell profile (e.g., .bashrc or .zshrc):"
    echo -e "  export GEMINI_API_KEY='your_api_key_here'"
fi
