#!/bin/bash

# Script to record asciinema demo of kubectl-resource-stats plugin
# This script sets up the environment and records the demo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEMO_SCRIPT="${SCRIPT_DIR}/demo.sh"
OUTPUT_FILE="${TASK_DIR}/kubectl-resource-stats-demo.cast"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Recording kubectl-resource-stats Plugin Demo ===${NC}"
echo ""

# Check if asciinema is installed
if ! command -v asciinema >/dev/null 2>&1; then
    echo -e "${RED}Error: asciinema is not installed${NC}"
    echo ""
    echo "Install asciinema:"
    echo "  macOS:   brew install asciinema"
    echo "  Linux:   pip install asciinema"
    echo "  Docker:  docker run -it --rm -v \$PWD:/data asciinema/asciinema rec /data/demo.cast"
    exit 1
fi

# Check if demo script exists
if [ ! -f "${DEMO_SCRIPT}" ]; then
    echo -e "${RED}Error: Demo script not found: ${DEMO_SCRIPT}${NC}"
    exit 1
fi

# Check if demo script is executable
if [ ! -x "${DEMO_SCRIPT}" ]; then
    echo -e "${YELLOW}Making demo script executable...${NC}"
    chmod +x "${DEMO_SCRIPT}"
fi

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v kubectl >/dev/null 2>&1; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v k3d >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: k3d is not installed${NC}"
    echo "k3d is recommended for the demo. Install with: brew install k3d"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if ! kubectl cluster-info &>/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Cannot access Kubernetes cluster${NC}"
    echo "Make sure you have a cluster running (k3d or other) and kubeconfig configured"
    echo "You can setup a k3d cluster with: make test-setup"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if ! command -v kubectl-resource-stats >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Plugin not found in PATH${NC}"
    echo "Installing plugin temporarily..."
    
    PLUGIN_SOURCE="${SCRIPT_DIR}/kubectl-resource-stats"
    if [ -f "${PLUGIN_SOURCE}" ]; then
        TEMP_PLUGIN="/tmp/kubectl-resource-stats"
        cp "${PLUGIN_SOURCE}" "${TEMP_PLUGIN}"
        chmod +x "${TEMP_PLUGIN}"
        export PATH="/tmp:${PATH}"
        echo -e "${GREEN}✓ Plugin installed temporarily${NC}"
    else
        echo -e "${RED}Error: Plugin script not found: ${PLUGIN_SOURCE}${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Prerequisites checked${NC}"
echo ""

# Record demo
echo -e "${BLUE}Starting asciinema recording...${NC}"
echo "Output file: ${OUTPUT_FILE}"
echo ""
echo -e "${YELLOW}Tip:${NC} The demo will run automatically."
echo -e "${YELLOW}Tip:${NC} Press Ctrl+C to stop recording early."
echo ""

# Record with asciinema
asciinema rec "${OUTPUT_FILE}" --command "${DEMO_SCRIPT}" --title "kubectl-resource-stats Plugin Demo" --command "bash -c '${DEMO_SCRIPT}'"

# Check if recording was successful
if [ $? -eq 0 ] && [ -f "${OUTPUT_FILE}" ]; then
    echo ""
    echo -e "${GREEN}✓ Demo recorded successfully!${NC}"
    echo ""
    echo "Recording saved to: ${OUTPUT_FILE}"
    echo ""
    echo "Next steps:"
    echo "  1. Upload to asciinema.org:"
    echo "     asciinema upload ${OUTPUT_FILE}"
    echo ""
    echo "  2. Or play locally:"
    echo "     asciinema play ${OUTPUT_FILE}"
    echo ""
    echo "  3. Embed in README.md:"
    echo "     [![asciicast](https://asciinema.org/a/YOUR_ID.svg)](https://asciinema.org/a/YOUR_ID)"
else
    echo ""
    echo -e "${RED}Error: Recording failed${NC}"
    exit 1
fi
