#!/bin/bash

set -e

echo "=========================================="
echo "  Switch to Direct PostgreSQL Connection"
echo "=========================================="
echo ""

echo "Updating application ConfigMap to use direct PostgreSQL..."

# Update ConfigMap
kubectl patch configmap app-config -n corebank --type merge -p '{
  "data": {
    "DATABASE_URL": "postgresql://postgres:postgres@postgres.corebank.svc.cluster.local:5432/corebank"
  }
}'

echo ""
echo "Restarting application pods to apply changes..."
kubectl rollout restart deployment corebank-api -n corebank

echo ""
echo "Waiting for application pods to be ready..."
kubectl rollout status deployment corebank-api -n corebank --timeout=120s

echo ""
echo "✅ Successfully switched to direct PostgreSQL!"
echo ""
echo "Verification:"
kubectl exec -n corebank $(kubectl get pod -n corebank -l app=corebank-api -o jsonpath='{.items[0].metadata.name}') -- env | grep DATABASE_URL

echo ""
echo "=========================================="
echo "  Application is now using Direct PostgreSQL"
echo "=========================================="
echo ""
echo "Connection flow:"
echo "  Application → PostgreSQL (direct)"
echo ""
echo "You can now run performance tests:"
echo "  ./scripts/performance-test-suite.sh"
echo ""
