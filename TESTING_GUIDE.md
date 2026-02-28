# PostgreSQL Performance Testing Guide

คู่มือการทดสอบประสิทธิภาพ PostgreSQL อย่างละเอียด

## 📋 Table of Contents

1. [การเตรียมความพร้อม](#การเตรียมความพร้อม)
2. [Test Scenarios](#test-scenarios)
3. [Metrics to Monitor](#metrics-to-monitor)
4. [Performance Comparison](#performance-comparison)
5. [Best Practices](#best-practices)

## การเตรียมความพร้อม

### 1. ตรวจสอบ Cluster Status

```bash
# ตรวจสอบว่า pods ทั้งหมดทำงาน
kubectl get pods -n corebank

# ควรเห็น:
# - postgres-0 (Running)
# - corebank-api-xxx (Running, 3 replicas)
# - prometheus-xxx (Running)
# - grafana-xxx (Running)
# - postgres-exporter-xxx (Running)
# - node-exporter-xxx (Running)
```

### 2. Seed ข้อมูล

```bash
# Port forward PostgreSQL
kubectl port-forward -n corebank svc/postgres 5432:5432 &

# Seed 100,000 accounts
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/corebank"
cargo run --bin seed-data

# ตรวจสอบจำนวนข้อมูล
kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank -c "SELECT COUNT(*) FROM accounts;"
```

### 3. เปิด Grafana

```bash
# ดู NodePort
kubectl get svc -n corebank grafana

# เข้าถึงผ่าน browser
# http://localhost:<NodePort>
# Login: admin/admin
```

## Test Scenarios

### Scenario 1: Baseline Performance (Default Config)

**วัตถุประสงค์**: วัดประสิทธิภาพพื้นฐานของ PostgreSQL ด้วย default configuration

#### Steps:

1. **ตรวจสอบ Configuration**
```bash
kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank -c "SHOW shared_buffers;"
kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank -c "SHOW max_connections;"
```

2. **รัน Heavy Read Test**
```bash
kubectl apply -f k8s/loadtest/job-heavy-read.yaml
kubectl logs -n corebank -f job/loadtest-heavy-read
```

3. **บันทึกผลลัพธ์**
- TPS (Transactions Per Second)
- Average Latency
- Min/Max Latency
- Success Rate
- CPU Usage (จาก Grafana)
- Memory Usage (จาก Grafana)
- Context Switches (จาก Grafana)

4. **รัน Heavy Write Test**
```bash
kubectl delete job -n corebank loadtest-heavy-read
kubectl apply -f k8s/loadtest/job-heavy-write.yaml
kubectl logs -n corebank -f job/loadtest-heavy-write
```

5. **รัน Mixed Load Test**
```bash
kubectl delete job -n corebank loadtest-heavy-write
kubectl apply -f k8s/loadtest/job-mixed-load.yaml
kubectl logs -n corebank -f job/loadtest-mixed-load
```

#### Expected Results (Baseline):

| Metric | Heavy Read | Heavy Write | Mixed Load |
|--------|-----------|-------------|------------|
| TPS | ~150-200 | ~80-120 | ~120-150 |
| Avg Latency | ~40-60ms | ~80-120ms | ~60-90ms |
| CPU Usage | 40-60% | 60-80% | 50-70% |
| Memory Usage | ~1-2GB | ~1.5-2.5GB | ~1.5-2GB |

### Scenario 2: Tuned Configuration

**วัตถุประสงค์**: วัดผลของการ tuning PostgreSQL

#### Steps:

1. **Switch to Tuned Config**
```bash
./scripts/switch-to-tuned-config.sh
```

2. **ตรวจสอบ Configuration**
```bash
kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank -c "SHOW shared_buffers;"
# ควรเห็น: 2GB

kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank -c "SHOW work_mem;"
# ควรเห็น: 16MB
```

3. **รัน Tests ทั้งหมดอีกครั้ง**
```bash
# Heavy Read
kubectl apply -f k8s/loadtest/job-heavy-read.yaml
kubectl logs -n corebank -f job/loadtest-heavy-read

# Heavy Write
kubectl delete job -n corebank loadtest-heavy-read
kubectl apply -f k8s/loadtest/job-heavy-write.yaml
kubectl logs -n corebank -f job/loadtest-heavy-write

# Mixed Load
kubectl delete job -n corebank loadtest-heavy-write
kubectl apply -f k8s/loadtest/job-mixed-load.yaml
kubectl logs -n corebank -f job/loadtest-mixed-load
```

#### Expected Improvements:

| Metric | Improvement |
|--------|-------------|
| TPS | +20-30% |
| Avg Latency | -15-25% |
| Cache Hit Ratio | +5-10% |
| Context Switches | -10-20% |

### Scenario 3: PgBouncer vs Direct Connection

**วัตถุประสงค์**: เปรียบเทียบ connection pooling

#### Steps:

1. **Test Direct Connection (Current)**
```bash
kubectl apply -f k8s/loadtest/job-heavy-read.yaml
kubectl logs -n corebank -f job/loadtest-heavy-read
```

2. **Switch to PgBouncer**
```bash
# แก้ไข k8s/app/configmap.yaml
kubectl edit configmap app-config -n corebank

# เปลี่ยนจาก:
# DATABASE_URL: "postgresql://postgres:postgres@postgres.corebank.svc.cluster.local:5432/corebank"
# เป็น:
# DATABASE_URL: "postgresql://postgres:postgres@pgbouncer.corebank.svc.cluster.local:6432/corebank"

# Restart application
kubectl rollout restart deployment/corebank-api -n corebank
kubectl rollout status deployment/corebank-api -n corebank
```

3. **Test with PgBouncer**
```bash
kubectl delete job -n corebank loadtest-heavy-read
kubectl apply -f k8s/loadtest/job-heavy-read.yaml
kubectl logs -n corebank -f job/loadtest-heavy-read
```

#### Metrics to Compare:

- Connection establishment time
- Number of active connections
- Connection overhead
- Query throughput
- Resource usage

### Scenario 4: Stress Testing

**วัตถุประสงค์**: หา breaking point ของระบบ

#### Steps:

1. **เพิ่ม Concurrency**
```bash
# รัน load tester จาก local ด้วย concurrency สูง
kubectl port-forward -n corebank svc/corebank-api 8080:8080 &

cargo run --bin load-tester -- http://localhost:8080 mixed 100 300
cargo run --bin load-tester -- http://localhost:8080 mixed 200 300
cargo run --bin load-tester -- http://localhost:8080 mixed 500 300
```

2. **ตรวจสอบ Metrics**
- ดู error rate เพิ่มขึ้นเมื่อไหร่
- ดู latency spike
- ดู resource exhaustion
- ดู context switching rate

## Metrics to Monitor

### PostgreSQL Metrics

#### 1. Connection Metrics
```sql
-- Active connections
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

-- Max connections
SHOW max_connections;

-- Connection usage percentage
SELECT (SELECT count(*) FROM pg_stat_activity) * 100.0 / 
       (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') 
       AS connection_usage_percent;
```

#### 2. Transaction Metrics
```sql
-- Transactions per second
SELECT datname, 
       xact_commit + xact_rollback as total_transactions,
       xact_commit,
       xact_rollback
FROM pg_stat_database 
WHERE datname = 'corebank';
```

#### 3. Cache Hit Ratio
```sql
-- Should be > 95%
SELECT 
  sum(blks_hit) * 100.0 / (sum(blks_hit) + sum(blks_read)) as cache_hit_ratio
FROM pg_stat_database
WHERE datname = 'corebank';
```

#### 4. Lock Monitoring
```sql
-- Current locks
SELECT mode, count(*) 
FROM pg_locks 
GROUP BY mode;

-- Lock waits
SELECT * FROM pg_stat_activity 
WHERE wait_event_type = 'Lock';
```

#### 5. Table Bloat
```sql
-- Dead tuples
SELECT schemaname, relname, n_dead_tup, n_live_tup,
       round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) as dead_ratio
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 10;
```

### System Metrics (from Grafana)

1. **CPU Usage**
   - Overall CPU utilization
   - Per-core usage
   - CPU wait time

2. **Memory Usage**
   - Total memory
   - Available memory
   - Swap usage

3. **Disk I/O**
   - Read/Write IOPS
   - Read/Write throughput
   - I/O wait time

4. **Context Switches**
   - Context switches per second
   - Voluntary vs Involuntary switches

## Performance Comparison

### Template for Recording Results

```markdown
## Test Results - [Date]

### Configuration
- PostgreSQL Config: [Default/Tuned]
- Connection Method: [Direct/PgBouncer]
- Number of Accounts: 100,000

### Heavy Read Test
- Duration: 300s
- Concurrency: 50
- TPS: XXX
- Avg Latency: XXms
- Min Latency: XXms
- Max Latency: XXms
- Success Rate: XX%
- CPU Usage: XX%
- Memory Usage: XXGB
- Context Switches/sec: XXXX

### Heavy Write Test
- Duration: 300s
- Concurrency: 30
- TPS: XXX
- Avg Latency: XXms
- Success Rate: XX%
- CPU Usage: XX%
- Memory Usage: XXGB

### Mixed Load Test
- Duration: 300s
- Concurrency: 50
- TPS: XXX
- Avg Latency: XXms
- Success Rate: XX%
- CPU Usage: XX%
- Memory Usage: XXGB
```

## Best Practices

### 1. Testing Methodology

- ✅ รัน test หลายครั้งและหาค่าเฉลี่ย
- ✅ ให้ระบบ warm up ก่อนเริ่ม test
- ✅ รอให้ระบบ cool down ระหว่าง tests
- ✅ ตรวจสอบว่าไม่มี background processes รบกวน
- ✅ บันทึก configuration ทุกครั้ง

### 2. Monitoring

- ✅ ดู metrics real-time ใน Grafana
- ✅ Export ผลลัพธ์เป็น CSV/JSON
- ✅ Screenshot graphs สำคัญ
- ✅ บันทึก anomalies ที่เจอ

### 3. Optimization

- ✅ เริ่มจาก baseline เสมอ
- ✅ เปลี่ยน configuration ทีละอย่าง
- ✅ วัดผลหลังแต่ละการเปลี่ยนแปลง
- ✅ Document ทุกการเปลี่ยนแปลง

### 4. Common Issues

#### High Latency
- ตรวจสอบ slow queries
- ดู index usage
- ตรวจสอบ table bloat
- ดู connection pooling

#### Low TPS
- เพิ่ม `shared_buffers`
- ปรับ `work_mem`
- ตรวจสอบ disk I/O
- ดู connection limits

#### High CPU Usage
- ตรวจสอบ inefficient queries
- ดู context switching
- ปรับ `max_connections`
- พิจารณา query optimization

#### Memory Issues
- ปรับ `shared_buffers`
- ลด `work_mem` ถ้าจำเป็น
- ตรวจสอบ memory leaks
- ดู swap usage

## Advanced Testing

### 1. Query Performance Analysis

```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 slowest queries
SELECT 
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### 2. Index Usage Analysis

```sql
-- Unused indexes
SELECT schemaname, tablename, indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexrelname NOT LIKE '%_pkey';

-- Index hit ratio
SELECT 
  relname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch,
  round(idx_tup_fetch * 100.0 / NULLIF(idx_tup_read, 0), 2) as hit_ratio
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### 3. Vacuum Analysis

```sql
-- Last vacuum/analyze times
SELECT schemaname, relname, 
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze
FROM pg_stat_user_tables;
```

---

**Happy Testing! 📊**
