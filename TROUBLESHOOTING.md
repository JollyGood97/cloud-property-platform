<!-- @format -->

# Troubleshooting Guide - Plot Listing Platform

This document contains all the issues we encountered and how we fixed them.

---

## 🔧 Common Issues & Solutions

### 1. Test Failures - Duplicate Data in Database

**Problem:**

```
assert 409 == 201  # Tests failing due to duplicate plot_id
```

**Cause:** SQLite test database persisting data between runs

**Solution:**

```python
# Change from file-based to in-memory database
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

# Or delete test database before each run
TEST_DB = "test_listings_temp.db"
if os.path.exists(TEST_DB):
    os.remove(TEST_DB)
```

**Files Changed:**

- `listing-service/test_main.py`
- `inquiry-service/test_main.py`

---

### 2. Blue-Green Pods Stuck in Init:0/1

**Problem:**

```
listing-service-blue-xxx   0/1     Init:0/1
```

**Cause:** Init container trying to connect to `postgres` but service is named `postgres-service`

**Solution:**

```bash
# Fix hostname in blue-green manifests
sed -i 's/nc -z postgres 5432/nc -z postgres-service 5432/g' k8s/blue-green/*.yaml
sed -i 's/@postgres:/@postgres-service:/g' k8s/blue-green/*.yaml

# Redeploy
kubectl delete deployment listing-service-blue listing-service-green -n plot-listing
kubectl apply -f k8s/blue-green/listing-service-blue-green.yaml
```

**Files Changed:**

- `k8s/blue-green/listing-service-blue-green.yaml`
- `k8s/blue-green/inquiry-service-blue-green.yaml`

---

### 3. Prometheus/Grafana Pods Not Starting - Resource Quota Exceeded

**Problem:**

```
Error creating: pods "prometheus-xxx" is forbidden: exceeded quota: plot-listing-quota
requested: limits.memory=512Mi, used: limits.memory=4Gi, limited: limits.memory=4Gi
```

**Cause:** Too many pods running (old + new blue-green deployments)

**Solution:**

```bash
# Option 1: Delete resource quota
kubectl delete resourcequota plot-listing-quota -n plot-listing

# Option 2: Increase quota
# Edit k8s/07-resource-limits.yaml
limits.memory: 8Gi  # Increased from 4Gi
requests.memory: 8Gi

# Option 3: Clean up old deployments
kubectl delete deployment <old-deployment-name> -n plot-listing
```

**Files Changed:**

- `k8s/07-resource-limits.yaml`

---

### 4. Prometheus Shows "No Targets"

**Problem:**

- Prometheus UI shows empty targets
- Queries return no data

**Cause:** Wrong service hostnames in Prometheus config

**Solution:**

```yaml
# Use full Kubernetes DNS names
scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["prometheus.plot-listing.svc.cluster.local:9090"]

  - job_name: "grafana"
    static_configs:
      - targets: ["grafana.plot-listing.svc.cluster.local:3000"]
```

**Update:**

```bash
kubectl delete configmap prometheus-config -n plot-listing
kubectl apply -f k8s/10-prometheus-grafana.yaml
kubectl rollout restart deployment prometheus -n plot-listing
```

**Files Changed:**

- `k8s/10-prometheus-grafana.yaml`

---

### 5. Prometheus Permission Denied - Cannot List Pods

**Problem:**

```
pods is forbidden: User "system:serviceaccount:plot-listing:default"
cannot list resource "pods"
```

**Cause:** Prometheus doesn't have RBAC permissions

**Solution:**

```bash
# Create ServiceAccount, ClusterRole, and ClusterRoleBinding
kubectl apply -f k8s/11-prometheus-rbac.yaml

# Update Prometheus deployment to use ServiceAccount
# Add to prometheus deployment spec:
serviceAccountName: prometheus

# Restart pods
kubectl delete pod -l app=prometheus -n plot-listing
```

**Files Created:**

- `k8s/11-prometheus-rbac.yaml`

**Files Changed:**

- `k8s/10-prometheus-grafana.yaml`

---

### 6. Grafana Shows "No Data" for Prometheus Queries

**Problem:**

- Grafana connected to Prometheus
- Queries return empty results

**Cause:** Data source URL incorrect or Prometheus not scraping

**Solution:**

```
# In Grafana Data Source configuration:
URL: http://prometheus:9090
# OR
URL: http://prometheus.plot-listing.svc.cluster.local:9090

# Both work within the same namespace
```

**Enable Grafana Metrics:**

```yaml
env:
  - name: GF_METRICS_ENABLED
    value: "true"
```

---

### 7. Container Metrics Not Available (CPU/Memory)

**Problem:**

```
container_cpu_usage_seconds_total  # Returns no data
```

**Cause:** Prometheus not scraping cAdvisor metrics from Kubernetes nodes

