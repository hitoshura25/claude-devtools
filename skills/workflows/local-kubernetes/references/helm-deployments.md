# Helm Deployments for Local Kubernetes

## Prerequisites

```bash
# Install Helm
brew install helm

# Add common repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## PostgreSQL

### Install

```bash
helm install postgres bitnami/postgresql \
  --namespace database --create-namespace \
  --set auth.postgresPassword=devpassword \
  --set auth.database=healthdata \
  --set primary.persistence.size=1Gi
```

### Terraform

```hcl
resource "helm_release" "postgres" {
  name             = "postgres"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "postgresql"
  namespace        = "database"
  create_namespace = true

  set {
    name  = "auth.postgresPassword"
    value = var.postgres_password
  }

  set {
    name  = "auth.database"
    value = "healthdata"
  }

  set {
    name  = "primary.persistence.size"
    value = "1Gi"
  }
}
```

### Connect

```bash
# Port forward
kubectl port-forward -n database svc/postgres-postgresql 5432:5432

# Connect
psql -h localhost -U postgres -d healthdata
```

## Redis

### Install

```bash
helm install redis bitnami/redis \
  --namespace cache --create-namespace \
  --set auth.enabled=false \
  --set replica.replicaCount=0 \
  --set master.persistence.size=500Mi
```

### Terraform

```hcl
resource "helm_release" "redis" {
  name             = "redis"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "redis"
  namespace        = "cache"
  create_namespace = true

  set {
    name  = "auth.enabled"
    value = "false"
  }

  set {
    name  = "replica.replicaCount"
    value = "0"
  }

  set {
    name  = "master.persistence.size"
    value = "500Mi"
  }
}
```

### Connect

```bash
# Port forward
kubectl port-forward -n cache svc/redis-master 6379:6379

# Connect
redis-cli ping
```

## MinIO (S3-compatible storage)

### Install

```bash
helm install minio bitnami/minio \
  --namespace storage --create-namespace \
  --set auth.rootUser=minioadmin \
  --set auth.rootPassword=minioadmin \
  --set defaultBuckets=mlflow-artifacts
```

### Access UI

```bash
kubectl port-forward -n storage svc/minio 9001:9001
# Open http://localhost:9001
```

## Ingress-NGINX

### Install

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
```

## Verification

```bash
# Check all releases
helm list -A

# Check PostgreSQL
kubectl get pods -n database

# Check Redis
kubectl get pods -n cache

# Test connections
kubectl run test-pod --rm -it --image=postgres:16 -- \
  psql -h postgres-postgresql.database -U postgres -c "SELECT 1"
```
