#!/bin/bash

set -e

echo "=========================================="
echo "  Switch to PgBouncer Connection"
echo "=========================================="
echo ""

# Check if PgBouncer is deployed
if ! kubectl get deployment pgbouncer -n corebank &> /dev/null; then
    echo "❌ Error: PgBouncer is not deployed"
    echo ""
    echo "Please deploy PgBouncer first:"
    echo "  kubectl apply -f k8s/pgbouncer/"
    exit 1
fi

# Check if PgBouncer is ready
echo "Checking PgBouncer status..."
kubectl wait --for=condition=ready pod -l app=pgbouncer -n corebank --timeout=30s

echo ""
echo "Updating application ConfigMap to use PgBouncer..."

# Update ConfigMap
kubectl patch configmap app-config -n corebank --type merge -p '{
  "data": {
    "DATABASE_URL": "postgresql://postgres:postgres@pgbouncer.corebank.svc.cluster.local:6432/corebank"
  }
}'

echo ""
echo "Restarting application pods to apply changes..."
kubectl rollout restart deployment corebank-api -n corebank

echo ""
echo "Waiting for application pods to be ready..."
kubectl rollout status deployment corebank-api -n corebank --timeout=120s

echo ""
echo "✅ Successfully switched to PgBouncer!"
echo ""
echo "Verification:"
kubectl exec -n corebank $(kubectl get pod -n corebank -l app=corebank-api -o jsonpath='{.items[0].metadata.name}') -- env | grep DATABASE_URL

echo ""
echo "=========================================="
echo "  Application is now using PgBouncer"
echo "=========================================="
echo ""
echo "Connection flow:"
echo "  Application → PgBouncer → PostgreSQL"
echo ""
echo "You can now run performance tests:"
echo "  ./scripts/performance-test-suite.sh"
echo ""
