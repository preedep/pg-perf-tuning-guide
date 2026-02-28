#!/bin/bash

set -e

echo "=== PostgreSQL Performance Tuning Guide - Deployment Script ==="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    echo "Waiting for $deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n $namespace
}

# Function to wait for statefulset
wait_for_statefulset() {
    local namespace=$1
    local statefulset=$2
    echo "Waiting for $statefulset to be ready..."
    kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 --timeout=300s statefulset/$statefulset -n $namespace
}

# Create namespace
echo "Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# Deploy PostgreSQL with default config
echo ""
echo "Deploying PostgreSQL with default configuration..."
kubectl apply -f k8s/postgres/configmap-default.yaml
kubectl apply -f k8s/postgres/statefulset.yaml
kubectl apply -f k8s/postgres/service.yaml

wait_for_statefulset corebank postgres

# Deploy PgBouncer (optional)
read -p "Do you want to deploy PgBouncer? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deploying PgBouncer..."
    kubectl apply -f k8s/pgbouncer/configmap.yaml
    kubectl apply -f k8s/pgbouncer/deployment.yaml
    kubectl apply -f k8s/pgbouncer/service.yaml
    wait_for_deployment corebank pgbouncer
fi

# Deploy monitoring stack
echo ""
echo "Deploying monitoring stack (Prometheus, Grafana, Exporters)..."
kubectl apply -f k8s/monitoring/prometheus-configmap.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
kubectl apply -f k8s/monitoring/prometheus-service.yaml

kubectl apply -f k8s/monitoring/postgres-exporter-deployment.yaml
kubectl apply -f k8s/monitoring/postgres-exporter-service.yaml

kubectl apply -f k8s/monitoring/node-exporter-daemonset.yaml
kubectl apply -f k8s/monitoring/node-exporter-service.yaml

kubectl apply -f k8s/monitoring/grafana-datasources-configmap.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards-config.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml
kubectl apply -f k8s/monitoring/grafana-service.yaml

wait_for_deployment corebank prometheus
wait_for_deployment corebank postgres-exporter
wait_for_deployment corebank grafana

# Build and deploy application
echo ""
echo "Building application Docker image..."
docker build -t corebank-api:latest .

echo ""
echo "Deploying application..."
kubectl apply -f k8s/app/configmap.yaml
kubectl apply -f k8s/app/deployment.yaml
kubectl apply -f k8s/app/service.yaml

wait_for_deployment corebank corebank-api

echo ""
echo "=========================================="
echo "=== ✅ Deployment Complete ==="
echo "=========================================="
echo ""

# Get service ports
GRAFANA_PORT=$(kubectl get svc grafana -n corebank -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
PROMETHEUS_PORT=$(kubectl get svc prometheus -n corebank -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
API_PORT=$(kubectl get svc corebank-api -n corebank -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")

# Get pod status
echo "📊 Deployment Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n corebank -o wide
echo ""

echo "🌐 Service Access Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📈 Grafana Dashboard:"
echo "   URL:      http://localhost:${GRAFANA_PORT}"
echo "   Username: admin"
echo "   Password: admin"
echo "   Note:     You'll be prompted to change password on first login"
echo ""
echo "📊 Prometheus:"
echo "   URL:      http://localhost:${PROMETHEUS_PORT}"
echo ""
echo "🔌 Core Banking API:"
if [ "$API_PORT" != "N/A" ]; then
    echo "   URL:      http://localhost:${API_PORT}"
else
    echo "   Port Forward: kubectl port-forward -n corebank svc/corebank-api 8080:8080"
    echo "   Then access:  http://localhost:8080"
fi
echo ""
echo "🗄️  PostgreSQL:"
echo "   Direct:   postgresql://postgres:postgres@localhost:5432/corebank"
echo "   Via Port Forward: kubectl port-forward -n corebank svc/postgres 5432:5432"
echo ""
if kubectl get deployment pgbouncer -n corebank &> /dev/null; then
    echo "🔄 PgBouncer (Connection Pooling):"
    echo "   URL:      postgresql://postgres:postgres@localhost:6432/corebank"
    echo "   Via Port Forward: kubectl port-forward -n corebank svc/pgbouncer 6432:6432"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  Seed Database (100,000 accounts):"
echo "   Option A - Via Kubernetes:"
echo "     kubectl port-forward -n corebank svc/postgres 5432:5432 &"
echo "     export DATABASE_URL='postgresql://postgres:postgres@localhost:5432/corebank'"
echo "     cargo run --bin seed-data"
echo ""
echo "   Option B - Direct to pod:"
echo "     kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank"
echo ""
echo "2️⃣  Run Load Tests:"
echo "   Heavy Read (Balance Inquiry):"
echo "     kubectl apply -f k8s/loadtest/job-heavy-read.yaml"
echo "     kubectl logs -n corebank -f job/loadtest-heavy-read"
echo ""
echo "   Heavy Write (Transfer):"
echo "     kubectl apply -f k8s/loadtest/job-heavy-write.yaml"
echo "     kubectl logs -n corebank -f job/loadtest-heavy-write"
echo ""
echo "   Mixed Load (60% Read, 40% Write):"
echo "     kubectl apply -f k8s/loadtest/job-mixed-load.yaml"
echo "     kubectl logs -n corebank -f job/loadtest-mixed-load"
echo ""
echo "3️⃣  Test API Endpoints:"
echo "   # Balance Inquiry (Heavy Read)"
echo "   curl http://localhost:8080/api/v1/accounts/balance/ACC00000001"
echo ""
echo "   # Transfer (Heavy Write)"
echo "   curl -X POST http://localhost:8080/api/v1/transactions/transfer \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"from_account_number\":\"ACC00000001\",\"to_account_number\":\"ACC00000002\",\"amount\":100.00}'"
echo ""
echo "4️⃣  Switch to Tuned PostgreSQL Config:"
echo "   ./scripts/switch-to-tuned-config.sh"
echo ""
echo "5️⃣  View Grafana Dashboards:"
echo "   - Open http://localhost:${GRAFANA_PORT}"
echo "   - Login with admin/admin"
echo "   - Navigate to Dashboards → PostgreSQL Performance"
echo "   - Monitor: TPS, Latency, Cache Hit Ratio, Connections, Context Switches"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Documentation:"
echo "   - README.md           - Project overview"
echo "   - TESTING_GUIDE.md    - Testing scenarios and metrics"
echo "   - DEPLOYMENT.md       - Detailed deployment guide"
echo "   - LOAD_TEST_SCENARIOS.md - Load test documentation"
echo ""
echo "🧹 Cleanup:"
echo "   ./scripts/cleanup.sh"
echo ""
echo "=========================================="
echo "Happy Performance Testing! 🚀"
echo "=========================================="
echo ""
