#!/bin/bash
set -e

# OpenClaw Ansible Installer
# This script installs Ansible if needed and runs the OpenClaw playbook via Ansible Galaxy

# Enable 256 colors
export TERM=xterm-256color

# Force color support
if [ -z "$COLORTERM" ]; then
    export COLORTERM=truecolor
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   OpenClaw Ansible Installer           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Detect operating system
PKG_INSTALL=""
if command -v apt-get &> /dev/null; then
    echo -e "${GREEN}✓ Detected: Debian/Ubuntu Linux${NC}"
    PKG_INSTALL="apt"
elif command -v dnf &> /dev/null; then
    echo -e "${GREEN}✓ Detected: Fedora/RHEL-family Linux${NC}"
    PKG_INSTALL="dnf"
elif command -v yum &> /dev/null; then
    echo -e "${GREEN}✓ Detected: RHEL-family Linux${NC}"
    PKG_INSTALL="yum"
else
    echo -e "${RED}✗ Error: Unsupported operating system${NC}"
    echo -e "${RED}  This installer supports: Debian/Ubuntu, Fedora, and RHEL-family Linux${NC}"
    exit 1
fi

# Check if running as root or with sudo access
if [ "$EUID" -eq 0 ]; then
    echo -e "${GREEN}Running as root.${NC}"
    SUDO=""
    ANSIBLE_EXTRA_VARS="-e ansible_become=false"
else
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}Error: sudo is not installed. Please install sudo or run as root.${NC}"
        exit 1
    fi
    SUDO="sudo"
    ANSIBLE_EXTRA_VARS="--ask-become-pass"
fi

echo -e "${GREEN}[1/3] Checking prerequisites...${NC}"

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${YELLOW}Ansible not found. Installing Ansible and git...${NC}"
    if [ "$PKG_INSTALL" = "apt" ]; then
        $SUDO apt-get update -qq
        $SUDO apt-get install -y ansible git
    else
        $SUDO $PKG_INSTALL install -y ansible-core git
    fi
    echo -e "${GREEN}✓ Ansible and git installed${NC}"
else
    echo -e "${GREEN}✓ Ansible already installed${NC}"
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}git not found. Installing...${NC}"
        if [ "$PKG_INSTALL" = "apt" ]; then
            $SUDO apt-get update -qq
            $SUDO apt-get install -y git
        else
            $SUDO $PKG_INSTALL install -y git
        fi
        echo -e "${GREEN}✓ git installed${NC}"
    else
        echo -e "${GREEN}✓ git already installed${NC}"
    fi
fi

echo -e "${GREEN}[2/3] Installing OpenClaw collection...${NC}"

# Create temporary requirements file
REQUIREMENTS_FILE=$(mktemp)
cat > "$REQUIREMENTS_FILE" << EOF
---
collections:
  - name: https://github.com/openclaw/openclaw-ansible.git
    type: git
    version: main
EOF

# Install collection
ansible-galaxy collection install -r "$REQUIREMENTS_FILE" --force

echo -e "${GREEN}✓ Collection installed${NC}"

echo -e "${GREEN}[3/3] Running Ansible playbook...${NC}"
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}You will be prompted for your sudo password.${NC}"
fi
echo ""

# Run the playbook
ansible-playbook openclaw.installer.install $ANSIBLE_EXTRA_VARS "$@"

# Cleanup
rm -f "$REQUIREMENTS_FILE"
