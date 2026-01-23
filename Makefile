# Makefile for kubectl-resource-stats plugin testing
# Provides targets for running tests using local k3d cluster

.PHONY: help test test-setup test-cleanup test-demo install install-user uninstall

# Detect OS
UNAME_S := $(shell uname -s 2>/dev/null || echo "Unknown")
PLUGIN_SOURCE := scripts/kubectl-resource-stats
PLUGIN_NAME := kubectl-resource-stats

# Default target
help:
	@echo "Available targets:"
	@echo "  install       - Install plugin system-wide (requires sudo on Linux/macOS)"
	@echo "  install-user  - Install plugin to user directory (~/bin)"
	@echo "  uninstall     - Remove installed plugin"
	@echo "  test          - Setup cluster and run all tests"
	@echo "  test-setup    - Setup k3d test cluster"
	@echo "  test-cleanup  - Cleanup k3d test cluster"
	@echo "  test-demo     - Setup cluster and record demo"

# Install BATS helper libraries (optional but recommended)
test-install-helpers:
	@echo "Installing BATS helper libraries (if needed)..."
	@if [ -f "tests/test_helper/install-bats-helpers.sh" ]; then \
		./tests/test_helper/install-bats-helpers.sh || echo "Warning: Could not install BATS helpers (tests will use fallback functions)"; \
	else \
		echo "BATS helpers installer not found, tests will use fallback functions..."; \
	fi

# Run all tests (setup cluster first, then run tests)
test: test-setup test-install-helpers
	@echo "Running BATS tests..."
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "Error: bats is not installed."; \
		echo ""; \
		echo "BATS (Bash Automated Testing System) is a testing framework for bash scripts."; \
		echo "Install with:"; \
		echo "  macOS:   brew install bats-core"; \
		echo "  Linux:   sudo apt-get install bats  (Debian/Ubuntu)"; \
		echo "           or install from source: https://github.com/bats-core/bats-core"; \
		echo ""; \
		echo "Note: On macOS, the package is called 'bats-core' but the command is 'bats'"; \
		exit 1; \
	fi
	@cd tests && bats kubectl-resource-stats.bats
	@echo "Tests completed"

# Setup test cluster locally using k3d
test-setup:
	@echo "Setting up test cluster locally..."
	@if ! command -v k3d >/dev/null 2>&1; then \
		echo "Error: k3d is not installed"; \
		echo "Install with: brew install k3d (macOS) or curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash (Linux)"; \
		exit 1; \
	fi
	@if ! command -v kubectl >/dev/null 2>&1; then \
		echo "Error: kubectl is not installed"; \
		exit 1; \
	fi
	@if ! docker info >/dev/null 2>&1; then \
		echo "Error: Docker is not running"; \
		exit 1; \
	fi
	@CLUSTER_NAME=test-cluster ./scripts/setup-k3d-cluster.sh
	@echo "Cluster setup complete. Context: k3d-test-cluster"

# Cleanup test cluster locally
test-cleanup:
	@echo "Cleaning up test cluster locally..."
	@if command -v k3d >/dev/null 2>&1; then \
		k3d cluster delete test-cluster 2>/dev/null || true; \
		echo "Cluster deleted"; \
	else \
		echo "Warning: k3d not found, skipping cluster deletion"; \
	fi

# Setup cluster and record demo
test-demo: test-setup
	@echo "Recording demo..."
	@if ! command -v asciinema >/dev/null 2>&1; then \
		echo "Error: asciinema is not installed"; \
		echo "Install with: brew install asciinema (macOS) or pip install asciinema (Linux)"; \
		exit 1; \
	fi
	@./scripts/record-demo.sh

