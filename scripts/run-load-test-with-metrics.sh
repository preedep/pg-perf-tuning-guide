#!/bin/bash

# Run load test and collect metrics from Prometheus
# Usage: ./run-load-test-with-metrics.sh <test_type> <duration> <concurrent_users>

set -e

TEST_TYPE=${1:-heavy-read}
DURATION=${2:-60}
CONCURRENT_USERS=${3:-20}

echo "=========================================="
echo "  Load Test with Metrics Collection"
echo "=========================================="
echo ""
echo "Test Type: $TEST_TYPE"
echo "Duration: ${DURATION}s"
echo "Concurrent Users: $CONCURRENT_USERS"
echo ""

# Record start time
START_TIME=$(date +%s)

# Ensure Prometheus port-forward is running
echo "Checking Prometheus connection..."
if ! curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "Starting Prometheus port-forward..."
    kubectl port-forward -n corebank svc/prometheus 9090:9090 > /dev/null 2>&1 &
    PORTFORWARD_PID=$!
    sleep 3
    
    if ! curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        echo "❌ Error: Could not connect to Prometheus"
        echo "   Please ensure Prometheus is running in the cluster"
        exit 1
    fi
fi

echo "✅ Prometheus connected"
echo ""

# Run the load test
echo "Running load test..."
./scripts/run-load-test.sh "$TEST_TYPE" "$DURATION" "$CONCURRENT_USERS"

# Record end time
END_TIME=$(date +%s)

# Copy CSV report from container
echo ""
echo "Copying CSV report from container..."
POD_NAME=$(kubectl get pod -n corebank -l app=corebank-api -o jsonpath='{.items[0].metadata.name}')
REMOTE_CSV=$(kubectl exec -n corebank $POD_NAME -- sh -c "ls -t /tmp/loadtest_${TEST_TYPE}_*.csv 2>/dev/null | head -n 1" 2>/dev/null || echo "")

if [ -n "$REMOTE_CSV" ]; then
    mkdir -p /tmp
    kubectl cp "corebank/${POD_NAME}:${REMOTE_CSV}" "${REMOTE_CSV}" 2>/dev/null
    if [ -f "$REMOTE_CSV" ]; then
        echo "✅ CSV copied: $REMOTE_CSV"
    else
        echo "⚠️  Warning: Could not copy CSV file"
    fi
else
    echo "⚠️  Warning: No CSV file found in container"
fi

echo ""
echo "Collecting metrics from Prometheus..."
./scripts/collect-metrics.sh "$TEST_TYPE" "$START_TIME" "$END_TIME"

# Find the generated CSV report
LATEST_CSV=$(ls -t /tmp/loadtest_${TEST_TYPE}_*.csv 2>/dev/null | head -n 1)
LATEST_METRICS=$(ls -t ./reports/metrics/${TEST_TYPE}_metrics_*.json 2>/dev/null | head -n 1)

if [ -n "$LATEST_CSV" ] && [ -n "$LATEST_METRICS" ]; then
    echo ""
    echo "Generating enhanced report..."
    ./scripts/generate-enhanced-report.sh "$TEST_TYPE" "$LATEST_CSV" "$LATEST_METRICS"
    
    LATEST_REPORT=$(ls -t ./reports/${TEST_TYPE}_report_*.csv 2>/dev/null | head -n 1)
    
    echo ""
    echo "=========================================="
    echo "✅ Test completed with metrics!"
    echo "=========================================="
    echo ""
    echo "📊 Professional Report Generated:"
    echo "  📄 $LATEST_REPORT"
    echo ""
    echo "  (Source files: $LATEST_CSV, $LATEST_METRICS)"
    echo ""
else
    echo ""
    echo "⚠️  Warning: Could not find CSV or metrics files"
    echo "   Application CSV: $LATEST_CSV"
    echo "   Metrics JSON: $LATEST_METRICS"
fi

# Cleanup port-forward if we started it
if [ -n "$PORTFORWARD_PID" ]; then
    kill $PORTFORWARD_PID 2>/dev/null || true
fi

echo ""
