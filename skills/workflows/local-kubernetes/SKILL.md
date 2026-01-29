---
name: local-kubernetes
description: Use when setting up local Kubernetes cluster, testing Helm charts, or before cloud deployment
---

# Local Kubernetes

## Overview

Set up k3s clusters via k3d for local development, managed with Terraform.

**Announce at start:** "I'm using the local-kubernetes skill to set up the development cluster."

**REQUIRED SUB-SKILL:** Use devtools:lint-terraform for Terraform validation.

## When to Use

- Local development before cloud
- Testing Helm charts
- CI/CD testing of K8s manifests

## Why k3s/k3d

| k3s | Kind |
|-----|------|
| Production-like | CI testing only |
| Edge/IoT career relevance | Limited |
| Real networking | Docker abstraction |
| Built-in ServiceLB | Needs MetalLB |

## Quick Start

```bash
k3d cluster create health-platform \
  --servers 1 --agents 2 \
  --registry-create health-registry:5000 \
  --port "8080:80@loadbalancer"
```

## References

- @references/k3d-setup.md - Manual setup
- @references/terraform-k3d.md - IaC approach (recommended)
- @references/helm-deployments.md - PostgreSQL, Redis
- @references/local-registry.md - Image workflow

## Completion Criteria

- [ ] `kubectl get nodes` shows Ready
- [ ] Local registry at localhost:5000
- [ ] PostgreSQL/Redis deployed
- [ ] Can push/pull images
