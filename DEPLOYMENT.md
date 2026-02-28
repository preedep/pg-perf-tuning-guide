# Deployment Guide

คู่มือการ Deploy PostgreSQL Performance Tuning Guide

## 🎯 Prerequisites

### Required Tools
- Docker Desktop หรือ Minikube
- kubectl
- Rust 1.75+
- Git

### System Requirements
- **RAM**: 4GB+ available for Kubernetes
- **CPU**: 2+ cores
- **Disk**: 10GB+ free space

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd pg-perf-tuning-guide
```

### 2. Setup Environment

```bash
# สร้าง .env file
cp .env.example .env

# แก้ไข .env ตามต้องการ (optional)
nano .env
```

### 3. Build Docker Image

```bash
docker build -t corebank-api:latest .
```

### 4. Deploy to Kubernetes

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

## 📝 Detailed Deployment Steps

### Step 1: Kubernetes Cluster Setup

#### Option A: Docker Desktop (macOS/Windows)

1. เปิด Docker Desktop
2. ไปที่ Settings → Kubernetes
3. เลือก "Enable Kubernetes"
4. คลิก "Apply & Restart"
5. รอจนกว่า Kubernetes จะพร้อม

```bash
# ตรวจสอบ cluster
kubectl cluster-info
kubectl get nodes
```

#### Option B: Minikube (Ubuntu/Linux)

```bash
# ติดตั้ง Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start Minikube
minikube start --cpus=4 --memory=4096 --disk-size=20g

# ตรวจสอบ status
minikube status
kubectl get nodes
```

### Step 2: Build Application

```bash
# Build Rust application locally (optional, for testing)
cargo build --release

# Build Docker image
docker build -t corebank-api:latest .

# สำหรับ Minikube, load image เข้า cluster
minikube image load corebank-api:latest
```

### Step 3: Deploy Infrastructure

#### 3.1 Create Namespace

```bash
kubectl apply -f k8s/namespace.yaml
kubectl get namespaces
```

#### 3.2 Deploy PostgreSQL

```bash
# Apply default configuration
kubectl apply -f k8s/postgres/configmap-default.yaml
kubectl apply -f k8s/postgres/configmap-tuned.yaml

# Deploy PostgreSQL StatefulSet
kubectl apply -f k8s/postgres/statefulset.yaml
kubectl apply -f k8s/postgres/service.yaml

# รอให้ PostgreSQL พร้อม
kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 \
  --timeout=300s statefulset/postgres -n corebank

# ตรวจสอบ
kubectl get pods -n corebank
kubectl logs -n corebank postgres-0
```

#### 3.3 Deploy PgBouncer (Optional)

```bash
kubectl apply -f k8s/pgbouncer/configmap.yaml
kubectl apply -f k8s/pgbouncer/deployment.yaml
kubectl apply -f k8s/pgbouncer/service.yaml

# รอให้พร้อม
kubectl wait --for=condition=available --timeout=300s \
  deployment/pgbouncer -n corebank
```

#### 3.4 Deploy Monitoring Stack

```bash
# Prometheus
kubectl apply -f k8s/monitoring/prometheus-configmap.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
kubectl apply -f k8s/monitoring/prometheus-service.yaml

# PostgreSQL Exporter
kubectl apply -f k8s/monitoring/postgres-exporter-deployment.yaml
kubectl apply -f k8s/monitoring/postgres-exporter-service.yaml

# Node Exporter
kubectl apply -f k8s/monitoring/node-exporter-daemonset.yaml
kubectl apply -f k8s/monitoring/node-exporter-service.yaml

# Grafana
kubectl apply -f k8s/monitoring/grafana-datasources-configmap.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards-config.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml
kubectl apply -f k8s/monitoring/grafana-service.yaml

# รอให้ทุกอย่างพร้อม
kubectl wait --for=condition=available --timeout=300s \
  deployment/prometheus -n corebank
kubectl wait --for=condition=available --timeout=300s \
  deployment/grafana -n corebank
```

#### 3.5 Deploy Application

```bash
kubectl apply -f k8s/app/configmap.yaml
kubectl apply -f k8s/app/deployment.yaml
kubectl apply -f k8s/app/service.yaml

