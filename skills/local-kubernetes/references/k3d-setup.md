# k3d Manual Setup

## Installation

```bash
# macOS
brew install k3d

# Linux
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Verify
k3d version
```

## Prerequisites

- Docker running
- kubectl installed

```bash
# Install kubectl
brew install kubectl

# Verify Docker
docker info
```

## Create Cluster

### Basic Cluster

```bash
k3d cluster create dev-cluster
```

### Production-like Cluster

```bash
k3d cluster create health-platform \
  --servers 1 \
  --agents 2 \
  --registry-create health-registry:5000 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*"
```

### With Custom Config

Create `k3d-config.yaml`:

```yaml
apiVersion: k3d.io/v1alpha5
kind: Simple
metadata:
  name: health-platform
servers: 1
agents: 2
ports:
  - port: 8080:80
    nodeFilters:
      - loadbalancer
  - port: 8443:443
    nodeFilters:
      - loadbalancer
registries:
  create:
    name: health-registry
    host: "0.0.0.0"
    hostPort: "5000"
options:
  k3s:
    extraArgs:
      - arg: "--disable=traefik"
        nodeFilters:
          - server:*
```

```bash
k3d cluster create --config k3d-config.yaml
```

## Cluster Management

```bash
# List clusters
k3d cluster list

# Stop cluster (preserves state)
k3d cluster stop health-platform

# Start cluster
k3d cluster start health-platform

# Delete cluster
k3d cluster delete health-platform
```

## Kubeconfig

```bash
# Get kubeconfig
k3d kubeconfig get health-platform

# Merge with default kubeconfig
k3d kubeconfig merge health-platform --kubeconfig-merge-default

# Set context
kubectl config use-context k3d-health-platform
```

## Verify Cluster

```bash
# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check local registry
curl -s http://localhost:5000/v2/_catalog
```

## Troubleshooting

### Container not starting

```bash
# Check Docker resources
docker system df

# Clean up
docker system prune
```

### Port conflicts

```bash
# Check what's using the port
lsof -i :8080

# Use different port
k3d cluster create ... --port "9080:80@loadbalancer"
```

### Registry issues

```bash
# Verify registry is running
docker ps | grep registry

# Test push
docker pull nginx:alpine
docker tag nginx:alpine localhost:5000/nginx:alpine
docker push localhost:5000/nginx:alpine
```
