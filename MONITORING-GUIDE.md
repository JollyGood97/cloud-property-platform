<!-- @format -->

# Prometheus & Grafana Monitoring Guide

Complete guide for setting up and using monitoring dashboards.

---

## 🔗 Access URLs

```
Prometheus:  http://YOUR-EC2-IP:30090
Grafana:     http://YOUR-EC2-IP:30300
  Username: admin
  Password: admin123

Frontend:    http://YOUR-EC2-IP:30397
```

Replace `YOUR-EC2-IP` with your actual EC2 public IP.

---

## 📊 Prometheus Queries Reference

### Basic Queries

#### 1. Service Health

```
up
```

Shows which services are up (1) or down (0).

#### 2. Service Count

```
count(up{namespace="plot-listing"})
```

Total number of monitored services.

---

### CPU Metrics

#### 3. CPU Usage (Raw)

```
rate(container_cpu_usage_seconds_total{namespace="plot-listing", container!=""}[5m])
```

CPU usage in cores (0.1 = 10% of one core).

#### 4. CPU Usage (Percentage)

```
rate(container_cpu_usage_seconds_total{namespace="plot-listing", container!=""}[5m]) * 100
```

CPU usage as percentage.

#### 5. CPU Usage by Pod

```
sum(rate(container_cpu_usage_seconds_total{namespace="plot-listing"}[5m])) by (pod)
```

Aggregated CPU usage per pod.

#### 6. Top 5 CPU Consumers

```
topk(5, rate(container_cpu_usage_seconds_total{namespace="plot-listing", container!=""}[5m]))
```

---

### Memory Metrics

#### 7. Memory Usage (Bytes)

```
container_memory_working_set_bytes{namespace="plot-listing", container!=""}
```

#### 8. Memory Usage (MB)

```
container_memory_working_set_bytes{namespace="plot-listing", container!=""} / 1024 / 1024
```

#### 9. Memory Usage (GB)

```
container_memory_working_set_bytes{namespace="plot-listing", container!=""} / 1024 / 1024 / 1024
```

#### 10. Memory Usage by Pod

```
sum(container_memory_working_set_bytes{namespace="plot-listing"}) by (pod) / 1024 / 1024
```

#### 11. Memory Limit

```
container_spec_memory_limit_bytes{namespace="plot-listing", container!=""} / 1024 / 1024
```

#### 12. Memory Usage vs Limit (%)

```
(container_memory_working_set_bytes{namespace="plot-listing"} / container_spec_memory_limit_bytes{namespace="plot-listing"}) * 100
```

---

### Network Metrics

#### 13. Network Received (bytes/sec)

```
rate(container_network_receive_bytes_total{namespace="plot-listing"}[5m])
```

#### 14. Network Transmitted (bytes/sec)

```
rate(container_network_transmit_bytes_total{namespace="plot-listing"}[5m])
```

#### 15. Network Received (MB/sec)

```
rate(container_network_receive_bytes_total{namespace="plot-listing"}[5m]) / 1024 / 1024
```

#### 16. Total Network Traffic

```
rate(container_network_receive_bytes_total{namespace="plot-listing"}[5m]) + rate(container_network_transmit_bytes_total{namespace="plot-listing"}[5m])
```

---

### Pod Metrics

#### 17. Pod Restart Count

```
kube_pod_container_status_restarts_total{namespace="plot-listing"}
```

#### 18. Pod Status

```
kube_pod_status_phase{namespace="plot-listing"}
```

#### 19. Running Pods Count

```
count(kube_pod_status_phase{namespace="plot-listing", phase="Running"})
```

---

### Prometheus Self-Monitoring

#### 20. Prometheus Memory Usage

```
process_resident_memory_bytes{job="prometheus"} / 1024 / 1024
```

#### 21. Prometheus CPU Usage

```
rate(process_cpu_seconds_total{job="prometheus"}[5m]) * 100
```

#### 22. Total Metrics Stored

```
prometheus_tsdb_head_series
```

#### 23. Scrape Duration

```
scrape_duration_seconds
```

#### 24. Failed Scrapes

```
up == 0
```

---

### Grafana Metrics

