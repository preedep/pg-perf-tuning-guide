#!/bin/bash

set -e

echo "=========================================="
echo "  PostgreSQL Performance Test Suite"
echo "=========================================="
echo ""
echo "This script will run a comprehensive performance test suite:"
echo "  1. Seed database with 100,000 accounts"
echo "  2. Run heavy-read test (60s, 20 users)"
echo "  3. Wait 30s for cooldown"
echo "  4. Run heavy-write test (60s, 20 users)"
echo "  5. Wait 30s for cooldown"
echo "  6. Run mixed load test (120s, 100 users) - Peak Load"
echo ""
echo "Total estimated time: ~8 minutes"
echo ""
echo "NOTE: Peak load (100 users) demonstrates that max_connections"
echo "      alone doesn't improve performance due to PostgreSQL's"
echo "      process-based architecture. CPU becomes the bottleneck."
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "=========================================="
echo "  Step 1/6: Seeding Database"
echo "=========================================="
./scripts/seed-database.sh

echo ""
echo "Waiting 10 seconds before starting tests..."
sleep 10

echo ""
echo "=========================================="
echo "  Step 2/6: Heavy Read Test"
echo "=========================================="
./scripts/run-load-test.sh heavy-read 60 20

echo ""
echo "Cooldown period (30 seconds)..."
sleep 30

echo ""
echo "=========================================="
echo "  Step 3/6: Heavy Write Test"
echo "=========================================="
./scripts/run-load-test.sh heavy-write 60 20

echo ""
echo "Cooldown period (30 seconds)..."
sleep 30

echo ""
echo "=========================================="
echo "  Step 4/6: Mixed Load Test (Peak: 100 users)"
echo "=========================================="
echo "⚠️  This will demonstrate CPU bottleneck with process-based model"
echo ""
./scripts/run-load-test.sh mixed 120 100

echo ""
echo "=========================================="
echo "  Performance Test Suite Completed! ✅"
echo "=========================================="
echo ""
echo "📊 Review results in Grafana:"
echo "   http://localhost:30030/d/postgresql-perf/postgresql-performance-tuning-dashboard"
echo ""
echo "📈 Performance Tuning Recommendations:"
echo ""
echo "Based on the metrics, consider tuning these PostgreSQL parameters:"
echo ""
echo "If Cache Hit Ratio < 95%:"
echo "  - Increase shared_buffers"
echo "  - Increase effective_cache_size"
echo ""
echo "If CPU IO Wait is high:"
echo "  - Increase effective_io_concurrency"
echo "  - Decrease random_page_cost (for SSD)"
echo "  - Check disk performance"
echo ""
echo "If Context Switches are very high:"
echo "  - Reduce max_connections"
echo "  - Use connection pooling (PgBouncer is already configured)"
echo ""
echo "If Memory usage is high:"
echo "  - Adjust work_mem"
echo "  - Adjust maintenance_work_mem"
echo ""
echo "If Deadlocks occur:"
echo "  - Review application logic"
echo "  - Adjust deadlock_timeout"
echo ""

echo "=========================================="
echo "  Collecting Performance Reports"
echo "=========================================="
echo ""

# Collect all CSV reports from the pod
./scripts/collect-reports.sh

echo ""
echo "=========================================="
echo "  Generating Summary Report"
echo "=========================================="
echo ""

# Generate consolidated summary report
./scripts/generate-summary-report.sh

echo ""
echo "=========================================="
echo "  📊 All Reports Ready!"
echo "=========================================="
echo ""
echo "Individual test reports:"
ls -lh ./reports/loadtest_*.csv 2>/dev/null | grep -v SUMMARY || echo "  No individual reports found"
echo ""
echo "Summary report:"
ls -lh ./reports/SUMMARY_*.csv 2>/dev/null || echo "  No summary report found"
echo ""
echo "📁 All reports saved in: ./reports/"
echo ""