# Install plugin system-wide (requires sudo on Linux/macOS)
install:
	@echo "Installing kubectl-resource-stats plugin..."
	@if [ ! -f "$(PLUGIN_SOURCE)" ]; then \
		echo "Error: Plugin source not found: $(PLUGIN_SOURCE)"; \
		exit 1; \
	fi
	@if [ "$(UNAME_S)" = "Linux" ]; then \
		echo "Installing to /usr/local/bin (Linux)..."; \
		sudo cp "$(PLUGIN_SOURCE)" /usr/local/bin/$(PLUGIN_NAME); \
		sudo chmod +x /usr/local/bin/$(PLUGIN_NAME); \
		echo "✓ Plugin installed to /usr/local/bin/$(PLUGIN_NAME)"; \
		echo ""; \
		echo "Verify installation:"; \
		echo "  kubectl plugin list"; \
		echo "  kubectl resource stats help"; \
	elif [ "$(UNAME_S)" = "Darwin" ]; then \
		echo "Installing to /usr/local/bin (macOS)..."; \
		sudo cp "$(PLUGIN_SOURCE)" /usr/local/bin/$(PLUGIN_NAME); \
		sudo chmod +x /usr/local/bin/$(PLUGIN_NAME); \
		echo "✓ Plugin installed to /usr/local/bin/$(PLUGIN_NAME)"; \
		echo ""; \
		echo "Verify installation:"; \
		echo "  kubectl plugin list"; \
		echo "  kubectl resource stats help"; \
	elif [ "$(UNAME_S)" = "MINGW64_NT" ] || [ "$(UNAME_S)" = "MSYS_NT" ] || [ "$(UNAME_S)" = "CYGWIN_NT" ]; then \
		echo "Installing for Windows (Git Bash/Cygwin)..."; \
		INSTALL_DIR="$$HOME/bin"; \
		mkdir -p "$$INSTALL_DIR"; \
		cp "$(PLUGIN_SOURCE)" "$$INSTALL_DIR/$(PLUGIN_NAME)"; \
		chmod +x "$$INSTALL_DIR/$(PLUGIN_NAME)"; \
		echo "✓ Plugin installed to $$INSTALL_DIR/$(PLUGIN_NAME)"; \
		echo ""; \
		echo "Add to PATH (add to ~/.bashrc or ~/.zshrc):"; \
		echo "  export PATH=\"\$$HOME/bin:\$$PATH\""; \
		echo ""; \
		echo "For Windows CMD/PowerShell, install to a directory in your PATH"; \
		echo "or add the plugin directory to your PATH environment variable."; \
	else \
		echo "Error: Unsupported operating system: $(UNAME_S)"; \
		echo "Please install manually:"; \
		echo "  1. Copy $(PLUGIN_SOURCE) to a directory in your PATH"; \
		echo "  2. Make it executable: chmod +x <destination>"; \
		exit 1; \
	fi

# Install plugin to user directory (no sudo required)
install-user:
	@echo "Installing kubectl-resource-stats plugin to user directory..."
	@if [ ! -f "$(PLUGIN_SOURCE)" ]; then \
		echo "Error: Plugin source not found: $(PLUGIN_SOURCE)"; \
		exit 1; \
	fi
	@USER_BIN_DIR="$$HOME/bin"; \
	mkdir -p "$$USER_BIN_DIR"; \
	cp "$(PLUGIN_SOURCE)" "$$USER_BIN_DIR/$(PLUGIN_NAME)"; \
	chmod +x "$$USER_BIN_DIR/$(PLUGIN_NAME)"; \
	echo "✓ Plugin installed to $$USER_BIN_DIR/$(PLUGIN_NAME)"; \
	echo ""; \
	if ! echo "$$PATH" | grep -q "$$USER_BIN_DIR"; then \
		echo "⚠ Warning: $$USER_BIN_DIR is not in your PATH"; \
		echo ""; \
		if [ -f "$$HOME/.bashrc" ]; then \
			echo "Add to ~/.bashrc:"; \
			echo "  export PATH=\"\$$HOME/bin:\$$PATH\""; \
		elif [ -f "$$HOME/.zshrc" ]; then \
			echo "Add to ~/.zshrc:"; \
			echo "  export PATH=\"\$$HOME/bin:\$$PATH\""; \
		fi; \
		echo ""; \
		echo "Then reload your shell:"; \
		echo "  source ~/.bashrc  # or source ~/.zshrc"; \
	fi; \
	echo ""; \
	echo "Verify installation:"; \
	echo "  kubectl plugin list"; \
	echo "  kubectl resource stats help"

# Uninstall plugin
uninstall:
	@echo "Uninstalling kubectl-resource-stats plugin..."
	@if [ "$(UNAME_S)" = "Linux" ] || [ "$(UNAME_S)" = "Darwin" ]; then \
		if [ -f "/usr/local/bin/$(PLUGIN_NAME)" ]; then \
			sudo rm -f /usr/local/bin/$(PLUGIN_NAME); \
			echo "✓ Plugin removed from /usr/local/bin/$(PLUGIN_NAME)"; \
		else \
			echo "Plugin not found in /usr/local/bin"; \
		fi; \
		if [ -f "$$HOME/bin/$(PLUGIN_NAME)" ]; then \
			rm -f "$$HOME/bin/$(PLUGIN_NAME)"; \
			echo "✓ Plugin removed from $$HOME/bin/$(PLUGIN_NAME)"; \
		fi; \
	elif [ "$(UNAME_S)" = "MINGW64_NT" ] || [ "$(UNAME_S)" = "MSYS_NT" ] || [ "$(UNAME_S)" = "CYGWIN_NT" ]; then \
		if [ -f "$$HOME/bin/$(PLUGIN_NAME)" ]; then \
			rm -f "$$HOME/bin/$(PLUGIN_NAME)"; \
			echo "✓ Plugin removed from $$HOME/bin/$(PLUGIN_NAME)"; \
		else \
			echo "Plugin not found in $$HOME/bin"; \
		fi; \
	else \
		echo "Please remove the plugin manually from your PATH directories"; \
	fi
