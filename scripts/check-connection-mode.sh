#!/bin/bash

set -e

echo "=========================================="
echo "  Current Connection Mode"
echo "=========================================="
echo ""

# Get current DATABASE_URL from ConfigMap
DATABASE_URL=$(kubectl get configmap app-config -n corebank -o jsonpath='{.data.DATABASE_URL}')

echo "DATABASE_URL: $DATABASE_URL"
echo ""

if [[ $DATABASE_URL == *"pgbouncer"* ]]; then
    echo "✅ Mode: PgBouncer"
    echo ""
    echo "Connection flow:"
    echo "  Application → PgBouncer → PostgreSQL"
    echo ""
    
    # Check PgBouncer status
    echo "PgBouncer Status:"
    kubectl get pods -n corebank -l app=pgbouncer
    echo ""
    
    # Get PgBouncer stats if available
    echo "PgBouncer Pool Info:"
    kubectl exec -n corebank $(kubectl get pod -n corebank -l app=pgbouncer -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres -p 6432 pgbouncer -c "SHOW POOLS;" 2>/dev/null || echo "  (Unable to fetch pool stats)"
    
elif [[ $DATABASE_URL == *"postgres.corebank"* ]]; then
    echo "✅ Mode: Direct PostgreSQL"
    echo ""
    echo "Connection flow:"
    echo "  Application → PostgreSQL (direct)"
    echo ""
    
    # Get active connections
    echo "Active PostgreSQL Connections:"
    kubectl exec -n corebank postgres-0 -- psql -U postgres -c "SELECT count(*) as active_connections, state FROM pg_stat_activity WHERE datname = 'corebank' GROUP BY state;" 2>/dev/null || echo "  (Unable to fetch connection stats)"
else
    echo "⚠️  Unknown connection mode"
fi

echo ""
echo "Application Pods:"
kubectl get pods -n corebank -l app=corebank-api

echo ""
echo "=========================================="
echo ""
echo "To switch connection mode:"
echo "  PgBouncer:  ./scripts/switch-to-pgbouncer.sh"
echo "  Direct:     ./scripts/switch-to-direct.sh"
echo ""
