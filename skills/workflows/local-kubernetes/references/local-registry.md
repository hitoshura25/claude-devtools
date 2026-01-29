# Local Registry Workflow

## Registry Setup

The k3d cluster creates a local registry at `localhost:5000` when using:

```bash
k3d cluster create ... --registry-create health-registry:5000
```

## Building Images

### Basic Build

```bash
# Build with local registry tag
docker build -t localhost:5000/my-app:latest .

# Push to local registry
docker push localhost:5000/my-app:latest
```

### Multi-platform Build

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t localhost:5000/my-app:latest \
  --push .
```

## Using Images in Kubernetes

### In Pod Spec

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      # Use k3d-[cluster-name]-registry:5000 inside cluster
      image: k3d-health-platform-registry:5000/my-app:latest
```

### In Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
        - name: app
          image: k3d-health-platform-registry:5000/my-app:latest
          imagePullPolicy: Always
```

## Development Workflow

### Watch and Rebuild

```bash
# Using skaffold
skaffold dev --default-repo=localhost:5000

# Manual
docker build -t localhost:5000/my-app:dev . && \
  docker push localhost:5000/my-app:dev && \
  kubectl rollout restart deployment/my-app
```

### Makefile Example

```makefile
REGISTRY := localhost:5000
APP := my-app
TAG := $(shell git rev-parse --short HEAD)

.PHONY: build push deploy

build:
	docker build -t $(REGISTRY)/$(APP):$(TAG) .

push: build
	docker push $(REGISTRY)/$(APP):$(TAG)

deploy: push
	kubectl set image deployment/$(APP) $(APP)=$(REGISTRY)/$(APP):$(TAG)

dev: push
	kubectl rollout restart deployment/$(APP)
	kubectl rollout status deployment/$(APP)
```

## Registry Operations

### List Images

```bash
curl -s http://localhost:5000/v2/_catalog
```

### List Tags

```bash
curl -s http://localhost:5000/v2/my-app/tags/list
```

### Delete Image

```bash
# Get digest
DIGEST=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:5000/v2/my-app/manifests/latest -I | grep Docker-Content-Digest | cut -d' ' -f2)

# Delete
curl -X DELETE http://localhost:5000/v2/my-app/manifests/$DIGEST
```

## Troubleshooting

### Image Pull Errors

```bash
# Verify image exists
curl http://localhost:5000/v2/my-app/tags/list

# Check registry from inside cluster
kubectl run test --rm -it --image=busybox -- \
  wget -qO- k3d-health-platform-registry:5000/v2/_catalog
```

### Registry Not Accessible

```bash
# Check registry container
docker ps | grep registry

# Check k3d network
docker network inspect k3d-health-platform

# Restart registry
docker restart k3d-health-platform-registry
```
