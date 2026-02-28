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
echo "=== Deployment Complete ==="
echo ""
echo "Services:"
echo "  - Grafana: http://localhost:$(kubectl get svc grafana -n corebank -o jsonpath='{.spec.ports[0].nodePort}')"
echo "  - Prometheus: http://localhost:$(kubectl get svc prometheus -n corebank -o jsonpath='{.spec.ports[0].nodePort}')"
echo ""
echo "To access the API, run:"
echo "  kubectl port-forward -n corebank svc/corebank-api 8080:8080"
echo ""
echo "To seed data (100k accounts), run:"
echo "  kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank"
echo "  Or build and run: cargo run --bin seed-data"
echo ""
echo "To run load tests:"
echo "  kubectl apply -f k8s/loadtest/job-heavy-read.yaml"
echo "  kubectl apply -f k8s/loadtest/job-heavy-write.yaml"
echo "  kubectl apply -f k8s/loadtest/job-mixed-load.yaml"
echo ""
