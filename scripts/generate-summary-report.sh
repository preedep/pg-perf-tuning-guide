#!/bin/bash

set -e

echo "=========================================="
echo "  Performance Test Summary Report"
echo "=========================================="
echo ""

if [ ! -d "reports" ] || [ -z "$(ls -A reports/loadtest_*.csv 2>/dev/null)" ]; then
    echo "❌ No reports found in ./reports/"
    echo "   Run: ./scripts/collect-reports.sh"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUMMARY_FILE="reports/SUMMARY_${TIMESTAMP}.csv"

# Create summary header
cat > $SUMMARY_FILE << 'EOF'
PostgreSQL Performance Test - Consolidated Summary Report
Generated,TIMESTAMP_PLACEHOLDER

Test Comparison
Test Name,Test Type,Concurrency,Duration (s),Total Requests,Success Rate (%),TPS,Avg Latency (ms),Max Latency (ms),Status
EOF

# Replace timestamp
sed -i.bak "s/TIMESTAMP_PLACEHOLDER/$(date '+%Y-%m-%d %H:%M:%S')/" $SUMMARY_FILE
rm -f $SUMMARY_FILE.bak

# Process each report
for report in reports/loadtest_*.csv; do
    if [ -f "$report" ]; then
        BASENAME=$(basename $report .csv)
        
        # Extract test type from filename (e.g., loadtest_heavy-read_20260228_103045.csv)
        TEST_TYPE=$(echo $BASENAME | cut -d'_' -f2)
        TIMESTAMP=$(echo $BASENAME | cut -d'_' -f3-4)
        
        # Extract metrics from CSV
        CONCURRENCY=$(grep "^Concurrency," "$report" | cut -d',' -f2)
        DURATION=$(grep "^Duration (seconds)," "$report" | cut -d',' -f2)
        TOTAL_REQ=$(grep "^Total Requests," "$report" | cut -d',' -f2)
        SUCCESS_RATE=$(grep "^Success Rate," "$report" | cut -d',' -f2)
        TPS=$(grep "^TPS" "$report" | cut -d',' -f2)
        AVG_LATENCY=$(grep "^Average Latency," "$report" | tail -1 | cut -d',' -f2)
        MAX_LATENCY=$(grep "^Maximum Latency," "$report" | tail -1 | cut -d',' -f2)
        
        # Determine overall status
        SUCCESS_STATUS=$(grep "^Success Rate," "$report" | grep "Performance Indicators" -A 10 | grep "^Success Rate," | cut -d',' -f2)
        LATENCY_STATUS=$(grep "^Average Latency," "$report" | grep "Performance Indicators" -A 10 | grep "^Average Latency," | cut -d',' -f2)
        TPS_STATUS=$(grep "^Throughput" "$report" | cut -d',' -f2)
        
        # Overall status (worst of the three)
        if [[ "$SUCCESS_STATUS" == "POOR" ]] || [[ "$LATENCY_STATUS" == "POOR" ]] || [[ "$TPS_STATUS" == "POOR" ]]; then
            OVERALL="POOR"
        elif [[ "$SUCCESS_STATUS" == "ACCEPTABLE" ]] || [[ "$LATENCY_STATUS" == "ACCEPTABLE" ]] || [[ "$TPS_STATUS" == "ACCEPTABLE" ]]; then
            OVERALL="ACCEPTABLE"
        elif [[ "$SUCCESS_STATUS" == "GOOD" ]] || [[ "$LATENCY_STATUS" == "GOOD" ]] || [[ "$TPS_STATUS" == "GOOD" ]]; then
            OVERALL="GOOD"
        else
            OVERALL="EXCELLENT"
        fi
        
        # Append to summary
        echo "${BASENAME},${TEST_TYPE},${CONCURRENCY},${DURATION},${TOTAL_REQ},${SUCCESS_RATE},${TPS},${AVG_LATENCY},${MAX_LATENCY},${OVERALL}" >> $SUMMARY_FILE
    fi
done

# Add recommendations section
cat >> $SUMMARY_FILE << 'EOF'

Performance Recommendations
Category,Recommendation,Priority
EOF

# Analyze and add recommendations (simplified)
echo "Cache Hit Ratio,Monitor pg_stat_database cache hit ratio - should be >95%,HIGH" >> $SUMMARY_FILE
echo "Connection Pooling,Consider using PgBouncer if max_connections is reached,MEDIUM" >> $SUMMARY_FILE
echo "Indexing,Review slow queries and add appropriate indexes,HIGH" >> $SUMMARY_FILE
echo "Autovacuum,Monitor table bloat and tune autovacuum settings,MEDIUM" >> $SUMMARY_FILE
echo "Hardware,Consider SSD storage for better random_page_cost,HIGH" >> $SUMMARY_FILE

cat >> $SUMMARY_FILE << 'EOF'

Status Legend
Status,Success Rate,Avg Latency,TPS
EXCELLENT,>=99.5%,<50ms,>=1000
GOOD,>=99.0%,<100ms,>=500
ACCEPTABLE,>=95.0%,<200ms,>=100
POOR,<95.0%,>=200ms,<100

End of Summary Report
EOF

echo "✅ Summary report generated: $SUMMARY_FILE"
echo ""
echo "📊 Report Contents:"
echo "   - Test comparison across all runs"
echo "   - Performance indicators"
echo "   - Recommendations"
echo ""
echo "View with:"
echo "   cat $SUMMARY_FILE"
echo "   open $SUMMARY_FILE  # macOS"
echo ""
