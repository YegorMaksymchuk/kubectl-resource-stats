# Testing Guide for kubectl-resource-stats Plugin

This directory contains the test suite for the kubectl-resource-stats plugin.

## Test Infrastructure

The testing infrastructure uses:
- **k3d** (Kubernetes in Docker) - For creating local Kubernetes clusters
- **BATS** (Bash Automated Testing System) - For writing and running tests
- **Local execution** - Tests run directly on your machine

## Prerequisites

Before running tests, ensure you have the following installed:

- **k3d** - Kubernetes in Docker
  ```bash
  # macOS
  brew install k3d
  
  # Linux
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  ```

- **kubectl** - Kubernetes command-line tool
  ```bash
  # macOS
  brew install kubectl
  
  # Linux
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  ```

- **BATS** - Bash Automated Testing System
  - **What is BATS?** BATS (Bash Automated Testing System) is a testing framework for bash scripts, similar to how pytest is for Python or Jest is for JavaScript.
  - **bats vs bats-core:** 
    - `bats-core` is the actively maintained fork of the original BATS project
    - The command is `bats` (regardless of which package you install)
    - On macOS, install via `brew install bats-core` (the package name is `bats-core` but the command is `bats`)
    - On Linux, the package might be called `bats` or `bats-core` depending on your distribution
  
  ```bash
  # macOS
  brew install bats-core
  
  # Linux (Debian/Ubuntu)
  sudo apt-get install bats
  
  # Linux (other distributions) - install from source
  git clone https://github.com/bats-core/bats-core.git
  cd bats-core
  ./install.sh /usr/local
  
  # Verify installation
  bats --version
  ```

- **Docker** - Required for k3d
  - Docker Desktop (macOS/Windows) or Docker Engine (Linux)
  - Must be running

- **kubectl-resource-stats plugin** - The plugin being tested
  - Should be in your PATH
  - Should be executable

## Quick Start

### Running Tests

The easiest way to run tests:

```bash
# Setup cluster and run all tests
make test

# Or step by step:
make test-setup    # Create k3d cluster
make test          # Run tests (will setup if needed)
make test-cleanup  # Delete cluster when done
```

This will:
1. Create a k3d Kubernetes cluster named `test-cluster`
2. Verify Metrics Server (k3d includes it by default)
3. Deploy test workloads
4. Run the BATS test suite
5. Clean up (optional, use `make test-cleanup`)

### Manual Test Execution

If you prefer to run tests manually:

```bash
# 1. Setup cluster
./scripts/setup-k3d-cluster.sh

# 2. Run tests
bats tests/kubectl-resource-stats.bats

# 3. Cleanup (optional)
k3d cluster delete test-cluster
```

## Test Structure

```
tests/
├── kubectl-resource-stats.bats    # Main test file
├── test_helper/                    # Test helper scripts
│   ├── setup-cluster.sh           # Cluster setup helper
│   ├── cleanup.sh                 # Cleanup helper
│   ├── bats-support/              # BATS support library (if installed)
│   ├── bats-assert/               # BATS assertion library (if installed)
│   └── bats-file/                 # BATS file library (if installed)
└── fixtures/                       # Test fixtures
    └── test-pods.yaml             # Sample pod manifests
```

## Test Categories

### 1. Basic Functionality Tests
- Help command (`help`, `--help`, `-h`)
- Plugin discovery (`kubectl plugin list`)
- Missing arguments handling
- Invalid format handling

### 2. Output Format Tests
- Table format (default)
- CSV format (`-o csv`)
- JSON format (`-o json`)
- Format validation

### 3. Resource Type Tests
- Full resource names (pods, deployments)
- Short resource names (po, deploy)
- Resource name normalization

### 4. Data Validation Tests
- Output structure validation
- Column presence verification
- JSON validity
- CSV format correctness

### 5. Integration Tests
- Real cluster interaction
- Metrics retrieval
- Empty results handling
- Error scenarios

## Writing New Tests

### Basic Test Structure

```bash
@test "test description" {
    run kubectl resource stats pods test-ns
    [ "$status" -eq 0 ]
    assert_output --partial "expected text"
}
```

### Using BATS Helpers