**Solution:**

```yaml
# Add to prometheus.yml
scrape_configs:
  - job_name: "kubernetes-nodes-cadvisor"
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      insecure_skip_verify: true
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
```

---

### 8. Security Group Ports Not Open

**Problem:**

- Can't access services from browser
- Connection timeout

**Solution:**

```bash
# Open required ports
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxx \
    --protocol tcp \
    --port 30090 \
    --cidr 0.0.0.0/0 \
    --profile personal \
    --region us-east-1

# Ports needed:
# 22 - SSH
# 80 - HTTP
# 443 - HTTPS
# 6443 - K3s API
# 30000-32767 - NodePort range
# 30090 - Prometheus
# 30300 - Grafana
# 30397 - Frontend
```

---

### 9. Multiple Pods Running (Old + New)

**Problem:**

- Too many pods consuming resources
- Multiple versions of same service

**Cause:** Deployments not cleaned up after updates

**Solution:**

```bash
# List all deployments
kubectl get deployments -n plot-listing

# Delete old deployments
kubectl delete deployment <old-deployment> -n plot-listing

# Or scale down to 0 first
kubectl scale deployment <name> -n plot-listing --replicas=0
```

---

### 10. Git Pull Conflicts on EC2

**Problem:**

```
fatal: Need to specify how to reconcile divergent branches
```

**Solution:**

```bash
# Use rebase instead of merge
git pull --rebase

# Or if you have local changes
git stash
git pull --rebase
git stash pop
```

---

## 🔍 Debugging Commands

### Check Pod Status

```bash
kubectl get pods -n plot-listing
kubectl describe pod <pod-name> -n plot-listing
kubectl logs <pod-name> -n plot-listing
kubectl logs -f deployment/<deployment-name> -n plot-listing
```

### Check Events

```bash
kubectl get events -n plot-listing --sort-by='.lastTimestamp'
```

### Check Resource Usage

```bash
kubectl top pods -n plot-listing
kubectl top nodes
```

### Check Services

```bash
kubectl get svc -n plot-listing
kubectl get endpoints -n plot-listing
```

### Check Deployments

```bash
kubectl get deployments -n plot-listing
kubectl describe deployment <name> -n plot-listing
```

### Check ConfigMaps

```bash
kubectl get configmap -n plot-listing
kubectl get configmap <name> -n plot-listing -o yaml
```

### Check RBAC

```bash
kubectl get serviceaccount -n plot-listing
kubectl get clusterrole prometheus
kubectl get clusterrolebinding prometheus
```

---

## 🚀 Quick Fixes

### Restart a Deployment

```bash
kubectl rollout restart deployment/<name> -n plot-listing
```

### Force Pod Restart

```bash
kubectl delete pod <pod-name> -n plot-listing
# Or delete all pods of a deployment
kubectl delete pod -l app=<app-name> -n plot-listing
```

### Update ConfigMap and Restart

```bash
kubectl delete configmap <name> -n plot-listing
kubectl apply -f <file>.yaml
kubectl rollout restart deployment/<name> -n plot-listing
```

### Scale Deployment

```bash
kubectl scale deployment/<name> -n plot-listing --replicas=0
kubectl scale deployment/<name> -n plot-listing --replicas=2
```

---

## 📊 Useful Prometheus Queries

### Working Queries (No Extra Config)

```
up                                    # Services up/down
prometheus_tsdb_head_series           # Metrics count
scrape_duration_seconds               # Scrape performance
process_resident_memory_bytes         # Process memory
```

### Container Metrics (Requires cAdvisor)

```
container_cpu_usage_seconds_total{namespace="plot-listing"}
container_memory_working_set_bytes{namespace="plot-listing"}
rate(container_cpu_usage_seconds_total[5m])
```

---

## 🎯 Access URLs

```
Frontend:    http://54.198.52.21:30397
Listing API: http://54.198.52.21:30397/api/listings
Inquiry API: http://54.198.52.21:30397/api/inquiries
Prometheus:  http://54.198.52.21:30090
Grafana:     http://54.198.52.21:30300
  Username: admin
  Password: admin123
```

---

## 💡 Best Practices Learned

1. **Always use full Kubernetes DNS names** in configs: `service.namespace.svc.cluster.local`
2. **Check RBAC permissions** when pods can't access Kubernetes API
3. **Monitor resource quotas** - they can silently prevent pod creation
4. **Clean up old deployments** to free resources
5. **Use `kubectl describe`** to see detailed error messages
6. **Check events** for cluster-level issues
7. **Test database isolation** - use in-memory or clean up between tests
8. **Security groups** must allow NodePort range (30000-32767)
9. **ServiceAccounts** are required for Prometheus to discover services
10. **Always restart pods** after ConfigMap changes

---

**Last Updated:** December 4, 2025
