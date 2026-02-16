# Terraform k3d Provider

## Provider Setup

```hcl
terraform {
  required_providers {
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "~> 0.0.7"
    }
  }
}

resource "k3d_cluster" "main" {
  name    = var.cluster_name
  servers = 1
  agents  = 2

  port {
    host_port      = 8080
    container_port = 80
    node_filters   = ["loadbalancer"]
  }

  registries {
    create {
      name = "${var.cluster_name}-registry"
      port = 5000
    }
  }
}
```

## Directory Structure

```
terraform/environments/local/
├── main.tf
├── variables.tf
└── terraform.tfvars
```

## Variables

```hcl
# variables.tf
variable "cluster_name" {
  description = "Name of the k3d cluster"
  type        = string
  default     = "health-platform"
}

variable "server_count" {
  description = "Number of server nodes"
  type        = number
  default     = 1
}

variable "agent_count" {
  description = "Number of agent nodes"
  type        = number
  default     = 2
}

variable "registry_port" {
  description = "Local registry port"
  type        = number
  default     = 5000
}
```

## Full Example

```hcl
# main.tf
terraform {
  required_providers {
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "~> 0.0.7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

resource "k3d_cluster" "main" {
  name    = var.cluster_name
  servers = var.server_count
  agents  = var.agent_count

  kube_api {
    host_ip   = "0.0.0.0"
    host_port = 6443
  }

  port {
    host_port      = 8080
    container_port = 80
    node_filters   = ["loadbalancer"]
  }

  port {
    host_port      = 8443
    container_port = 443
    node_filters   = ["loadbalancer"]
  }

  registries {
    create {
      name = "${var.cluster_name}-registry"
      port = var.registry_port
    }
  }

  k3d {
    disable_load_balancer = false
  }

  k3s {
    extra_args {
      arg          = "--disable=traefik"
      node_filters = ["server:*"]
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "k3d-${var.cluster_name}"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "k3d-${var.cluster_name}"
  }
}
```

## Usage

```bash
cd terraform/environments/local
terraform init
terraform plan
terraform apply
```

## Outputs

```hcl
output "cluster_name" {
  value = k3d_cluster.main.name
}

output "kubeconfig_context" {
  value = "k3d-${k3d_cluster.main.name}"
}

output "registry_url" {
  value = "localhost:${var.registry_port}"
}
```
