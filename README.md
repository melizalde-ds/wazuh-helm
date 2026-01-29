# Wazuh Helm Chart

Production-ready Helm chart for deploying Wazuh security monitoring on Kubernetes.

## Quick Start

```bash
# Install with default values
helm install wazuh ./wazuh-helm

# Install with custom values
helm install wazuh ./wazuh-helm -f values.yaml

# Upgrade existing deployment
helm upgrade wazuh ./wazuh-helm
```

## What Gets Deployed

- **Wazuh Manager**: Security event processing and agent management
- **Wazuh Indexer**: Event storage and search (OpenSearch-based)
- **Wazuh Dashboard**: Web UI for security monitoring

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+
- Persistent storage (Longhorn, Ceph, etc.)
- 8GB RAM, 4 CPU cores minimum

## Basic Configuration

```yaml
# values.yaml
wazuh-manager:
  replicas: 2

wazuh-indexer:
  replicas: 3
  persistence:
    size: 50Gi
    storageClass: longhorn

wazuh-dashboard:
  ingress:
    enabled: true
    host: wazuh.yourdomain.com
```

## Common Commands

```bash
# Check deployment status
kubectl get pods -l app.kubernetes.io/name=wazuh

# View manager logs
kubectl logs -l app=wazuh-manager -f

# Access dashboard
kubectl port-forward svc/wazuh-dashboard 8443:443
```

## Troubleshooting

**Indexer not starting?**
```bash
# Check memory - needs 2GB minimum per node
kubectl describe pod -l app=wazuh-indexer
```

**Dashboard can't connect?**
```bash
# Verify indexer is running
kubectl get svc wazuh-indexer
kubectl logs -l app=wazuh-dashboard
```

## Documentation

- [Wazuh Official Docs](https://documentation.wazuh.com/)
- [Kubernetes Deployment Guide](https://documentation.wazuh.com/current/deployment-options/deploying-with-kubernetes/index.html)

## License
For license information, please see the [LICENSE](LICENSE) file.