#### 25. Grafana Memory Usage

```
process_resident_memory_bytes{job="grafana"} / 1024 / 1024
```

#### 26. Grafana CPU Usage

```
rate(process_cpu_seconds_total{job="grafana"}[5m]) * 100
```

---

## 🎨 How to Test Queries in Prometheus

### Step 1: Access Prometheus

1. Open browser: `http://YOUR-EC2-IP:30090`
2. You'll see the Prometheus UI

### Step 2: Run a Query

1. Click on **"Graph"** tab (top)
2. In the query box, paste any query from above
3. Click **"Execute"** button
4. Switch between **"Table"** and **"Graph"** views

### Step 3: Adjust Time Range

- Use the time picker at the top
- Options: Last 5m, 15m, 1h, 6h, 24h, etc.

### Step 4: Check Targets

1. Click **"Status"** → **"Targets"**
2. Verify all targets are **UP** (green)
3. If any are **DOWN** (red), check the error message

---

## 📈 How to Create Grafana Dashboards

### Step 1: Access Grafana

1. Open browser: `http://YOUR-EC2-IP:30300`
2. Login:
   - Username: `admin`
   - Password: `admin123`

### Step 2: Add Prometheus Data Source (First Time Only)

1. Click **"Connections"** (left sidebar)
2. Click **"Data sources"**
3. Click **"Add data source"**
4. Select **"Prometheus"**
5. URL: `http://prometheus:9090`
6. Click **"Save & Test"** (should show green checkmark)

### Step 3: Create New Dashboard

1. Click **"Dashboards"** (left sidebar)
2. Click **"New"** → **"New dashboard"**
3. Click **"Add visualization"**

### Step 4: Add a Panel

1. Select **"prometheus"** as data source
2. In the query box, paste a query (e.g., `up`)
3. Configure the panel (see below)
4. Click **"Apply"**

### Step 5: Configure Panel Options

#### Panel Title

- Right side → **"Panel options"** → **"Title"**
- Example: `CPU Usage by Pod`

#### Legend

- Bottom of query section → **"Legend"**
- Show pod names: `{{pod}}`
- Show pod and container: `{{pod}} - {{container}}`

#### Visualization Type

- Top right dropdown
- Options: Time series, Stat, Gauge, Bar chart, Table

#### Units

- Right side → **"Standard options"** → **"Unit"**
- Common units:
  - Percent (0-100)
  - Bytes (IEC)
  - Bytes/sec
  - Milliseconds
  - None

#### Thresholds (for Stat/Gauge)

- Right side → **"Thresholds"**
- Set warning/critical levels
- Example: Green < 70%, Yellow 70-90%, Red > 90%

### Step 6: Save Dashboard

1. Click **"Save dashboard"** (top right, disk icon)
2. Enter name: `Plot Listing Monitoring`
3. Click **"Save"**

---

## 🎯 Pre-Built Dashboard Examples

### Dashboard 1: System Overview

**Panel 1: Services Status**

- Query: `up{namespace="plot-listing"}`
- Visualization: Stat
- Title: `Services Up`

**Panel 2: CPU Usage**

- Query: `rate(container_cpu_usage_seconds_total{namespace="plot-listing", container!=""}[5m]) * 100`
- Visualization: Time series
- Title: `CPU Usage (%)`
- Legend: `{{pod}}`
- Unit: Percent (0-100)

**Panel 3: Memory Usage**

- Query: `container_memory_working_set_bytes{namespace="plot-listing", container!=""} / 1024 / 1024`
- Visualization: Time series
- Title: `Memory Usage (MB)`
- Legend: `{{pod}}`
- Unit: Bytes (IEC)

**Panel 4: Network Traffic**

- Query: `rate(container_network_receive_bytes_total{namespace="plot-listing"}[5m]) / 1024`
- Visualization: Time series
- Title: `Network Received (KB/s)`
- Legend: `{{pod}}`

---

### Dashboard 2: Service Health

**Panel 1: Pod Count**

- Query: `count(kube_pod_status_phase{namespace="plot-listing", phase="Running"})`
- Visualization: Stat
- Title: `Running Pods`

**Panel 2: Pod Restarts**