# รอให้พร้อม
kubectl wait --for=condition=available --timeout=300s \
  deployment/corebank-api -n corebank
```

### Step 4: Verify Deployment

```bash
# ตรวจสอบ pods ทั้งหมด
kubectl get pods -n corebank

# ควรเห็น:
# NAME                                READY   STATUS    RESTARTS   AGE
# postgres-0                          1/1     Running   0          5m
# corebank-api-xxx                    1/1     Running   0          2m
# corebank-api-xxx                    1/1     Running   0          2m
# corebank-api-xxx                    1/1     Running   0          2m
# prometheus-xxx                      1/1     Running   0          3m
# grafana-xxx                         1/1     Running   0          3m
# postgres-exporter-xxx               1/1     Running   0          3m
# node-exporter-xxx                   1/1     Running   0          3m

# ตรวจสอบ services
kubectl get svc -n corebank
```

### Step 5: Access Services

#### Get Service URLs

```bash
# For Docker Desktop
echo "Grafana: http://localhost:$(kubectl get svc grafana -n corebank -o jsonpath='{.spec.ports[0].nodePort}')"
echo "Prometheus: http://localhost:$(kubectl get svc prometheus -n corebank -o jsonpath='{.spec.ports[0].nodePort}')"

# For Minikube
minikube service grafana -n corebank --url
minikube service prometheus -n corebank --url
```

#### Port Forward API

```bash
kubectl port-forward -n corebank svc/corebank-api 8080:8080
```

#### Test API

```bash
curl http://localhost:8080/health
# Expected: {"status":"healthy","service":"core-banking-api"}
```

### Step 6: Seed Data

```bash
# Port forward PostgreSQL
kubectl port-forward -n corebank svc/postgres 5432:5432 &

# Set environment variable
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/corebank"

# Run seed script
cargo run --bin seed-data

# หรือรันใน Kubernetes
kubectl exec -it -n corebank postgres-0 -- bash
# จากนั้นรัน seed script ภายใน pod
```

## 🔧 Configuration Options

### PostgreSQL Configuration

#### Switch to Tuned Configuration

```bash
./scripts/switch-to-tuned-config.sh
```

#### Manual Switch

```bash
# Edit StatefulSet
kubectl edit statefulset postgres -n corebank

# เปลี่ยน configMap reference จาก
# postgres-config-default
# เป็น
# postgres-config-tuned

# Delete pod to apply
kubectl delete pod postgres-0 -n corebank
```

### Application Configuration

#### Use PgBouncer

```bash
# Edit ConfigMap
kubectl edit configmap app-config -n corebank

# เปลี่ยน DATABASE_URL จาก
# postgresql://postgres:postgres@postgres.corebank.svc.cluster.local:5432/corebank
# เป็น
# postgresql://postgres:postgres@pgbouncer.corebank.svc.cluster.local:6432/corebank

# Restart application
kubectl rollout restart deployment/corebank-api -n corebank
```

#### Adjust Replicas

```bash
# Scale up
kubectl scale deployment corebank-api -n corebank --replicas=5

# Scale down
kubectl scale deployment corebank-api -n corebank --replicas=2
```

## 🧪 Running Tests

### Load Tests in Kubernetes

```bash
# Heavy Read Test
kubectl apply -f k8s/loadtest/job-heavy-read.yaml
kubectl logs -n corebank -f job/loadtest-heavy-read

# Heavy Write Test
kubectl apply -f k8s/loadtest/job-heavy-write.yaml
kubectl logs -n corebank -f job/loadtest-heavy-write

# Mixed Load Test
kubectl apply -f k8s/loadtest/job-mixed-load.yaml
kubectl logs -n corebank -f job/loadtest-mixed-load
```

### Load Tests from Local

```bash
# Port forward API
kubectl port-forward -n corebank svc/corebank-api 8080:8080 &

# Run load tester
cargo run --bin load-tester -- http://localhost:8080 mixed 50 300
```

## 🔍 Monitoring

### Access Grafana

```bash
# Get Grafana URL
kubectl get svc grafana -n corebank

# For Docker Desktop
open http://localhost:<NodePort>

