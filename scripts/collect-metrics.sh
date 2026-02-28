#!/bin/bash

# Script to collect metrics from Prometheus during load test
# Usage: ./collect-metrics.sh <test_type> <start_time> <end_time>

set -e

TEST_TYPE=${1:-"unknown"}
START_TIME=${2:-$(date -u +%s)}
END_TIME=${3:-$(date -u +%s)}

PROMETHEUS_URL="http://localhost:9090"
OUTPUT_DIR="./reports/metrics"

mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
METRICS_FILE="$OUTPUT_DIR/${TEST_TYPE}_metrics_${TIMESTAMP}.json"

echo "Collecting metrics from Prometheus..."
echo "Test Type: $TEST_TYPE"
echo "Time Range: $START_TIME - $END_TIME"
echo ""

# Function to query Prometheus
query_prometheus() {
    local query=$1
    local metric_name=$2
    
    curl -s -G "$PROMETHEUS_URL/api/v1/query" \
        --data-urlencode "query=$query" \
        --data-urlencode "time=$END_TIME" | \
        jq -r ".data.result[0].value[1] // \"N/A\"" 2>/dev/null || echo "N/A"
}

# Function to query Prometheus range
query_prometheus_range() {
    local query=$1
    local metric_name=$2
    local stat=$3  # avg, max, min
    
    local duration=$((END_TIME - START_TIME))
    
    curl -s -G "$PROMETHEUS_URL/api/v1/query" \
        --data-urlencode "query=${stat}_over_time(${query}[${duration}s])" \
        --data-urlencode "time=$END_TIME" | \
        jq -r ".data.result[0].value[1] // \"N/A\"" 2>/dev/null || echo "N/A"
}

echo "Querying metrics..."

# Database Metrics
echo "📊 Database Metrics:"
DB_CONNECTIONS=$(query_prometheus_range 'pg_stat_database_numbackends{datname="corebank"}' 'connections' 'avg')
echo "  Active Connections (avg): $DB_CONNECTIONS"

CACHE_HIT_RATIO=$(query_prometheus_range 'rate(pg_stat_database_blks_hit{datname="corebank"}[1m]) / (rate(pg_stat_database_blks_hit{datname="corebank"}[1m]) + rate(pg_stat_database_blks_read{datname="corebank"}[1m])) * 100' 'cache_hit' 'avg')
echo "  Cache Hit Ratio (avg): $CACHE_HIT_RATIO%"

TPS=$(query_prometheus_range 'rate(pg_stat_database_xact_commit{datname="corebank"}[1m])' 'tps' 'avg')
echo "  TPS (avg): $TPS"

DEADLOCKS=$(query_prometheus_range 'pg_stat_database_deadlocks{datname="corebank"}' 'deadlocks' 'max')
echo "  Deadlocks: $DEADLOCKS"

# System Metrics
echo ""
echo "💻 System Metrics:"
CPU_USAGE=$(query_prometheus_range '100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)' 'cpu' 'avg')
echo "  CPU Usage (avg): $CPU_USAGE%"

MEMORY_USAGE=$(query_prometheus_range '(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024 / 1024 / 1024' 'memory' 'avg')
echo "  Memory Usage (avg): $MEMORY_USAGE GB"

CONTEXT_SWITCHES=$(query_prometheus_range 'rate(node_context_switches_total[1m])' 'context_switches' 'avg')
echo "  Context Switches (avg): $CONTEXT_SWITCHES ops/s"

CONTEXT_SWITCHES_P95=$(query_prometheus_range 'quantile_over_time(0.95, rate(node_context_switches_total[1m])[5m:])' 'context_switches_p95' 'avg')
echo "  Context Switches P95: $CONTEXT_SWITCHES_P95 ops/s"

DISK_READ=$(query_prometheus_range 'rate(node_disk_read_bytes_total[1m]) / 1024 / 1024' 'disk_read' 'avg')
echo "  Disk Read (avg): $DISK_READ MB/s"

DISK_WRITE=$(query_prometheus_range 'rate(node_disk_written_bytes_total[1m]) / 1024 / 1024' 'disk_write' 'avg')
echo "  Disk Write (avg): $DISK_WRITE MB/s"

# PostgreSQL Specific Metrics
echo ""
echo "🗄️  PostgreSQL Metrics:"
SHARED_BUFFERS=$(query_prometheus 'pg_settings_shared_buffers_bytes / 1024 / 1024 / 1024' 'shared_buffers')
echo "  Shared Buffers: $SHARED_BUFFERS GB"

MAX_CONNECTIONS=$(query_prometheus 'pg_settings_max_connections' 'max_connections')
echo "  Max Connections: $MAX_CONNECTIONS"

# Create JSON output
cat > "$METRICS_FILE" <<EOF
{
  "test_type": "$TEST_TYPE",
  "timestamp": "$TIMESTAMP",
  "time_range": {
    "start": $START_TIME,
    "end": $END_TIME,
    "duration": $((END_TIME - START_TIME))
  },
  "database_metrics": {
    "active_connections_avg": "$DB_CONNECTIONS",
    "cache_hit_ratio_avg": "$CACHE_HIT_RATIO",
    "tps_avg": "$TPS",
    "deadlocks": "$DEADLOCKS"
  },
  "system_metrics": {
    "cpu_usage_avg": "$CPU_USAGE",
    "memory_usage_avg_gb": "$MEMORY_USAGE",
    "context_switches_avg": "$CONTEXT_SWITCHES",
    "context_switches_p95": "$CONTEXT_SWITCHES_P95",
    "disk_read_avg_mbps": "$DISK_READ",
    "disk_write_avg_mbps": "$DISK_WRITE"
  },
  "postgresql_config": {
    "shared_buffers_gb": "$SHARED_BUFFERS",
    "max_connections": "$MAX_CONNECTIONS"
  }
}
EOF

echo ""
echo "✅ Metrics saved to: $METRICS_FILE"
echo ""
