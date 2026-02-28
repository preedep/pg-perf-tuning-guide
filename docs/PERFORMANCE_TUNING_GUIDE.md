# PostgreSQL Performance Tuning Guide

## 📊 Dashboard Metrics และการ Tuning

### 1. Cache Hit Ratio (เป้าหมาย: >95%)

**อ่านค่าจาก Dashboard:**
- Panel: "Cache Hit Ratio" (Gauge)
- สีเขียว (>95%) = ดี
- สีเหลือง (90-95%) = ควรปรับ
- สีแดง (<90%) = ต้องแก้ไขด่วน

**วิธีแก้:**
```sql
-- ตรวจสอบค่าปัจจุบัน
SHOW shared_buffers;
SHOW effective_cache_size;

-- แนะนำ
shared_buffers = 25% ของ RAM (สูงสุด 8GB)
effective_cache_size = 50-75% ของ RAM
```

**ตัวอย่าง:**
- RAM 8GB → shared_buffers = 2GB, effective_cache_size = 6GB
- RAM 16GB → shared_buffers = 4GB, effective_cache_size = 12GB

---

### 2. Context Switches (ยิ่งน้อยยิ่งดี)

**อ่านค่าจาก Dashboard:**
- Panel: "Context Switches (Performance Impact)"
- ดูค่า mean และ max

**สาเหตุที่ Context Switches สูง:**
- max_connections สูงเกินไป
- ไม่ใช้ Connection Pooling
- CPU cores น้อยเกินไป

**วิธีแก้:**
```sql
-- ลด max_connections
max_connections = 100  -- แทนที่จะเป็น 200-300

-- ใช้ PgBouncer
-- แก้ไข k8s/app/configmap.yaml
DATABASE_URL: "postgresql://postgres:postgres@pgbouncer:6432/corebank"
```

**สูตรคำนวณ max_connections:**
```
max_connections = (CPU cores * 2) + effective_spindle_count
```

---

### 3. CPU Usage & IO Wait

**อ่านค่าจาก Dashboard:**
- Panel: "CPU Usage Breakdown"
- ดู CPU Usage %, IO Wait %, System %

**ถ้า IO Wait สูง (>10%):**

**สาเหตุ:**
- Disk ช้า (HDD แทน SSD)
- shared_buffers น้อยเกินไป
- random_page_cost ไม่เหมาะสม

**วิธีแก้:**
```sql
-- สำหรับ SSD
random_page_cost = 1.1  -- default = 4.0
effective_io_concurrency = 200  -- default = 1

-- สำหรับ HDD
random_page_cost = 4.0
effective_io_concurrency = 2

-- เพิ่ม shared_buffers
shared_buffers = 2GB  -- หรือมากกว่า
```

---

### 4. Memory Usage

**อ่านค่าจาก Dashboard:**
- Panel: "Memory Usage (Tuning: shared_buffers, work_mem)"
- ดู Used Memory, Cache + Buffers, Available

**Parameters ที่เกี่ยวข้อง:**

```sql
-- Shared Buffers (สำหรับ cache ข้อมูล)
shared_buffers = 2GB

-- Work Memory (สำหรับ sort, hash operations)
work_mem = 16MB  -- ระวัง! คูณด้วย max_connections

-- Maintenance Work Memory (สำหรับ VACUUM, CREATE INDEX)
maintenance_work_mem = 256MB

-- Effective Cache Size (บอก planner ว่า OS มี cache เท่าไร)
effective_cache_size = 6GB
```

**การคำนวณ work_mem:**
```
Total work_mem = work_mem * max_connections * 2
ต้องไม่เกิน 50% ของ RAM

ตัวอย่าง:
work_mem = 16MB
max_connections = 100
Total = 16MB * 100 * 2 = 3.2GB
```

---

### 5. Database Connections

**อ่านค่าจาก Dashboard:**
- Panel: "Database Connections (Tuning: max_connections)"
- ดู Active Connections vs Max Connections

**ถ้า Active Connections ใกล้ Max:**

**วิธีแก้:**
```sql
-- เพิ่ม max_connections (ระวัง! เพิ่ม context switches)
max_connections = 200

-- หรือใช้ PgBouncer (แนะนำ)
# PgBouncer Config
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
```

**PgBouncer Pool Modes:**
- `session` - 1 connection ต่อ session (ปลอดภัยที่สุด)
- `transaction` - 1 connection ต่อ transaction (แนะนำ)
- `statement` - 1 connection ต่อ statement (เร็วที่สุดแต่มีข้อจำกัด)

---

### 6. Disk I/O

**อ่านค่าจาก Dashboard:**
- Panel: "Disk I/O (Tuning: effective_io_concurrency, random_page_cost)"
- ดู Disk Read/Write throughput

**ถ้า Disk I/O สูง:**

```sql
-- เพิ่ม shared_buffers เพื่อลด disk reads
shared_buffers = 4GB

-- ปรับ checkpoint settings
checkpoint_completion_target = 0.9
max_wal_size = 2GB
min_wal_size = 1GB

-- ปรับ background writer
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0
```

---

### 7. Deadlocks