# For Minikube
minikube service grafana -n corebank

# Login: admin/admin
```

### Access Prometheus

```bash
kubectl get svc prometheus -n corebank

# For Docker Desktop
open http://localhost:<NodePort>

# For Minikube
minikube service prometheus -n corebank
```

### View Logs

```bash
# Application logs
kubectl logs -n corebank -l app=corebank-api -f

# PostgreSQL logs
kubectl logs -n corebank postgres-0 -f

# Prometheus logs
kubectl logs -n corebank -l app=prometheus -f
```

## 🐛 Troubleshooting

### PostgreSQL Won't Start

```bash
# Check logs
kubectl logs -n corebank postgres-0

# Check events
kubectl describe pod postgres-0 -n corebank

# Check PVC
kubectl get pvc -n corebank

# Common issues:
# 1. Insufficient resources
# 2. PVC not bound
# 3. Configuration errors
```

### Application Can't Connect to Database

```bash
# Test database connectivity
kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank

# Check service
kubectl get svc postgres -n corebank

# Check DNS
kubectl exec -it -n corebank <app-pod-name> -- nslookup postgres.corebank.svc.cluster.local

# Check application logs
kubectl logs -n corebank -l app=corebank-api
```

### Monitoring Stack Issues

```bash
# Check Prometheus targets
kubectl port-forward -n corebank svc/prometheus 9090:9090
# Open http://localhost:9090/targets

# Check Grafana datasource
# Login to Grafana → Configuration → Data Sources

# Restart monitoring stack
kubectl rollout restart deployment/prometheus -n corebank
kubectl rollout restart deployment/grafana -n corebank
```

### Load Test Failures

```bash
# Check API health
curl http://localhost:8080/health

# Check application logs
kubectl logs -n corebank -l app=corebank-api

# Check database connections
kubectl exec -it -n corebank postgres-0 -- \
  psql -U postgres -d corebank -c "SELECT count(*) FROM pg_stat_activity;"
```

## 🧹 Cleanup

### Delete Everything

```bash
./scripts/cleanup.sh
```

### Selective Cleanup

```bash
# Delete load test jobs
kubectl delete jobs -n corebank -l app=loadtest

# Delete application only
kubectl delete deployment corebank-api -n corebank

# Delete monitoring stack
kubectl delete deployment prometheus grafana -n corebank
kubectl delete deployment postgres-exporter -n corebank
kubectl delete daemonset node-exporter -n corebank
```

## 📊 Resource Requirements

### Minimum Requirements

| Component | CPU | Memory | Disk |
|-----------|-----|--------|------|
| PostgreSQL | 1 core | 2GB | 10GB |
| Application (3 replicas) | 750m | 768MB | - |
| Prometheus | 500m | 512MB | 5GB |
| Grafana | 250m | 256MB | 1GB |
| Exporters | 200m | 192MB | - |
| **Total** | **~2.7 cores** | **~3.7GB** | **~16GB** |

### Recommended Requirements

| Component | CPU | Memory | Disk |
|-----------|-----|--------|------|
| PostgreSQL | 2 cores | 4GB | 20GB |
| Application (3 replicas) | 3 cores | 1.5GB | - |
| Prometheus | 1 core | 1GB | 10GB |
| Grafana | 500m | 512MB | 2GB |
| Exporters | 300m | 256MB | - |
| **Total** | **~7 cores** | **~7.3GB** | **~32GB** |

## 🔐 Security Considerations

### Production Deployment

1. **Change Default Passwords**
```bash
# PostgreSQL
kubectl create secret generic postgres-secret \
  --from-literal=password=<strong-password> \
  -n corebank

# Grafana
kubectl create secret generic grafana-secret \
  --from-literal=admin-password=<strong-password> \
  -n corebank
```

2. **Enable TLS**
- Configure PostgreSQL SSL
- Use cert-manager for certificates
- Enable HTTPS for API

3. **Network Policies**
```bash
kubectl apply -f k8s/network-policies/
```

4. **Resource Limits**
- Set proper resource requests/limits
- Configure Pod Security Policies
- Use RBAC

---

**Deployment Complete! 🎉**