- Query: `kube_pod_container_status_restarts_total{namespace="plot-listing"}`
- Visualization: Table
- Title: `Container Restarts`

**Panel 3: Failed Services**

- Query: `up{namespace="plot-listing"} == 0`
- Visualization: Table
- Title: `Down Services`

---

### Dashboard 3: Resource Usage

**Panel 1: Top CPU Consumers**

- Query: `topk(5, rate(container_cpu_usage_seconds_total{namespace="plot-listing"}[5m]) * 100)`
- Visualization: Bar chart
- Title: `Top 5 CPU Users`

**Panel 2: Top Memory Consumers**

- Query: `topk(5, container_memory_working_set_bytes{namespace="plot-listing"} / 1024 / 1024)`
- Visualization: Bar chart
- Title: `Top 5 Memory Users (MB)`

**Panel 3: Memory Usage vs Limit**

- Query: `(container_memory_working_set_bytes{namespace="plot-listing"} / container_spec_memory_limit_bytes{namespace="plot-listing"}) * 100`
- Visualization: Gauge
- Title: `Memory Usage (%)`
- Thresholds: Green < 70%, Yellow 70-90%, Red > 90%

---

## 🔧 Troubleshooting

### Prometheus Shows "No Data"

**Check 1: Verify Targets**

```
Go to: http://YOUR-EC2-IP:30090/targets
All targets should be UP (green)
```

**Check 2: Verify Pods Running**

```bash
kubectl get pods -n plot-listing
```

**Check 3: Check Prometheus Logs**

```bash
kubectl logs deployment/prometheus -n plot-listing
```

---

### Grafana Shows "No Data"

**Check 1: Data Source Connected**

```
Grafana → Connections → Data sources → prometheus
Click "Test" - should show green checkmark
```

**Check 2: Query Works in Prometheus**

```
Test the same query in Prometheus first
If it works there, it should work in Grafana
```

**Check 3: Time Range**

```
Check time range picker (top right)
Make sure it covers when data exists
```

**Check 4: Refresh**

```
Click the refresh button (top right)
Or set auto-refresh: 5s, 10s, 30s, 1m
```

---

## 📝 Quick Reference

### Common Legend Formats

```
{{pod}}                          # Pod name only
{{container}}                    # Container name only
{{pod}} - {{container}}          # Both
{{namespace}}/{{pod}}            # With namespace
{{instance}}                     # Node/instance
```

### Common Time Ranges

```
[1m]   # Last 1 minute
[5m]   # Last 5 minutes
[15m]  # Last 15 minutes
[1h]   # Last 1 hour
[24h]  # Last 24 hours
```

### Common Aggregations

```
sum(...) by (pod)        # Sum by pod
avg(...) by (pod)        # Average by pod
max(...) by (pod)        # Maximum by pod
min(...) by (pod)        # Minimum by pod
count(...) by (pod)      # Count by pod
topk(5, ...)             # Top 5 values
bottomk(5, ...)          # Bottom 5 values
```

---

## 🎓 Learning Resources

### Prometheus Query Language (PromQL)

- Official docs: https://prometheus.io/docs/prometheus/latest/querying/basics/
- Examples: https://prometheus.io/docs/prometheus/latest/querying/examples/

### Grafana Dashboards

- Official docs: https://grafana.com/docs/grafana/latest/dashboards/
- Community dashboards: https://grafana.com/grafana/dashboards/

---

## 💾 Backup Your Dashboards

### Export Dashboard

1. Open dashboard in Grafana
2. Click **"Share"** (top right)
3. Click **"Export"**
4. Click **"Save to file"**
5. Save JSON file locally

### Import Dashboard

1. **Dashboards** → **"New"** → **"Import"**
2. Upload JSON file or paste JSON
3. Click **"Load"**
4. Select Prometheus data source
5. Click **"Import"**

---

## 🚀 Next Steps

1. **Create your first dashboard** with CPU and Memory panels
2. **Set up alerts** in Grafana (optional)
3. **Explore community dashboards** for Kubernetes
4. **Add custom metrics** from your applications

---

**Last Updated:** December 4, 2025  
**Version:** 1.0
