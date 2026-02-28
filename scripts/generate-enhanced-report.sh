#!/bin/bash

# Generate professional consolidated CSV report with all metrics
# Usage: ./generate-enhanced-report.sh <test_type> <app_csv> <metrics_json>

set -e

TEST_TYPE=${1:-"unknown"}
APP_CSV=${2:-""}
METRICS_JSON=${3:-""}

if [ -z "$APP_CSV" ] || [ -z "$METRICS_JSON" ]; then
    echo "Usage: $0 <test_type> <app_csv_file> <metrics_json_file>"
    exit 1
fi

if [ ! -f "$APP_CSV" ]; then
    echo "Error: Application CSV file not found: $APP_CSV"
    exit 1
fi

if [ ! -f "$METRICS_JSON" ]; then
    echo "Error: Metrics JSON file not found: $METRICS_JSON"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="./reports"
mkdir -p "$OUTPUT_DIR"

REPORT_CSV="$OUTPUT_DIR/${TEST_TYPE}_report_${TIMESTAMP}.csv"

echo "Generating professional consolidated report..."
echo "  Test Type: $TEST_TYPE"
echo "  Application CSV: $APP_CSV"
echo "  Metrics JSON: $METRICS_JSON"
echo "  Output: $REPORT_CSV"
echo ""

# Extract metrics from JSON
DB_CONNECTIONS=$(jq -r '.database_metrics.active_connections_avg // "N/A"' "$METRICS_JSON")
CACHE_HIT_RATIO=$(jq -r '.database_metrics.cache_hit_ratio_avg // "N/A"' "$METRICS_JSON")
DB_TPS=$(jq -r '.database_metrics.tps_avg // "N/A"' "$METRICS_JSON")
DEADLOCKS=$(jq -r '.database_metrics.deadlocks // "0"' "$METRICS_JSON")

CPU_USAGE=$(jq -r '.system_metrics.cpu_usage_avg // "N/A"' "$METRICS_JSON")
MEMORY_USAGE=$(jq -r '.system_metrics.memory_usage_avg_gb // "N/A"' "$METRICS_JSON")
CONTEXT_SWITCHES=$(jq -r '.system_metrics.context_switches_avg // "N/A"' "$METRICS_JSON")
CONTEXT_SWITCHES_P95=$(jq -r '.system_metrics.context_switches_p95 // "N/A"' "$METRICS_JSON")
DISK_READ=$(jq -r '.system_metrics.disk_read_avg_mbps // "N/A"' "$METRICS_JSON")
DISK_WRITE=$(jq -r '.system_metrics.disk_write_avg_mbps // "N/A"' "$METRICS_JSON")

SHARED_BUFFERS=$(jq -r '.postgresql_config.shared_buffers_gb // "N/A"' "$METRICS_JSON")
MAX_CONNECTIONS=$(jq -r '.postgresql_config.max_connections // "N/A"' "$METRICS_JSON")

# Extract application metrics from CSV
APP_TOTAL_REQUESTS=$(grep "^Total Requests," "$APP_CSV" | cut -d',' -f2)
APP_SUCCESS_RATE=$(grep "^Success Rate," "$APP_CSV" | cut -d',' -f2)
APP_TPS=$(grep "^TPS" "$APP_CSV" | cut -d',' -f2)
APP_MIN_LATENCY=$(grep "^Minimum Latency," "$APP_CSV" | cut -d',' -f2)
APP_AVG_LATENCY=$(grep "^Average Latency," "$APP_CSV" | cut -d',' -f2)
APP_P95_LATENCY=$(grep "^P95 Latency," "$APP_CSV" | cut -d',' -f2 2>/dev/null || echo "N/A")
APP_MAX_LATENCY=$(grep "^Maximum Latency," "$APP_CSV" | cut -d',' -f2)
APP_CONCURRENCY=$(grep "^Concurrency," "$APP_CSV" | cut -d',' -f2)
APP_DURATION=$(grep "^Duration" "$APP_CSV" | cut -d',' -f2)

# Create professional consolidated CSV report
cat > "$REPORT_CSV" <<EOF
===============================================================================
POSTGRESQL PERFORMANCE TEST REPORT
===============================================================================
Generated,$(date +"%Y-%m-%d %H:%M:%S")
Test Type,$TEST_TYPE
Test Duration,$APP_DURATION seconds
Concurrent Users,$APP_CONCURRENCY
,
===============================================================================
SECTION 1: EXECUTIVE SUMMARY
===============================================================================
,

