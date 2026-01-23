#!/bin/bash

# Setup k3d cluster for testing kubectl-resource-stats plugin
# This script creates a k3d cluster, verifies Metrics Server, and creates test workloads

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-test-cluster}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Setting up k3d cluster for testing ===${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if k3d is installed
if ! command_exists k3d; then
    echo -e "${RED}Error: k3d is not installed${NC}"
    echo "Please install k3d:"
    echo "  macOS: brew install k3d"
    echo "  Linux: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
    exit 1
fi

# Check if kubectl is installed
if ! command_exists kubectl; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# Delete existing cluster if it exists
if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
    echo -e "${YELLOW}Cluster '${CLUSTER_NAME}' already exists${NC}"
    echo "Deleting existing cluster..."
    k3d cluster delete "${CLUSTER_NAME}" || true
fi

# Create k3d cluster
echo -e "${BLUE}Creating k3d cluster '${CLUSTER_NAME}'...${NC}"
k3d cluster create "${CLUSTER_NAME}" \
    --wait \
    --timeout 120s

echo -e "${GREEN}✓ Cluster created successfully${NC}"
echo ""

# Set kubectl context
echo -e "${BLUE}Setting kubectl context...${NC}"
kubectl config use-context "k3d-${CLUSTER_NAME}"

# Wait for cluster to be ready
echo -e "${BLUE}Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=120s || true

# Verify cluster
echo -e "${BLUE}Verifying cluster status...${NC}"
kubectl cluster-info
echo ""
kubectl get nodes
echo ""

# Verify Metrics Server (k3d includes it by default)
echo -e "${BLUE}Verifying Metrics Server...${NC}"
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    echo -e "${GREEN}✓ Metrics Server found${NC}"
    
    # Check if --kubelet-insecure-tls flag is needed (for local clusters)
    # This is common for minikube, k3d, and other local clusters
    if ! kubectl top nodes &>/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Metrics Server not responding, adding --kubelet-insecure-tls flag...${NC}"
        kubectl patch deployment metrics-server -n kube-system --type='json' \
            -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' 2>/dev/null || {
            # If patch fails, try to add it differently
            kubectl get deployment metrics-server -n kube-system -o yaml | \
                sed 's/- --kubelet-use-node-status-port/- --kubelet-use-node-status-port\n        - --kubelet-insecure-tls/' | \
                kubectl apply -f - 2>/dev/null || true
        }
        echo -e "${BLUE}Waiting for Metrics Server to restart...${NC}"
        sleep 5
    fi
    
    # Wait for Metrics Server to be ready
    kubectl wait --for=condition=available \
        --timeout=120s \
        deployment/metrics-server \
        -n kube-system || true
else
    echo -e "${YELLOW}⚠ Metrics Server not found, installing...${NC}"
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # For local clusters, add --kubelet-insecure-tls flag
    echo -e "${BLUE}Configuring Metrics Server for local cluster...${NC}"
    kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' 2>/dev/null || true
    
    kubectl wait --for=condition=available \
        --timeout=120s \
        deployment/metrics-server \
        -n kube-system || true
fi

# Wait a bit for metrics to be available
echo "Waiting for metrics to be available..."
sleep 10

# Verify Metrics Server is working
if kubectl top nodes >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Metrics Server is working${NC}"
else
    echo -e "${YELLOW}⚠ Metrics Server may not be fully ready yet${NC}"
fi
echo ""

# Create test namespace
echo -e "${BLUE}Creating test namespace...${NC}"
kubectl create namespace test-ns --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Test namespace created${NC}"
echo ""

# Deploy test workloads
echo -e "${BLUE}Deploying test workloads...${NC}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-1
  namespace: test-ns
  labels:
    app: test-app
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-2
  namespace: test-ns
  labels:
    app: test-app
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ['sh', '-c', 'sleep 3600']
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: test-ns
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-deployment
  template:
    metadata:
      labels:
        app: test-deployment
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF

# Wait for pods to be ready (with longer timeout and continue even if not ready)
echo "Waiting for test pods to be ready..."
kubectl wait --for=condition=ready \
    --timeout=180s \
    pod -l app=test-app -n test-ns 2>/dev/null || {
    echo -e "${YELLOW}⚠ Some test pods may not be ready yet (this is OK for testing)${NC}"
}

kubectl wait --for=condition=ready \
    --timeout=180s \
    pod -l app=test-deployment -n test-ns 2>/dev/null || {
    echo -e "${YELLOW}⚠ Some deployment pods may not be ready yet (this is OK for testing)${NC}"
}

echo -e "${GREEN}✓ Test workloads deployed${NC}"
echo ""

# Final verification
echo -e "${BLUE}Final cluster verification...${NC}"
kubectl get pods -A
echo ""

echo -e "${GREEN}=== Cluster setup complete ===${NC}"
echo ""
echo "Cluster name: ${CLUSTER_NAME}"
echo "Context: k3d-${CLUSTER_NAME}"
echo ""
echo "You can now run tests against this cluster."
echo "Run: make test"
