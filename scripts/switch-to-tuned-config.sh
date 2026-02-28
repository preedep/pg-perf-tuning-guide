#!/bin/bash

set -e

echo "=========================================="
echo "  Switching to Tuned PostgreSQL Config"
echo "=========================================="
echo ""

# Check if tuned config exists
if ! kubectl get configmap postgres-config-tuned -n corebank &> /dev/null; then
    echo "Creating tuned configuration..."
    kubectl apply -f k8s/postgres/configmap-tuned.yaml
fi

echo "Updating StatefulSet to use tuned configuration..."

# Update environment variables to use tuned config
kubectl set env statefulset/postgres -n corebank \
  --from=configmap/postgres-config-tuned \
  --keys=POSTGRES_DB,POSTGRES_USER,POSTGRES_PASSWORD

# Update volume to use tuned config
kubectl patch statefulset postgres -n corebank --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/volumes/0/configMap/name",
    "value": "postgres-config-tuned"
  }
]'

echo ""
echo "Restarting PostgreSQL to apply new configuration..."
kubectl delete pod postgres-0 -n corebank

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod/postgres-0 -n corebank --timeout=120s

echo ""
echo "=========================================="
echo "  ✅ PostgreSQL Tuned Config Applied"
echo "=========================================="
echo ""
echo "Tuned settings:"
echo "  - max_connections: 200 (was 100)"
echo "  - shared_buffers: 2GB (was 128MB)"
echo "  - effective_cache_size: 6GB (was 4GB)"
echo "  - work_mem: 16MB (was 4MB)"
echo "  - random_page_cost: 1.1 (was 4.0 - optimized for SSD)"
echo "  - effective_io_concurrency: 200 (was 1)"
echo "  - synchronous_commit: off (was on - faster writes)"
echo ""
echo "Run load tests again to compare performance!"
echo ""
