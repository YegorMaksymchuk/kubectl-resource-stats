#!/bin/bash

# Install BATS helper libraries
# This script downloads bats-support, bats-assert, and bats-file libraries

set -euo pipefail

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_bats_helper() {
    local repo=$1
    local name=$2
    local target_dir="${HELPER_DIR}/${name}"
    
    if [ -d "$target_dir" ]; then
        echo "BATS helper ${name} already installed"
        return 0
    fi
    
    echo "Installing BATS helper: ${name}"
    if git clone --depth 1 "https://github.com/bats-core/${repo}.git" "$target_dir" 2>/dev/null; then
        echo "✓ Installed ${name}"
    else
        echo "⚠ Failed to clone ${repo}, continuing without it"
        return 1
    fi
}

# Install helper libraries
echo "Installing BATS helper libraries..."
install_bats_helper "bats-support" "bats-support" || true
install_bats_helper "bats-assert" "bats-assert" || true
install_bats_helper "bats-file" "bats-file" || true

echo "BATS helpers installation complete"
