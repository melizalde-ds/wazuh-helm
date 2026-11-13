# Wazuh Kubernetes Deployment

Production-grade Helm chart for deploying Wazuh SIEM on Kubernetes. This is a complete rewrite optimized for cloud-native deployments with cert-manager integration, proper security controls, and scalability.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Wazuh Version](https://img.shields.io/badge/Wazuh-4.14.1-green.svg)](https://wazuh.com)

## 🎯 Features

- ✅ **Automated Certificate Management** - Full cert-manager integration with self-signed or external CA support
- ✅ **High Availability** - StatefulSet for indexer, configurable replicas for all components
- ✅ **Security Hardened** - Non-root containers, security contexts, TLS everywhere
- ✅ **Production Ready** - Comprehensive probes, anti-affinity rules, resource management
- ✅ **Persistent Storage** - Configurable PVCs with support for any storage class
- ✅ **GitOps Friendly** - Fully templated, values-driven configuration

## 📋 Prerequisites

| Component | Version | Required | Notes |
|-----------|---------|----------|-------|
| Kubernetes | 1.24+ | ✅ | Tested on 1.24-1.31 |
| Helm | 3.8+ | ✅ | |
| cert-manager | 1.13+ | ✅ | For certificate management |
| StorageClass | - | ✅ | Must support RWO volumes |
| LoadBalancer | - | ⚠️ | Optional, for external access |

### Required Kubernetes Resources

```bash
# Verify cert-manager is installed
kubectl get pods -n cert-manager

# Verify default storage class exists
kubectl get storageclass
```

## 🚀 Quick Start

### 1. Create Namespace

```bash
kubectl create namespace wazuh
```

### 2. Install with Default Configuration

```bash
helm upgrade --install wazuh ./chart \
  --namespace wazuh \
  --create-namespace \
  --timeout 10m
```

### 3. Access Dashboard

#### Option A: Port Forward (Development)
```bash
kubectl port-forward -n wazuh svc/wazuh-dashboard 5601:5601
```
Then access: `https://localhost:5601`

#### Option B: NodePort (Testing)
Update values.yaml:
```yaml
dashboard:
  service:
    type: NodePort
```

Get access URL:
```bash
export NODE_PORT=$(kubectl get -n wazuh -o jsonpath="{.spec.ports[0].nodePort}" services wazuh-dashboard)
export NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}")
echo "https://$NODE_IP:$NODE_PORT"
```

#### Option C: LoadBalancer (Production)
```yaml
dashboard:
  service:
    type: LoadBalancer
```

### 4. Default Credentials

⚠️ **CHANGE IMMEDIATELY IN PRODUCTION**

| Component | Username | Password |
|-----------|----------|----------|
| Dashboard | `admin` | `admin` |
| API | `wazuh-api` | `ApiPass123!` |
| Indexer | `admin` | `admin` |

## 📦 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Wazuh Dashboard                     │
│                    (Deployment: 1 Pod)                  │
│                     Port: 5601/HTTPS                    │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Wazuh Manager Master                  │
│                  (StatefulSet: 1 Pod)                   │
│              Ports: 1515, 1516, 55000                   │
└─────────────────────────────────────────────────────────┘
                            │
                            ├──────────────────────┐
                            ▼                      ▼
┌────────────────────────────────┐   ┌──────────────────────────────┐
│     Wazuh Manager Workers      │   │      Wazuh Indexer           │
│     (Deployment: N Pods)       │   │   (StatefulSet: N Pods)      │
│       Port: 1514/TCP+UDP       │   │    Ports: 9200, 9300         │
└────────────────────────────────┘   └──────────────────────────────┘
                ▲
                │
         ┌──────┴──────┐
         │   Agents    │
         └─────────────┘
```

## 🔒 Certificate Management

The chart uses cert-manager for automated certificate lifecycle management.

### Self-Signed Certificates (Default)

Automatically creates:
- Root CA certificate
- Component certificates (indexer, manager, worker, dashboard, admin)
- 1-year validity with 30-day renewal window

```yaml
certificates:
  selfSigned: true
  duration: 8760h      # 1 year
  renewBefore: 720h    # 30 days before expiration
```

### Using External CA/Issuer

```yaml
certificates:
  selfSigned: false
  issuerRef:
    name: my-cluster-issuer
    kind: ClusterIssuer
  rootCA:
    secretName: my-ca-secret  # Must contain ca.crt
```

### Certificate Locations

All certificates are automatically mounted to the correct locations:
- Indexer: `/usr/share/wazuh-indexer/config/certs/`
- Manager: `/etc/ssl/`
- Dashboard: `/usr/share/wazuh-dashboard/certs/`

## ⚙️ Configuration

### Essential Configuration

#### Secrets (⚠️ MUST CHANGE FOR PRODUCTION)

```yaml
secrets:
  # Agent registration password
  authdPassword: "YourSecurePassword123!"
  
  # Wazuh API credentials
  apiUsername: "wazuh-api"
  apiPassword: "YourAPIPassword123!"
  
  # Indexer credentials
  indexerUsername: "admin"
  indexerPassword: "YourIndexerPassword123!"
  # Generate hash: docker run --rm -it wazuh/wazuh-indexer:4.14.1 \
  #   bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p YourPassword
  indexerPasswordHash: "$2y$12$..."
  
  # Dashboard credentials
  dashboardUsername: "kibanaserver"
  dashboardPassword: "YourDashboardPassword123!"
  dashboardPasswordHash: "$2y$12$..."
  
  # Cluster key (32 characters)
  clusterKey: "c98b6ha9b6169zc5f67rae55ae4z5647"
```

#### Storage Configuration

```yaml
global:
  storageClass: "fast-ssd"  # Your storage class

indexer:
  persistence:
    size: 100Gi
    storageClass: ""  # Override global if needed

manager:
  master:
    persistence:
      size: 20Gi
  workers:
    persistence:
      size: 20Gi

dashboard:
  persistence:
    size: 5Gi
```

#### Resource Limits

```yaml
indexer:
  replicas: 3
  javaOpts: "-Xms4g -Xmx4g"  # Heap size
  resources:
    requests:
      cpu: 2000m
      memory: 6Gi
    limits:
      cpu: 4000m
      memory: 8Gi

manager:
  workers:
    replicas: 2
    resources:
      requests:
        cpu: 1000m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi
```

### Advanced Configuration

#### High Availability

For production HA setup:

```yaml
indexer:
  replicas: 3  # Minimum for quorum
  antiAffinity:
    enabled: true
    type: hard  # Force distribution across nodes
    topologyKey: "kubernetes.io/hostname"

manager:
  master:
    replicas: 1  # Single master (HA master not yet supported)
  workers:
    replicas: 3  # Multiple workers for load distribution
```

#### Performance Tuning

```yaml
indexer:
  javaOpts: "-Xms8g -Xmx8g"  # 50-75% of memory limit
  resources:
    limits:
      memory: 12Gi

manager:
  workers:
    replicas: 5  # Scale based on agent count
    # Rough guide: 1 worker per 1000-2000 agents
```

#### Node Scheduling

```yaml
global:
  nodeSelector:
    workload: wazuh
  
  tolerations:
    - key: "wazuh"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
  
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                  - us-west-2a
                  - us-west-2b
```

## 🔌 Connecting Agents

### Connection String

Agents connect to worker nodes:

```bash
# Get worker service endpoint
kubectl get svc -n wazuh wazuh-workers

# For LoadBalancer
WAZUH_MANAGER=$(kubectl get svc -n wazuh wazuh-workers -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# For NodePort
WAZUH_MANAGER=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
WAZUH_PORT=$(kubectl get svc -n wazuh wazuh-workers -o jsonpath='{.spec.ports[?(@.name=="agents-events")].nodePort}')
```

### Agent Registration

1. Get authd password:
```bash
kubectl get secret -n wazuh wazuh-auth -o jsonpath='{.data.authd\.pass}' | base64 -d
```

2. Register agent:
```bash
# Linux/Unix
sudo /var/ossec/bin/agent-auth -m $WAZUH_MANAGER -P <authd-password>
sudo systemctl start wazuh-agent

# Windows
"C:\Program Files (x86)\ossec-agent\agent-auth.exe" -m $WAZUH_MANAGER -P <authd-password>
```

## 📊 Monitoring & Observability

### Health Checks

```bash
# Check pod status
kubectl get pods -n wazuh

# Check indexer cluster health
kubectl exec -n wazuh wazuh-indexer-0 -- curl -sk -u admin:admin \
  https://localhost:9200/_cluster/health?pretty

# Check manager cluster status
kubectl exec -n wazuh wazuh-manager-master-0 -- /var/ossec/bin/cluster_control -l
```

### Logs

```bash
# Dashboard logs
kubectl logs -n wazuh -l app=wazuh-dashboard -f

# Indexer logs
kubectl logs -n wazuh -l app=wazuh-indexer -f

# Manager logs
kubectl logs -n wazuh -l app=wazuh-manager -f
```

### Metrics (Future)

ServiceMonitor and PodMonitor resources will be added in future releases for Prometheus integration.

## 🔧 Maintenance

### Upgrading

```bash
# Backup current configuration
helm get values -n wazuh wazuh > wazuh-values-backup.yaml

# Upgrade to new version
helm upgrade wazuh ./chart \
  --namespace wazuh \
  --values wazuh-values-backup.yaml \
  --timeout 15m
```

### Backup Strategy

```yaml
# Example using Velero
velero backup create wazuh-backup \
  --include-namespaces wazuh \
  --default-volumes-to-fs-backup

# Backup individual PVCs
kubectl get pvc -n wazuh
# Use your backup solution (Velero, Kasten, etc.)
```

### Scaling

```bash
# Scale workers
kubectl scale deployment -n wazuh wazuh-workers --replicas=5

# Scale indexer (requires care)
# 1. Update values.yaml
# 2. Run helm upgrade
# 3. Wait for new pods to join cluster
```

## 🐛 Troubleshooting

### Indexer Won't Start

```bash
# Check cluster formation
kubectl logs -n wazuh wazuh-indexer-0 | grep -i "cluster\|discovery"

# Check DNS resolution
kubectl exec -n wazuh wazuh-indexer-0 -- nslookup wazuh-indexer-cluster.wazuh.svc.cluster.local

# Check certificates
kubectl exec -n wazuh wazuh-indexer-0 -- ls -la /usr/share/wazuh-indexer/config/certs/
```

### Dashboard Can't Connect

```bash
# Verify indexer is healthy
kubectl exec -n wazuh wazuh-indexer-0 -- curl -sk -u admin:admin https://localhost:9200

# Check dashboard config
kubectl get cm -n wazuh wazuh-dashboard-conf -o yaml

# Check credentials match
kubectl get secret -n wazuh wazuh-indexer-creds -o yaml
kubectl get secret -n wazuh wazuh-dashboard-secret -o yaml
```

### Agents Not Connecting

```bash
# Verify worker service
kubectl get svc -n wazuh wazuh-workers

# Check worker logs
kubectl logs -n wazuh -l node-type=worker -f

# Test connection from agent
telnet $WAZUH_MANAGER 1514

# Check firewall rules
# Ensure port 1514 TCP/UDP is open
```

### Certificate Issues

```bash
# Check cert-manager certificates
kubectl get certificates -n wazuh

# Describe certificate for issues
kubectl describe certificate -n wazuh wazuh-indexer

# Force renewal
kubectl delete certificate -n wazuh wazuh-indexer
# Will be recreated automatically
```

## 🚧 Known Limitations

1. **Secrets in values.yaml**: Currently requires manual secret generation. Future: External secrets support
2. **Single Master**: HA master cluster not yet implemented
3. **No Ingress**: Must configure separately (see examples below)
4. **No Monitoring**: ServiceMonitor/PodMonitor coming in future release
5. **Manual Security Init**: Indexer security must be initialized manually (automated job coming)

## 📚 Examples

### Production values.yaml

```yaml
# See examples/production-values.yaml (to be created)
global:
  storageClass: "fast-ssd"

indexer:
  replicas: 3
  javaOpts: "-Xms8g -Xmx8g"
  resources:
    requests:
      cpu: 4000m
      memory: 12Gi
    limits:
      cpu: 8000m
      memory: 16Gi
  persistence:
    size: 200Gi
  antiAffinity:
    enabled: true
    type: hard

manager:
  workers:
    replicas: 3
    resources:
      requests:
        cpu: 2000m
        memory: 4Gi
    persistence:
      size: 50Gi

dashboard:
  service:
    type: LoadBalancer
```

### Ingress Example

```yaml
# examples/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wazuh-dashboard
  namespace: wazuh
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - wazuh.example.com
      secretName: wazuh-dashboard-tls
  rules:
    - host: wazuh.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wazuh-dashboard
                port:
                  number: 5601
```

## 🤝 Contributing

This is a personal fork/rewrite of the upstream Wazuh Helm chart. Contributions welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

Apache 2.0 (same as Wazuh)

## 🙏 Acknowledgments

- Based on [wazuh/wazuh-kubernetes](https://github.com/wazuh/wazuh-kubernetes) but heavily rewritten
- Wazuh team for the amazing SIEM platform
- cert-manager team for certificate automation

## 📞 Support

- **Issues**: GitHub Issues
- **Wazuh Docs**: https://documentation.wazuh.com
- **Community**: Wazuh Slack/Forums

---

**Status**: Development/Testing Ready | Production with caveats (see limitations)

**Version**: 0.1.0 (Based on Wazuh 4.14.1)

**Maintained by**: Miguel (@samma-io fork)