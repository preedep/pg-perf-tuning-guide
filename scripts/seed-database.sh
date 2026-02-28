#!/bin/bash

set -e

echo "=========================================="
echo "  Seeding Database with Test Data"
echo "=========================================="
echo ""

# Check if API pod is running
echo "Checking if corebank-api is deployed..."
if ! kubectl get deployment corebank-api -n corebank &> /dev/null; then
    echo "❌ Error: corebank-api deployment not found"
    echo "Please run ./scripts/deploy.sh first"
    exit 1
fi

# Wait for pod to be ready
echo "Waiting for corebank-api pod to be ready..."
kubectl wait --for=condition=ready pod -l app=corebank-api -n corebank --timeout=60s

# Get pod name
POD_NAME=$(kubectl get pod -n corebank -l app=corebank-api -o jsonpath='{.items[0].metadata.name}')
echo "Using pod: $POD_NAME"
echo ""

# Run seed-data
echo "Starting to seed 100,000 accounts..."
echo "This will take approximately 2-3 minutes..."
echo ""

kubectl exec -n corebank $POD_NAME -- sh -c 'DATABASE_URL="postgresql://postgres:postgres@postgres.corebank.svc.cluster.local:5432/corebank" /app/seed-data'

echo ""
echo "✅ Database seeding completed!"
echo ""
echo "Verifying data..."
kubectl exec -n corebank postgres-0 -- psql -U postgres -d corebank -c "SELECT COUNT(*) as total_accounts FROM accounts;"

echo ""
echo "=========================================="
echo "  Ready for Load Testing!"
echo "=========================================="
