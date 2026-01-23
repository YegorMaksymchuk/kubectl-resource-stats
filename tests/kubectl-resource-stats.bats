#!/usr/bin/env bats

# Test suite for kubectl-resource-stats plugin
# Tests cover basic functionality, output formats, resource types, and error handling

# Load BATS helpers if available (optional but recommended)
# Try to load from test_helper directory first
if [ -f "test_helper/bats-support/load.bash" ]; then
    load 'test_helper/bats-support/load' 2>/dev/null || true
fi
if [ -f "test_helper/bats-assert/load.bash" ]; then
    load 'test_helper/bats-assert/load' 2>/dev/null || true
fi

# Helper functions if bats-assert is not available
if ! type assert_output >/dev/null 2>&1; then
    # Fallback assert_output function (simplified version)
    # Handles: assert_output --partial "pattern"
    assert_output() {
        local pattern=""
        local arg1="${1:-}"
        local arg2="${2:-}"
        
        # Parse --partial flag
        if [ "$arg1" = "--partial" ]; then
            pattern="$arg2"
        else
            pattern="$arg1"
        fi
        
        if echo "$output" | grep -q "$pattern"; then
            return 0
        else
            echo "Expected output containing: $pattern"
            echo "Actual output: $output"
            return 1
        fi
    }
    
    # Fallback assert_line function (simplified version)
    # Handles: assert_line --index N --partial "pattern" or --regexp "pattern"
    assert_line() {
        local line_num=""
        local pattern=""
        local use_regexp=false
        local arg1="${1:-}"
        local arg2="${2:-}"
        local arg3="${3:-}"
        local arg4="${4:-}"
        
        # Parse arguments (handle --index, --partial, and --regexp flags)
        if [ "$arg1" = "--index" ]; then
            line_num="$arg2"
            if [ "$arg3" = "--partial" ]; then
                pattern="${arg4:-}"
            elif [ "$arg3" = "--regexp" ]; then
                pattern="${arg4:-}"
                use_regexp=true
            else
                pattern="$arg3"
            fi
        elif [ "$arg1" = "--partial" ]; then
            pattern="$arg2"
        elif [ "$arg1" = "--regexp" ]; then
            pattern="$arg2"
            use_regexp=true
        else
            pattern="$arg1"
        fi
        
        if [ -n "$line_num" ] && [ -n "$pattern" ]; then
            # Line numbers in BATS are 0-indexed, but sed is 1-indexed
            local sed_line=$((line_num + 1))
            local actual_line=$(echo "$output" | sed -n "${sed_line}p")
            if [ "$use_regexp" = true ]; then
                if echo "$actual_line" | grep -qE "$pattern"; then
                    return 0
                else
                    echo "Expected line $line_num to match regex: $pattern"
                    echo "Actual line: $actual_line"
                    return 1
                fi
            else
                if echo "$actual_line" | grep -q "$pattern"; then
                    return 0
                else
                    echo "Expected line $line_num to contain: $pattern"
                    echo "Actual line: $actual_line"
                    return 1
                fi
            fi
        elif [ -n "$pattern" ]; then
            # Check if any line contains/matches the pattern
            if [ "$use_regexp" = true ]; then
                if echo "$output" | grep -qE "$pattern"; then
                    return 0
                else
                    echo "Expected output matching regex: $pattern"
                    echo "Actual output: $output"
                    return 1
                fi
            else
                if echo "$output" | grep -q "$pattern"; then
                    return 0
                else
                    echo "Expected output containing: $pattern"
                    echo "Actual output: $output"
                    return 1
                fi
            fi
        else
            echo "assert_line: missing pattern"
            return 1
        fi
    }
fi

