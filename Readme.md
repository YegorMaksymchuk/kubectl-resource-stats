# kubectl-resource-stats Plugin

Kubectl plugin for getting resource usage statistics (CPU and Memory) for Kubernetes resources in a convenient CSV format.

## Demo

Watch a live demo of the plugin in action:

[![asciicast](https://asciinema.org/a/WjHVtGMGICgWqQ6U.svg)](https://asciinema.org/a/zgdkhkKn4BUaR95O)

### Recording Your Own Demo

To record a new demo using asciinema:

```bash
# Record demo (requires asciinema installed)
./scripts/record-demo.sh

# Or manually:
asciinema rec demo.cast --command="./scripts/demo.sh"
```

The demo script (`scripts/demo.sh`) showcases:
- Plugin installation verification
- Help command
- Default table format
- Short resource names
- CSV output format
- JSON output format
- Different resource types
- Error handling
- Comparison with `kubectl top`

## Description

The `kubectl-resource-stats` plugin allows you to quickly get resource usage statistics for pods, deployments, nodes, and other Kubernetes resources in CSV format, which is convenient for data analysis and processing.

## Requirements

- `kubectl` version 1.8 or higher
- Access to a Kubernetes cluster
- Metrics Server installed in the cluster
- Bash 4.0 or higher

## Installation

### Method 1: Installation via PATH

1. Download the script or copy it from the repository:
   ```bash
   cp scripts/kubectl-resource-stats /usr/local/bin/
   ```

2. Make the file executable (if not already done):
   ```bash
   chmod +x /usr/local/bin/kubectl-resource-stats
   ```

3. Verify installation:
   ```bash
   kubectl plugin list
   ```

### Method 2: Installation to local directory

1. Create a directory for plugins (if it doesn't exist):
   ```bash
   mkdir -p ~/bin
   ```

2. Copy the script:
   ```bash
   cp scripts/kubectl-resource-stats ~/bin/
   ```

3. Add the directory to PATH (add to `~/.bashrc` or `~/.zshrc`):
   ```bash
   export PATH=$PATH:~/bin
   ```

4. Reload the shell or run:
   ```bash
   source ~/.bashrc  # or source ~/.zshrc
   ```

5. Verify installation:
   ```bash
   kubectl plugin list
   ```

## Usage

> **Demo Video:** See the plugin in action: [asciinema recording](https://asciinema.org/a/WjHVtGMGICgWqQ6U)

### Syntax

**Important:** The plugin filename is `kubectl-resource-stats` (with hyphen), but it's invoked as `kubectl resource stats` (with space). This is how kubectl converts hyphens in plugin filenames to spaces in commands.

```bash
kubectl resource stats <resource-type> <namespace> [OPTIONS]
```

### Parameters

- `resource-type` - Kubernetes resource type (pods, deployments, nodes, etc.) or short name (po, svc, deploy, etc.)
- `namespace` - Name of the namespace for which to get statistics

### Options

- `-o, --output FORMAT` - Output format: `table` (default), `csv`, or `json`

### Short Resource Names

The plugin supports kubectl short resource names for convenience. You can use either full names or short names:

| Short Name | Full Name |
|------------|-----------|
| `po` | pods |
| `svc` | services |
| `deploy` | deployments |
| `ds` | daemonsets |
| `rs` | replicasets |
| `sts` | statefulsets |
| `cm` | configmaps |
| `ns` | namespaces |
| `no` | nodes |
| `hpa` | horizontalpodautoscalers |
| `ing` | ingresses |

### Output Formats

The plugin supports three output formats:

1. **Table (default)** - Human-readable table format with aligned columns
2. **CSV** - Comma-separated values format, suitable for spreadsheet applications
3. **JSON** - JSON array format, suitable for programmatic processing

### Examples

1. **Get statistics for pods in the kube-system namespace (default table format):**
   ```bash
   kubectl resource stats pods kube-system
   ```

2. **Get statistics using short name:**
   ```bash
   kubectl resource stats po kube-system
   ```

3. **Get statistics in CSV format:**
   ```bash
   kubectl resource stats pods kube-system -o csv
   # or using long form:
   kubectl resource stats pods kube-system --output csv
   ```

4. **Get statistics in JSON format:**
   ```bash
   kubectl resource stats pods kube-system -o json
   ```

5. **Combine short name with JSON output:**
   ```bash
   kubectl resource stats po kube-system -o json
   ```

6. **Get statistics for deployments:**
   ```bash
   kubectl resource stats deployments default
   # or using short name:
   kubectl resource stats deploy default
   ```

7. **Get statistics for services:**
   ```bash
   kubectl resource stats svc default
   ```

8. **Get statistics for nodes:**
   ```bash
   kubectl resource stats nodes default
   # or using short name:
   kubectl resource stats no default
   ```
   Note: For nodes, the namespace can be any value since nodes don't belong to a namespace.

9. **Display help information:**
   ```bash
   kubectl resource stats help
   kubectl resource stats --help
   kubectl resource stats -h
   ```

## Output Formats

The plugin supports three output formats that can be selected using the `-o` or `--output` flag.

### Table Format (Default)

Human-readable table with aligned columns:

```
RESOURCE         NAMESPACE           NAME                                    CPU       MEMORY
----------------------------------------------------------------------------------------
pods             kube-system         coredns-xxx                              10m       20Mi
pods             kube-system         etcd-xxx                                  50m      100Mi
pods             kube-system         kube-apiserver-xxx                       100m      200Mi
```

### CSV Format

Comma-separated values format, suitable for spreadsheet applications:

```
Resource, Namespace, Name, CPU, Memory
pods, kube-system, coredns-xxx, 10m, 20Mi
pods, kube-system, etcd-xxx, 50m, 100Mi
pods, kube-system, kube-apiserver-xxx, 100m, 200Mi
```

### JSON Format

JSON array format, suitable for programmatic processing:

```json
[
  {
    "resource": "pods",
    "namespace": "kube-system",
    "name": "coredns-xxx",
    "cpu": "10m",
    "memory": "20Mi"
  },
  {
    "resource": "pods",
    "namespace": "kube-system",
    "name": "etcd-xxx",
    "cpu": "50m",
    "memory": "100Mi"
  }
]
```

### Output Structure

All formats contain the same data fields:

- **Resource** - Resource type (pods, deployments, etc.)
- **Namespace** - Namespace name
- **Name** - Resource name
- **CPU** - CPU usage (format: 100m = 0.1 CPU, 1 = 1 CPU)
- **Memory** - Memory usage (format: 50Mi, 100Gi, etc.)

## Troubleshooting

### Error: "Metrics API not available" or "Failed to get resource statistics"

**Cause:** Metrics Server is not installed in the cluster or is not running.

**Solution:**
1. Check if Metrics Server exists:
   ```bash
   kubectl get deployment metrics-server -n kube-system
   ```

2. If Metrics Server is missing, install it:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

3. For local clusters (minikube, k3d), you may need to add the `--kubelet-insecure-tls` flag (k3d includes Metrics Server by default):
   ```bash
   kubectl patch deployment metrics-server -n kube-system --type='json' \
     -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
   ```

### Error: "command not found: kubectl resource stats"

**Cause:** Plugin not found in PATH or file doesn't have execute permissions.

**Solution:**
1. Check if the file is in PATH:
   ```bash
   which kubectl-resource-stats
   ```

2. Check execute permissions:
   ```bash
   ls -l $(which kubectl-resource-stats)
   ```

3. If the file is not found, add it to PATH or move it to a directory that's already in PATH.

4. Check the plugin list:
   ```bash
   kubectl plugin list
   ```

**Note:** Remember that the plugin is invoked as `kubectl resource stats` (with space), not `kubectl resource-stats` (with hyphen).

### Error: "Error: Missing required arguments"

**Cause:** Required arguments are not specified.

**Solution:**
Use the correct syntax:
```bash
kubectl resource stats <resource-type> <namespace>
```

Or display help:
```bash
kubectl resource stats help
```

### Error: "namespace not found"

**Cause:** Namespace doesn't exist in the cluster.

**Solution:**
1. Check the list of available namespaces:
   ```bash
   kubectl get namespaces
   ```

2. Make sure you're using the correct namespace name.

## Testing

### Manual Testing

After installation, test the plugin:

```bash
# Test with pods in kube-system (default table format)
kubectl resource stats pods kube-system

# Test with pods using short name
kubectl resource stats po kube-system

# Test CSV output format
kubectl resource stats pods kube-system -o csv

# Test JSON output format
kubectl resource stats pods kube-system -o json

# Test with deployments (full name)
kubectl resource stats deployments default

# Test with deployments using short name
kubectl resource stats deploy default -o json

# Test help command
kubectl resource stats help

# Test error handling (non-existent namespace)
kubectl resource stats pods non-existent-namespace

# Test invalid output format
kubectl resource stats pods kube-system -o invalid
```

### Automated Testing

The plugin includes a comprehensive test suite using BATS (Bash Automated Testing System) and k3d (Kubernetes in Docker).

#### Quick Start

Run all tests using k3d:

```bash
make test
```

This will:
1. Create a k3d Kubernetes cluster
2. Verify Metrics Server (k3d includes it by default)
3. Deploy test workloads
4. Run the BATS test suite

#### Running Tests Step by Step

```bash
# Setup test cluster
make test-setup

# Run tests
make test

# Cleanup when done
make test-cleanup
```

#### Test Infrastructure

The test infrastructure includes:
- **k3d** cluster setup script for local testing
- **BATS** test suite with 20+ test cases
- **Test helpers** for cluster management
- **Test fixtures** with sample workloads

For detailed testing documentation, see [tests/README.md](../tests/README.md).

## Technical Details

### How the Plugin Works

1. The plugin receives two arguments: resource type and namespace
2. Executes the command `kubectl top <resource-type> -n <namespace>`
3. Parses the command output using `awk`
4. Formats data in CSV format with a header
5. Outputs the result to the console

### Error Handling

The plugin includes handling for the following errors:
- Missing arguments
- Missing kubectl
- Errors executing the `kubectl top` command
- Empty lines in output

## Demo and Recording

### Recording a Demo

To create a new demo recording:

```bash
# Automated recording script
./scripts/record-demo.sh

# Or manually with asciinema
asciinema rec demo.cast --command="./scripts/demo.sh"
```

The demo script showcases all plugin features including:
- Multiple output formats
- Short resource names
- Error handling
- Comparison with kubectl top

For detailed demo instructions, see [DEMO.md](./DEMO.md).

## Additional Resources

- [Official kubectl plugins documentation](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/)
- [Krew - kubectl plugin manager](https://krew.sigs.k8s.io/)
- [Krew plugin catalog](https://krew.sigs.k8s.io/plugins/)
- [Metrics Server documentation](https://github.com/kubernetes-sigs/metrics-server)
- [Testing Guide](../tests/README.md) - Comprehensive test suite documentation

## License

This script is part of the Prometheus educational project.

## Author

Created for the kubectl extension task.
