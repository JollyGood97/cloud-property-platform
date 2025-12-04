<!-- @format -->

# Answers to Your Questions

## Question 1: Is port 8080 the ingress, which acts as an API gateway?

**Short Answer**: No, port 8080 is just your local port-forward. The actual ingress is a Kubernetes resource.

**Detailed Explanation**:

### What is Port 8080?

Port 8080 is the **local port** on your machine where you're forwarding traffic from the Kubernetes cluster. When you run:

```bash
kubectl port-forward -n plot-listing svc/frontend 8080:80
```

This creates a tunnel:

```
Your Browser (localhost:8080) → kubectl → Kubernetes Service (port 80) → Frontend Pods
```

### What is the Actual Ingress/API Gateway?

The **real ingress** is defined in `k8s/06-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: plot-listing-ingress
  namespace: plot-listing
```

**How it works**:

```
Internet/External Traffic
         ↓
    Ingress Controller (Traefik)
         ↓
    Routes based on path:
    - / → frontend service
    - /api/listings → listing-service
    - /api/inquiries → inquiry-service
```

### API Gateway Functionality

The **Nginx frontend** acts as an API gateway through its configuration:

```nginx
# From k8s/05-frontend.yaml ConfigMap
location /api/listings {
    proxy_pass http://listing-service:8000/listings;
}

location /api/inquiries {
    proxy_pass http://inquiry-service:8001/inquiries;
}
```

**Request Flow**:

```
User Request: http://localhost:8080/api/listings
         ↓
    Port Forward (8080 → 80)
         ↓
    Frontend Nginx (API Gateway)
         ↓
    Proxies to: listing-service:8000/listings
         ↓
    Listing Service Pod
         ↓
    PostgreSQL Database
```

---

## Question 2: Is plot-listing-lb responsible for distributing workloads to each pod? Each has 2 pods right?

**Short Answer**: Yes! The LoadBalancer service distributes traffic across pods, and yes, each service has 2 replicas.

**Detailed Explanation**:

### LoadBalancer Service

From your output:

```bash
kubectl get svc plot-listing-lb -n plot-listing
NAME              TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
plot-listing-lb   LoadBalancer   10.43.26.219   <pending>     80:30257/TCP
```

**What it does**:

```yaml
# From k8s/06-ingress.yaml
apiVersion: v1
kind: Service
metadata:
  name: plot-listing-lb
spec:
  type: LoadBalancer
  selector:
    app: frontend # Selects all pods with label app=frontend
  ports:
    - port: 80
      targetPort: 80
```

### Load Distribution

**How Kubernetes distributes traffic**:

```
plot-listing-lb (LoadBalancer)
         ↓
    Selects pods with label: app=frontend
         ↓
    ┌─────────────┴─────────────┐
    ↓                           ↓
frontend-pod-1              frontend-pod-2
(replica 1)                 (replica 2)
```

**Load balancing algorithm**: Round-robin (default)

- Request 1 → Pod 1
- Request 2 → Pod 2
- Request 3 → Pod 1
- Request 4 → Pod 2
- ...

### Your Current Deployment

From your output:

```bash
kubectl get pods -n plot-listing
NAME                               READY   STATUS
frontend-745d7dbc45-q2hhg          1/1     Running   # Frontend replica 1
frontend-745d7dbc45-zw5kz          1/1     Running   # Frontend replica 2
inquiry-service-6d578f9856-6ch6m   1/1     Running   # Inquiry replica 1
inquiry-service-6d578f9856-zwqq5   1/1     Running   # Inquiry replica 2
listing-service-68bfb748f7-d5vqg   1/1     Running   # Listing replica 1
listing-service-68bfb748f7-nr8vm   1/1     Running   # Listing replica 2
postgres-0                         1/1     Running   # Database (1 pod)
```

**Yes, each service has 2 pods**:

- ✅ Frontend: 2 replicas
- ✅ Listing Service: 2 replicas
- ✅ Inquiry Service: 2 replicas
- ✅ PostgreSQL: 1 pod (StatefulSet)

### Complete Traffic Flow

```
External Request
       ↓
plot-listing-lb (LoadBalancer)
       ↓
   [Round-robin]
       ↓
   ┌───┴───┐
   ↓       ↓
Frontend  Frontend
 Pod 1    Pod 2
   ↓       ↓
   └───┬───┘
       ↓
  Nginx (API Gateway)
       ↓
   [Routes by path]
       ↓
   ┌───┴────────┐
   ↓            ↓
Listing Svc   Inquiry Svc
   ↓            ↓
[Round-robin] [Round-robin]
   ↓            ↓
 ┌─┴─┐        ┌─┴─┐
 ↓   ↓        ↓   ↓
Pod1 Pod2    Pod1 Pod2
 └─┬─┘        └─┬─┘
   ↓            ↓
   └─────┬──────┘
         ↓
    PostgreSQL
```

### Service Types Comparison

| Service Type     | Purpose                              | Your Usage                       |
| ---------------- | ------------------------------------ | -------------------------------- |
| **LoadBalancer** | External access, distributes to pods | plot-listing-lb → frontend       |
| **ClusterIP**    | Internal cluster access only         | listing-service, inquiry-service |
| **NodePort**     | Access via node IP:port              | Automatically created (30257)    |

---

## Question 3: How can I access the frontend site in my local browser to see if it's working?

**Short Answer**: You have 3 options. Port-forward is the easiest for local K3s.

### Option 1: Port Forward (Recommended for K3s)

**Command**:

```bash
kubectl port-forward -n plot-listing svc/frontend 8080:80
```

**Access**:

- Open browser: http://localhost:8080
- Frontend will load
- APIs accessible at:
  - http://localhost:8080/api/listings
  - http://localhost:8080/api/inquiries

**Pros**:

- ✅ Works immediately
- ✅ No configuration needed
- ✅ Secure (localhost only)

**Cons**:

- ❌ Only accessible from your machine
- ❌ Terminal must stay open

### Option 2: NodePort (Already Available!)

From your output: `80:30257/TCP`

**Access**:

- Open browser: http://localhost:30257
- Or: http://<your-machine-ip>:30257

**How to find your IP**:

```bash
# Get your machine IP
hostname -I | awk '{print $1}'

# Or
ip addr show | grep "inet " | grep -v 127.0.0.1
```

**Example**:

```bash
# If your IP is 192.168.1.100
http://192.168.1.100:30257
```

**Pros**:

- ✅ No port-forward needed
- ✅ Accessible from other machines on network
- ✅ Persistent (doesn't require terminal)

**Cons**:

- ❌ Uses non-standard port (30257)
- ❌ May be blocked by firewall

### Option 3: Ingress with Local Domain

**Setup**:

```bash
# 1. Add to /etc/hosts
echo "127.0.0.1 plot-listing.local" | sudo tee -a /etc/hosts

# 2. Access via ingress
# http://plot-listing.local
```

**Note**: K3s uses Traefik ingress controller by default, which should work automatically.

**Pros**:

- ✅ Clean URL (no port number)
- ✅ Production-like setup
- ✅ Can use HTTPS

**Cons**:

- ❌ Requires /etc/hosts modification
- ❌ Only works on your machine

### Recommended Approach for Testing

**For local development**:

```bash
# Terminal 1: Port forward
kubectl port-forward -n plot-listing svc/frontend 8080:80

# Terminal 2: Test APIs
curl http://localhost:8080/api/listings
curl http://localhost:8080/api/inquiries

# Browser: Open http://localhost:8080
```

**For demo/presentation**:

```bash
# Use NodePort (no terminal needed)
# Open: http://localhost:30257
```

### Verify It's Working

**Test the frontend**:

```bash
# 1. Port forward
kubectl port-forward -n plot-listing svc/frontend 8080:80 &

# 2. Test homepage
curl http://localhost:8080

# 3. Test listing API
curl http://localhost:8080/api/listings

# 4. Create a test listing
curl -X POST http://localhost:8080/api/listings \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "DEMO001",
    "title": "Beautiful Villa",
    "location": "Cloud City",
    "category": "Sale",
    "price": 500000,
    "available": true
  }'

# 5. Verify it was created
curl http://localhost:8080/api/listings | python3 -m json.tool
```

**Expected output**:

```json
[
  {
    "plot_id": "K8S001",
    "title": "Kubernetes Villa",
    "location": "Cloud City",
    "category": "Sale",
    "price": 9999999.0,
    "available": true,
    "created_at": "2025-12-04T09:03:40.094771Z",
    "updated_at": null
  },
  {
    "plot_id": "DEMO001",
    "title": "Beautiful Villa",
    "location": "Cloud City",
    "category": "Sale",
    "price": 500000.0,
    "available": true,
    "created_at": "2025-12-04T10:15:30.123456Z",
    "updated_at": null
  }
]
```

---

## Summary

### Your Understanding is Correct!

1. ✅ **Port 8080**: Local port-forward, not the actual ingress
2. ✅ **plot-listing-lb**: Yes, distributes traffic to frontend pods
3. ✅ **2 pods each**: Correct, each service has 2 replicas
4. ✅ **Access frontend**: Use port-forward or NodePort (30257)

### Architecture Summary

```
Your Browser (localhost:8080)
         ↓
    Port Forward
         ↓
plot-listing-lb (LoadBalancer)
         ↓
    [Load balances between]
         ↓
    ┌────┴────┐
    ↓         ↓
Frontend   Frontend
 Pod 1     Pod 2
    ↓         ↓
    └────┬────┘
         ↓
   Nginx (API Gateway)
         ↓
    [Routes by path]
         ↓
    ┌────┴─────────┐
    ↓              ↓
Listing Svc    Inquiry Svc
    ↓              ↓
[2 pods each]  [2 pods each]
    ↓              ↓
    └──────┬───────┘
           ↓
      PostgreSQL
```

---

## Next Steps: CI/CD Setup

Now that you understand the architecture, you're ready to set up CI/CD!

### Quick Setup

```bash
# 1. Make scripts executable (already done)
chmod +x scripts/*.sh tests/*.sh

# 2. Set up CI/CD
./scripts/deploy-ci-cd.sh

# 3. Create GitHub repository
git init
git add .
git commit -m "Add Plot Listing platform with CI/CD"
git remote add origin https://github.com/your-username/plot-listing.git
git push -u origin main

# 4. Configure GitHub secrets
# Go to: Repository → Settings → Secrets → Actions
# Add: KUBECONFIG (from deploy-ci-cd.sh output)

# 5. Push to trigger pipeline
git push origin main

# 6. Monitor pipeline
# GitHub → Actions tab
```

### Yes, GitHub Actions is Free!

- ✅ **Free for public repositories**: Unlimited minutes
- ✅ **Free for private repositories**: 2,000 minutes/month
- ✅ **No credit card required**

---

**You're all set!** 🚀

Your deployment is working perfectly, and you now have:

- ✅ Microservices running
- ✅ Load balancing configured
- ✅ Multiple replicas for high availability
- ✅ Ready for CI/CD setup

**Time to proceed with CI/CD!** 🎉