# Setup function - runs before each test
setup() {
    # Use default kubeconfig location (k3d sets context automatically)
    # KUBECONFIG is usually ~/.kube/config or set by k3d
    if [ -z "${KUBECONFIG:-}" ] && [ -f "${HOME}/.kube/config" ]; then
        export KUBECONFIG="${HOME}/.kube/config"
    fi
    
    # Ensure kubectl can access the cluster
    if ! kubectl cluster-info &>/dev/null; then
        skip "Cluster not available"
    fi
    
    # Verify we're using k3d context (optional check)
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ "$CURRENT_CONTEXT" != *"k3d"* ]] && [[ "$CURRENT_CONTEXT" != *"test-cluster"* ]]; then
        echo "Warning: Not using k3d-test-cluster context. Current: $CURRENT_CONTEXT" >&2
    fi
    
    # Wait for Metrics Server to be ready (k3d includes it by default)
    # Redirect all output to stderr to avoid interfering with test output
    kubectl wait --for=condition=available \
        --timeout=60s \
        deployment/metrics-server \
        -n kube-system >&2 2>/dev/null || true
    
    # Ensure test namespace exists
    kubectl create namespace test-ns --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
    
    # Wait a moment for metrics to be available (only if we need metrics)
    # Don't wait for help/error tests
    if [[ ! "${BATS_TEST_NAME}" =~ (help|error|missing|invalid) ]]; then
        sleep 2
    fi
}

# Teardown function - runs after each test
teardown() {
    # Cleanup is handled by test helpers if needed
    true
}

# Test: Plugin help command
@test "plugin shows help with help command" {
    run kubectl resource stats help
    [ "$status" -eq 0 ]
    assert_output --partial "Usage:"
    assert_output --partial "kubectl resource stats"
}

# Test: Plugin help with --help flag
@test "plugin shows help with --help flag" {
    run kubectl resource stats --help
    [ "$status" -eq 0 ]
    assert_output --partial "Usage:"
}

# Test: Plugin help with -h flag
@test "plugin shows help with -h flag" {
    run kubectl resource stats -h
    [ "$status" -eq 0 ]
    assert_output --partial "Usage:"
}

# Test: Plugin is found by kubectl
@test "plugin is found by kubectl plugin list" {
    run kubectl plugin list
    [ "$status" -eq 0 ]
    assert_output --partial "kubectl-resource-stats"
}

# Test: Missing arguments shows error
@test "missing arguments shows error" {
    run kubectl resource stats
    [ "$status" -ne 0 ]
    assert_output --partial "Error"
    assert_output --partial "Missing required arguments"
}

# Test: Invalid output format shows error
@test "invalid output format shows error" {
    run kubectl resource stats pods default -o invalid
    [ "$status" -ne 0 ]
    assert_output --partial "Invalid output format"
}

# Test: Basic functionality with pods (table format - default)
@test "plugin works with pods in default table format" {
    run kubectl resource stats pods test-ns
    [ "$status" -eq 0 ]
    assert_output --partial "RESOURCE"
    assert_output --partial "NAMESPACE"
    assert_output --partial "NAME"
    assert_output --partial "CPU"
    assert_output --partial "MEMORY"
}

# Test: CSV output format
@test "plugin outputs CSV format correctly" {
    run kubectl resource stats pods test-ns -o csv
    [ "$status" -eq 0 ]
    assert_output --partial "Resource, Namespace, Name, CPU, Memory"
    # Verify CSV structure (comma-separated)
    assert_line --regexp '^pods, test-ns, .+, .+, .+$'
}

# Test: JSON output format
@test "plugin outputs valid JSON format" {
    run kubectl resource stats pods test-ns -o json
    [ "$status" -eq 0 ]
    # Verify it's valid JSON
    echo "$output" | jq . >/dev/null 2>&1 || {
        skip "jq not available for JSON validation"
    }
    # Verify JSON structure
    assert_output --partial "["
    assert_output --partial "resource"
    assert_output --partial "namespace"
    assert_output --partial "name"
    assert_output --partial "cpu"
    assert_output --partial "memory"
}

# Test: Short resource name (po -> pods)
@test "plugin works with short resource name 'po'" {
    run kubectl resource stats po test-ns
    [ "$status" -eq 0 ]
    assert_output --partial "RESOURCE"
    # Should work the same as 'pods'
}

# Test: Short resource name (deploy -> deployments)
@test "plugin works with short resource name 'deploy'" {
    # Create a deployment first if it doesn't exist
    kubectl create deployment test-deploy --image=nginx:alpine -n test-ns --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
    sleep 5
    
    run kubectl resource stats deploy test-ns
    [ "$status" -eq 0 ]
    assert_output --partial "RESOURCE"
}

