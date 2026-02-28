#!/bin/bash

set -e

# Default values
TEST_TYPE="mixed"
DURATION=60
CONCURRENT_USERS=10

# Parse arguments
if [ $# -ge 1 ]; then
    TEST_TYPE=$1
fi

if [ $# -ge 2 ]; then
    DURATION=$2
fi

if [ $# -ge 3 ]; then
    CONCURRENT_USERS=$3
fi

# Validate test type
if [[ ! "$TEST_TYPE" =~ ^(heavy-read|heavy-write|mixed)$ ]]; then
    echo "❌ Error: Invalid test type '$TEST_TYPE'"
    echo ""
    echo "Usage: $0 [test-type] [duration] [concurrent-users]"
    echo ""
    echo "Test types:"
    echo "  heavy-read   - Read-heavy workload (balance queries)"
    echo "  heavy-write  - Write-heavy workload (transfers)"
    echo "  mixed        - Mixed workload (60% read, 40% write)"
    echo ""
    echo "Examples:"
    echo "  $0 heavy-read 60 10      # 60 seconds, 10 concurrent users"
    echo "  $0 heavy-write 120 20    # 120 seconds, 20 concurrent users"
    echo "  $0 mixed 300 50          # 300 seconds, 50 concurrent users"
    exit 1
fi

echo "=========================================="
echo "  PostgreSQL Performance Load Test"
echo "=========================================="
echo ""
echo "Test Configuration:"
echo "  Type:              $TEST_TYPE"
echo "  Duration:          $DURATION seconds"
echo "  Concurrent Users:  $CONCURRENT_USERS"
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

# Display Grafana info
echo "📊 Monitor performance in Grafana:"
echo "   http://localhost:30030/d/postgresql-perf/postgresql-performance-tuning-dashboard"
echo ""

# Countdown
echo "Starting load test in 3 seconds..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
echo ""
echo "🚀 Load test started!"
echo "=========================================="
echo ""

# Run load test
# load-tester runs inside the pod, use service name for internal communication
kubectl exec -n corebank $POD_NAME -- /app/load-tester http://corebank-api:8080 $TEST_TYPE $CONCURRENT_USERS $DURATION

echo ""
echo "=========================================="
echo "✅ Load test completed!"
echo "=========================================="
echo ""
echo "📊 View detailed metrics in Grafana:"
echo "   http://localhost:30030/d/postgresql-perf/postgresql-performance-tuning-dashboard"
echo ""
echo "Key metrics to check:"
echo "  - TPS (Transactions Per Second)"
echo "  - Cache Hit Ratio (should be >95%)"
echo "  - Context Switches"
echo "  - CPU Usage & IO Wait"
echo "  - Memory Usage"
echo "  - Active Connections"
echo "  - Deadlocks (should be 0)"
echo ""