Key Performance Indicators
Metric,Value,Unit,Status
Application Throughput,$APP_TPS,requests/sec,Primary KPI
Success Rate,$APP_SUCCESS_RATE,%,✓ Target: 100%
Average Latency,$APP_AVG_LATENCY,ms,Lower is better
P95 Latency,$APP_P95_LATENCY,ms,95% of requests
Cache Hit Ratio,$CACHE_HIT_RATIO,%,Target >95%
Database Connections,$DB_CONNECTIONS,connections,Active backends
,
===============================================================================
SECTION 2: APPLICATION METRICS (Load Tester)
===============================================================================
,
Throughput & Volume
Metric,Value,Unit
Total Requests,$APP_TOTAL_REQUESTS,requests
Requests Per Second (TPS),$APP_TPS,req/s
Success Rate,$APP_SUCCESS_RATE,%
,
Latency Distribution
Metric,Value (ms),Percentile
Minimum,$APP_MIN_LATENCY,0th (best case)
Average,$APP_AVG_LATENCY,50th (typical)
P95,$APP_P95_LATENCY,95th (most requests)
Maximum,$APP_MAX_LATENCY,100th (worst case)
,
===============================================================================
SECTION 3: DATABASE METRICS (PostgreSQL via Prometheus)
===============================================================================
,
Connection & Transaction Metrics
Metric,Value,Unit,Note
Active Connections (avg),$DB_CONNECTIONS,connections,Backend processes
Database TPS (avg),$DB_TPS,transactions/s,Committed transactions
Deadlocks,$DEADLOCKS,count,Should be 0
Cache Hit Ratio (avg),$CACHE_HIT_RATIO,%,Target >95%

PostgreSQL Configuration
Parameter,Value,Unit
Max Connections,$MAX_CONNECTIONS,connections
Shared Buffers,$SHARED_BUFFERS,GB
,
===============================================================================
SECTION 4: SYSTEM RESOURCES (Node Exporter via Prometheus)
===============================================================================
,
CPU & Memory
Metric,Value,Unit,Note
CPU Usage (avg),$CPU_USAGE,%,Overall CPU utilization
Memory Usage (avg),$MEMORY_USAGE,GB,RAM consumption
,
Context Switching (Performance Impact)
Metric,Value,Unit,Note
Context Switches (avg),$CONTEXT_SWITCHES,ops/s,Average rate
Context Switches (P95),$CONTEXT_SWITCHES_P95,ops/s,95th percentile
,
Disk I/O
Metric,Value,Unit
Disk Read (avg),$DISK_READ,MB/s
Disk Write (avg),$DISK_WRITE,MB/s
,
===============================================================================
SECTION 5: PERFORMANCE ANALYSIS
===============================================================================
,
Application vs Database Perspective
Metric,Application View,Database View,Explanation
Throughput,$APP_TPS req/s,$DB_TPS tx/s,App TPS = HTTP requests; DB TPS = committed transactions
Connections,N/A,$DB_CONNECTIONS,Backend connections to PostgreSQL
Latency (P95),$APP_P95_LATENCY ms,N/A,End-to-end user experience
Cache Efficiency,N/A,$CACHE_HIT_RATIO%,Higher = less disk I/O
,
Resource Utilization
Resource,Usage,Status,Recommendation
CPU,$CPU_USAGE%,Monitored,Target <70% for headroom
Memory,$MEMORY_USAGE GB,Monitored,Ensure sufficient for shared_buffers
Context Switches,$CONTEXT_SWITCHES_P95 ops/s,Monitored,Lower is better for given throughput
,
===============================================================================
SECTION 6: NOTES & METHODOLOGY
===============================================================================
,
Data Collection Methods
Source,Metrics Collected,Method
Load Tester,Application TPS / Latency / Success Rate,Direct HTTP measurement
Prometheus,Database connections / TPS / Cache hit ratio,PostgreSQL Exporter
Prometheus,CPU / Memory / Context switches / Disk I/O,Node Exporter
,
Metric Definitions
Definition,Description
TPS (Application),HTTP requests per second processed by application
TPS (Database),Database transactions committed per second
P95 Latency,95% of requests completed within this time
Context Switches,OS scheduler context switches (lower is better)
Cache Hit Ratio,Percentage of data found in memory vs disk
,
Performance Targets
Target,Value,Note
Success Rate,100%,No errors
Cache Hit Ratio,>95%,Minimize disk I/O
CPU Usage,<70%,Leave headroom for spikes
Deadlocks,0,No transaction conflicts
,
===============================================================================
END OF REPORT
===============================================================================
EOF

echo "✅ Professional consolidated report generated: $REPORT_CSV"
echo ""
echo "📊 Professional Report Sections:"
echo "  1️⃣  Executive Summary (KPIs)"
echo "  2️⃣  Application Metrics (throughput, latency)"
echo "  3️⃣  Database Metrics (connections, cache, transactions)"
echo "  4️⃣  System Resources (CPU, memory, I/O)"
echo "  5️⃣  Performance Analysis (app vs database view)"
echo "  6️⃣  Notes & Methodology"
echo ""
echo "📁 Single consolidated CSV file - ready for Excel/analysis!"
echo ""