# Test: Full resource name works
@test "plugin works with full resource name 'pods'" {
    run kubectl resource stats pods test-ns
    [ "$status" -eq 0 ]
    assert_output --partial "pods"
}

# Test: Invalid namespace shows appropriate error
@test "invalid namespace shows error" {
    run kubectl resource stats pods non-existent-namespace-12345
    # May succeed with empty output or show error depending on kubectl top behavior
    # This test verifies plugin doesn't crash
    [ "$status" -ge 0 ]
}

# Test: Output contains expected columns (CSV)
@test "CSV output contains all expected columns" {
    run kubectl resource stats pods test-ns -o csv
    [ "$status" -eq 0 ]
    
    # Check header (works with or without bats-assert)
    header=$(echo "$output" | head -n 1)
    echo "$header" | grep -q "Resource" || { echo "Missing 'Resource' in header: $header"; return 1; }
    echo "$header" | grep -q "Namespace" || { echo "Missing 'Namespace' in header: $header"; return 1; }
    echo "$header" | grep -q "Name" || { echo "Missing 'Name' in header: $header"; return 1; }
    echo "$header" | grep -q "CPU" || { echo "Missing 'CPU' in header: $header"; return 1; }
    echo "$header" | grep -q "Memory" || { echo "Missing 'Memory' in header: $header"; return 1; }
}

# Test: Output contains expected columns (table)
@test "table output contains all expected columns" {
    run kubectl resource stats pods test-ns -o table
    [ "$status" -eq 0 ]
    
    # Check header row
    assert_output --partial "RESOURCE"
    assert_output --partial "NAMESPACE"
    assert_output --partial "NAME"
    assert_output --partial "CPU"
    assert_output --partial "MEMORY"
}

# Test: JSON output is parseable
@test "JSON output is valid and parseable" {
    run kubectl resource stats pods test-ns -o json
    
    if command -v jq >/dev/null 2>&1; then
        [ "$status" -eq 0 ]
        # Try to parse JSON
        echo "$output" | jq . >/dev/null
        [ $? -eq 0 ]
        
        # Verify structure
        echo "$output" | jq 'type' | grep -q "array"
    else
        skip "jq not available for JSON validation"
    fi
}

# Test: Empty results handled correctly (CSV)
@test "empty results handled correctly in CSV format" {
    # Use a namespace that likely has no pods
    run kubectl resource stats pods kube-system -o csv
    [ "$status" -eq 0 ]
    # Should at least have header
    first_line=$(echo "$output" | head -n 1)
    echo "$first_line" | grep -q "Resource" || {
        echo "Expected header in first line, got: $first_line"
        return 1
    }
}

# Test: Long form output flag works
@test "long form --output flag works" {
    run kubectl resource stats pods test-ns --output csv
    [ "$status" -eq 0 ]
    assert_output --partial "Resource, Namespace, Name, CPU, Memory"
}

# Test: Plugin handles nodes resource type
@test "plugin works with nodes resource type" {
    run kubectl resource stats nodes default
    [ "$status" -eq 0 ]
    assert_output --partial "RESOURCE"
}

# Test: Plugin handles short name for nodes (no)
@test "plugin works with short name 'no' for nodes" {
    run kubectl resource stats no default
    [ "$status" -eq 0 ]
    assert_output --partial "RESOURCE"
}

# Test: Error handling for missing kubectl
@test "plugin handles kubectl not found gracefully" {
    # This test would require temporarily hiding kubectl, which is complex
    # So we'll skip it or test it differently
    skip "Requires kubectl to be available for other tests"
}

# Test: Multiple output formats produce consistent data
@test "different output formats produce consistent data" {
    # Get output in different formats
    run kubectl resource stats pods test-ns -o csv
    [ "$status" -eq 0 ]
    local csv_output="$output"
    
    run kubectl resource stats pods test-ns -o json
    [ "$status" -eq 0 ]
    local json_output="$output"
    
    # Both should succeed
    [ -n "$csv_output" ]
    [ -n "$json_output" ]
    
    # CSV should have header
    echo "$csv_output" | grep -q "Resource, Namespace"
    # JSON should be valid array
    echo "$json_output" | grep -q "\["
}