**อ่านค่าจาก Dashboard:**
- Panel: "Active Connections & Deadlocks (Tuning: deadlock_timeout)"
- Deadlocks ควรเป็น 0

**ถ้ามี Deadlocks:**

**สาเหตุ:**
- Application logic ไม่ดี (lock order ไม่สม่ำเสมอ)
- Transaction ยาวเกินไป

**วิธีแก้:**
```sql
-- ปรับ deadlock_timeout
deadlock_timeout = 1s  -- default

-- ใน Application
-- 1. Lock ตาม order เดียวกันเสมอ (เช่น sort by account_id)
-- 2. ใช้ SELECT FOR UPDATE NOWAIT
-- 3. ทำ transaction ให้สั้น
```

---

### 8. Table Bloat (Dead Tuples)

**อ่านค่าจาก Dashboard:**
- Panel: "Table Bloat - Dead Tuples (Tuning: autovacuum)"
- ดู Dead Tuples per table

**ถ้า Dead Tuples สูง:**

```sql
-- ปรับ autovacuum settings
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min

-- Per-table settings
autovacuum_vacuum_scale_factor = 0.1  -- vacuum เมื่อ 10% เป็น dead
autovacuum_analyze_scale_factor = 0.05

-- สำหรับ high-write tables
ALTER TABLE transactions SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
```

---

### 9. Block I/O (Cache vs Disk)

**อ่านค่าจาก Dashboard:**
- Panel: "Block I/O (Tuning: shared_buffers, effective_cache_size)"
- ดู Disk Blocks Read vs Cache Blocks Hit

**เป้าหมาย:**
- Cache Blocks Hit >> Disk Blocks Read
- Ratio ควร >95%

**วิธีแก้:**
```sql
-- เพิ่ม shared_buffers
shared_buffers = 4GB

-- เพิ่ม effective_cache_size
effective_cache_size = 12GB

-- ตรวจสอบ index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0;
```

---

## 🎯 Quick Tuning Checklist

### สำหรับ Read-Heavy Workload
- [ ] เพิ่ม `shared_buffers` (2-4GB)
- [ ] เพิ่ม `effective_cache_size` (50-75% RAM)
- [ ] ลด `random_page_cost` (1.1 สำหรับ SSD)
- [ ] สร้าง indexes ที่เหมาะสม
- [ ] ใช้ PgBouncer pool_mode = transaction

### สำหรับ Write-Heavy Workload
- [ ] ปรับ `checkpoint_completion_target` = 0.9
- [ ] เพิ่ม `max_wal_size` (2GB+)
- [ ] ปรับ `autovacuum` settings
- [ ] ใช้ `synchronous_commit = off` (ถ้ายอมเสี่ยงได้)
- [ ] เพิ่ม `maintenance_work_mem` (256MB+)

### สำหรับ High Concurrency
- [ ] ใช้ PgBouncer
- [ ] ลด `max_connections` (100-200)
- [ ] เพิ่ม `work_mem` แต่ระวัง total memory
- [ ] Monitor context switches
- [ ] ใช้ connection pooling ใน application

---

## 📈 Performance Testing Workflow

### 1. Baseline Test (Default Config)
```bash
# Deploy with default config
./scripts/deploy.sh

# Seed data
./scripts/seed-database.sh

# Run test suite
./scripts/performance-test-suite.sh

# บันทึกผลลัพธ์:
# - TPS
# - Latency (min/avg/max)
# - Cache Hit Ratio
# - Context Switches
# - CPU/Memory Usage
```

### 2. Tuned Config Test
```bash
# Apply tuned config
kubectl apply -f k8s/postgres/configmap-tuned.yaml
kubectl rollout restart statefulset/postgres -n corebank

# รอให้ PostgreSQL restart
kubectl wait --for=condition=ready pod/postgres-0 -n corebank --timeout=120s

# Run test suite อีกครั้ง
./scripts/performance-test-suite.sh

# เปรียบเทียบผลลัพธ์
```

### 3. PgBouncer Test
```bash
# Enable PgBouncer
kubectl apply -f k8s/app/configmap-pgbouncer.yaml
kubectl rollout restart deployment/corebank-api -n corebank

# Run test suite
./scripts/performance-test-suite.sh

# เปรียบเทียบ connection overhead
```

---

## 🔍 Troubleshooting Common Issues

### Issue: Cache Hit Ratio < 90%

**Diagnosis:**
```sql
SELECT 
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit) as heap_hit,
  sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM pg_statio_user_tables;
```

**Solution:**
- เพิ่ม shared_buffers
- เพิ่ม effective_cache_size
- ตรวจสอบ missing indexes

### Issue: High Context Switches

**Diagnosis:**
```bash
# ดูจาก Grafana Dashboard
# หรือ
vmstat 1 10
```

**Solution:**
- ลด max_connections
- ใช้ PgBouncer
- ตรวจสอบ application connection pooling

### Issue: Slow Queries

**Diagnosis:**
```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ดู slow queries
SELECT query, calls, mean_exec_time, max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**Solution:**
- สร้าง indexes
- เพิ่ม work_mem
- Optimize queries
- ใช้ EXPLAIN ANALYZE

---

## 📚 Additional Resources

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [PgBouncer Documentation](https://www.pgbouncer.org/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/)
