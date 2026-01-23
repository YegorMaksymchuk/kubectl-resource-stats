#!/bin/bash

# Test helper script for cleaning up test resources
# Removes test namespace and workloads

set -euo pipefail

NAMESPACE="${TEST_NAMESPACE:-test-ns}"

# Cleanup test namespace
cleanup_test_namespace() {
    echo "Cleaning up test namespace: ${NAMESPACE}"
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true || true
}

# Cleanup specific resources
cleanup_resources() {
    echo "Cleaning up test resources in namespace: ${NAMESPACE}"
    
    kubectl delete pod -l app=test-app -n "${NAMESPACE}" --ignore-not-found=true || true
    kubectl delete deployment test-deployment -n "${NAMESPACE}" --ignore-not-found=true || true
}

# Main cleanup function
main() {
    cleanup_resources
    # Optionally delete namespace (commented out to keep namespace for multiple test runs)
    # cleanup_test_namespace
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
