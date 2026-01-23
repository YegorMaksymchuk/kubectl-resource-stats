#!/bin/bash

# Test helper script for setting up test cluster resources
# Creates test namespace and sample workloads for testing

set -euo pipefail

NAMESPACE="${TEST_NAMESPACE:-test-ns}"

# Create test namespace
create_test_namespace() {
    echo "Creating test namespace: ${NAMESPACE}"
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
}

# Deploy test pods
deploy_test_pods() {
    echo "Deploying test pods to namespace: ${NAMESPACE}"
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-1
  namespace: ${NAMESPACE}
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
  namespace: ${NAMESPACE}
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
EOF
    
    # Wait for pods to be ready
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready \
        --timeout=120s \
        pod -l app=test-app -n "${NAMESPACE}" || true
}

# Deploy test deployment
deploy_test_deployment() {
    echo "Deploying test deployment to namespace: ${NAMESPACE}"
    
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: ${NAMESPACE}
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
    
    # Wait for deployment to be ready
    echo "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available \
        --timeout=120s \
        deployment/test-deployment -n "${NAMESPACE}" || true
}

# Verify Metrics Server (k3d includes it by default)
verify_metrics_server() {
    echo "Verifying Metrics Server..."
    
    if kubectl top nodes >/dev/null 2>&1; then
        echo "Metrics Server is working"
        return 0
    else
        echo "Warning: Metrics Server may not be ready yet (k3d includes it by default)"
        return 1
    fi
}

# Main setup function
main() {
    create_test_namespace
    deploy_test_pods
    deploy_test_deployment
    verify_metrics_server
    
    echo "Test cluster setup complete"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