```bash
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "example test" {
    run kubectl resource stats pods test-ns -o json
    assert_success
    assert_output --partial "resource"
}
```

### Setup and Teardown

```bash
setup() {
    # Setup code runs before each test
    # KUBECONFIG is automatically set by k3d
}

teardown() {
    # Cleanup code runs after each test
    # Usually empty, cleanup handled by helpers
}
```

## Test Helpers

### setup-cluster.sh

Sets up test cluster resources:
- Creates test namespace
- Deploys test pods
- Deploys test deployments
- Verifies Metrics Server (k3d includes it)

Usage:
```bash
source tests/test_helper/setup-cluster.sh
```

### cleanup.sh

Cleans up test resources:
- Removes test pods
- Removes test deployments
- Optionally removes namespace

Usage:
```bash
source tests/test_helper/cleanup.sh
```

## Test Fixtures

Test fixtures are Kubernetes manifests used for testing:
- `test-pods.yaml` - Sample pods and deployments

Apply fixtures:
```bash
kubectl apply -f tests/fixtures/test-pods.yaml
```

## Makefile Targets

- `make test` - Setup cluster and run all tests
- `make test-setup` - Setup k3d cluster
- `make test-cleanup` - Delete k3d cluster
- `make test-demo` - Setup cluster and record demo

## Troubleshooting

### Tests Fail: Cluster Not Available

**Problem:** Tests skip with "Cluster not available"

**Solution:**
- Ensure k3d cluster is running: `k3d cluster list`
- Check kubeconfig: `kubectl cluster-info`
- Verify context: `kubectl config current-context` (should be `k3d-test-cluster`)
- Setup cluster: `make test-setup`

### Tests Fail: Metrics Server Not Ready

**Problem:** Tests fail because metrics are not available

**Solution:**
- k3d includes Metrics Server by default
- Wait for it: `kubectl wait --for=condition=available deployment/metrics-server -n kube-system`
- Check Metrics Server: `kubectl get deployment metrics-server -n kube-system`
- Verify it works: `kubectl top nodes`

### Tests Fail: Plugin Not Found

**Problem:** `kubectl plugin list` doesn't show plugin

**Solution:**
- Verify plugin is in PATH: `which kubectl-resource-stats`
- Check plugin permissions: `ls -l $(which kubectl-resource-stats)`
- Ensure plugin is executable: `chmod +x kubectl-resource-stats`

### k3d Cluster Creation Fails

**Problem:** `make test-setup` fails

**Solution:**
1. **Check Docker is running:**
   ```bash
   docker info
   ```

2. **Check k3d installation:**
   ```bash
   k3d --version
   ```

3. **Delete existing cluster and retry:**
   ```bash
   k3d cluster delete test-cluster
   make test-setup
   ```

4. **Check for port conflicts:**
   - k3d uses Docker, ensure no port conflicts

### BATS Not Found

**Problem:** `bats: command not found`

**Solution:**
- **What is BATS?** BATS (Bash Automated Testing System) is a testing framework for testing bash scripts. It's used to run the test suite for the kubectl-resource-stats plugin.
- **Installation:**
  ```bash
  # macOS (package name is bats-core, but command is bats)
  brew install bats-core
  
  # Linux (Debian/Ubuntu)
  sudo apt-get install bats
  
  # Linux (other distributions) - install from source
  git clone https://github.com/bats-core/bats-core.git
  cd bats-core
  ./install.sh /usr/local
  
  # Verify installation
  bats --version
  ```
  
- **Note:** On macOS, you install `bats-core` via Homebrew, but the command you run is `bats` (not `bats-core`). This is because the package name is `bats-core` but the binary is named `bats`.

## CI/CD Integration

The test infrastructure is designed to work in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Install k3d
  run: |
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

- name: Install BATS
  run: |
    brew install bats-core  # macOS
    # or apt-get install bats  # Linux

- name: Run tests
  run: |
    make test
```

The tests output TAP format, which is compatible with most CI systems.

## Additional Resources

- [k3d Documentation](https://k3d.io/)
- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Plugin README](../scripts/README.md) - Main plugin documentation
- [Demo Guide](../scripts/DEMO.md) - Guide for recording demos
