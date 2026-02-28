#!/bin/bash

set -e

echo "=========================================="
echo "  Collecting Performance Test Reports"
echo "=========================================="
echo ""

# Create reports directory if it doesn't exist
mkdir -p reports

# Get pod name
POD_NAME=$(kubectl get pod -n corebank -l app=corebank-api -o jsonpath='{.items[0].metadata.name}')
echo "Using pod: $POD_NAME"
echo ""

# List available reports
echo "Available reports in pod:"
kubectl exec -n corebank $POD_NAME -- ls -lh /tmp/loadtest_*.csv 2>/dev/null || echo "No reports found yet"
echo ""

# Copy all CSV reports from pod
echo "Copying reports from pod to ./reports/ ..."
REPORT_COUNT=0

for report in $(kubectl exec -n corebank $POD_NAME -- ls /tmp/loadtest_*.csv 2>/dev/null); do
    BASENAME=$(basename $report)
    kubectl cp corebank/$POD_NAME:$report ./reports/$BASENAME
    echo "  ✅ Copied: $BASENAME"
    REPORT_COUNT=$((REPORT_COUNT + 1))
done

echo ""
if [ $REPORT_COUNT -eq 0 ]; then
    echo "⚠️  No reports found. Run performance tests first:"
    echo "   ./scripts/run-load-test.sh mixed 60 10"
else
    echo "=========================================="
    echo "  ✅ Collected $REPORT_COUNT report(s)"
    echo "=========================================="
    echo ""
    echo "Reports saved to: ./reports/"
    ls -lh ./reports/loadtest_*.csv 2>/dev/null || true
    echo ""
    echo "📊 Open reports with:"
    echo "   - Excel / Google Sheets"
    echo "   - cat reports/loadtest_*.csv"
    echo "   - ./scripts/generate-summary-report.sh"
fi
echo ""
