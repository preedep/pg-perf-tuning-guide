# Load Test Scenarios - Core Banking

คู่มือการทดสอบ API สำหรับ Core Banking Performance Tuning

## 🎯 API Endpoints ที่ทดสอบ

### 1. Balance Inquiry (Heavy Read)
**Endpoint**: `GET /api/v1/accounts/balance/{account_number}`

**วัตถุประสงค์**: ทดสอบประสิทธิภาพการอ่านข้อมูลยอดเงินคงเหลือ

**Response**:
```json
{
  "account_number": "ACC00000001",
  "balance": 50000.00,
  "currency": "THB"
}
```

**Use Case**: 
- ลูกค้าตรวจสอบยอดเงินผ่าน Mobile Banking
- ATM แสดงยอดเงิน
- ระบบ Backend ตรวจสอบยอดก่อนทำธุรกรรม

### 2. Transfer (Heavy Write)
**Endpoint**: `POST /api/v1/transactions/transfer`

**วัตถุประสงค์**: ทดสอบประสิทธิภาพการโอนเงินระหว่างบัญชี (Heavy Write + Transaction)

**Request**:
```json
{
  "from_account_number": "ACC00000001",
  "to_account_number": "ACC00000002",
  "amount": 1000.00,
  "description": "Transfer to friend"
}
```

**Response**:
```json
{
  "id": "uuid",
  "transaction_ref": "TXN123456",
  "from_account_id": "uuid",
  "to_account_id": "uuid",
  "transaction_type": "TRANSFER",
  "amount": 1000.00,
  "currency": "THB",
  "status": "COMPLETED"
}
```

**Database Operations**:
- อ่าน 2 accounts (from + to)
- อัพเดท balance 2 accounts
- สร้าง 1 transaction record
- สร้าง 2 ledger entries (debit + credit)
- ทั้งหมดใน 1 database transaction

**Use Case**:
- โอนเงินผ่าน Mobile Banking
- โอนเงินระหว่างบัญชีตัวเอง
- ชำระเงินผ่าน QR Code

## 📊 Test Scenarios

### Scenario 1: Heavy Read (Balance Inquiry)

**คำสั่งทดสอบ**:
```bash
# รันจาก Kubernetes
kubectl apply -f k8s/loadtest/job-heavy-read.yaml
kubectl logs -n corebank -f job/loadtest-heavy-read

# รันจาก local
cargo run --bin load-tester -- http://localhost:8080 heavy-read 50 300
```

**Parameters**:
- Test Type: `heavy-read`
- Concurrency: 50 concurrent users
- Duration: 300 seconds (5 minutes)

**Expected Behavior**:
- 100% Balance Inquiry operations
- Random account selection (0-99,999)
- Minimal database writes
- High cache hit ratio

**Key Metrics**:
- TPS: 200-300+ (ขึ้นกับ config)
- Avg Latency: 20-40ms
- Cache Hit Ratio: >95%
- CPU Usage: 30-50%

### Scenario 2: Heavy Write (Transfer)

**คำสั่งทดสอบ**:
```bash
# รันจาก Kubernetes
kubectl apply -f k8s/loadtest/job-heavy-write.yaml
kubectl logs -n corebank -f job/loadtest-heavy-write

# รันจาก local
cargo run --bin load-tester -- http://localhost:8080 heavy-write 30 300
```

**Parameters**:
- Test Type: `heavy-write`
- Concurrency: 30 concurrent users (ลดลงเพราะ write intensive)
- Duration: 300 seconds

**Expected Behavior**:
- 100% Transfer operations
- Random account pairs
- Heavy database writes
- Transaction locks
- Ledger entry creation

**Key Metrics**:
- TPS: 80-150 (ต่ำกว่า read เพราะ complexity)
- Avg Latency: 60-120ms
- Lock Waits: Monitor carefully
- CPU Usage: 60-80%
- Disk I/O: High

### Scenario 3: Mixed Load (Realistic)

**คำสั่งทดสอบ**:
```bash
# รันจาก Kubernetes
kubectl apply -f k8s/loadtest/job-mixed-load.yaml
kubectl logs -n corebank -f job/loadtest-mixed-load

# รันจาก local
cargo run --bin load-tester -- http://localhost:8080 mixed 50 300
```

**Parameters**:
- Test Type: `mixed`
- Concurrency: 50 concurrent users
- Duration: 300 seconds

**Operation Mix**:
- 60% Balance Inquiry (Read)
- 40% Transfer (Write)

**Expected Behavior**:
- Realistic banking workload
- Mix of read and write operations
- Balanced resource usage

**Key Metrics**:
- TPS: 120-200
- Avg Latency: 40-80ms
- Success Rate: >99%
- CPU Usage: 50-70%

## 🔬 การวิเคราะห์ผลลัพธ์

### 1. Balance Inquiry Performance

**ปัจจัยที่ส่งผล**:
- **Index Efficiency**: account_number index
- **Cache Hit Ratio**: shared_buffers, effective_cache_size
- **Connection Pooling**: PgBouncer vs Direct
- **Query Plan**: EXPLAIN ANALYZE

**การปรับแต่ง**:
```sql
-- ตรวจสอบ index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE tablename = 'accounts';

-- ตรวจสอบ cache hit ratio
SELECT 
  sum(blks_hit) * 100.0 / (sum(blks_hit) + sum(blks_read)) as cache_hit_ratio
FROM pg_stat_database
WHERE datname = 'corebank';
```

### 2. Transfer Performance

**ปัจจัยที่ส่งผล**:
- **Transaction Isolation**: Serialization conflicts
- **Lock Contention**: Row-level locks
- **WAL Writing**: synchronous_commit, wal_buffers
- **Checkpoint Frequency**: checkpoint_timeout
- **Index Maintenance**: Multiple table updates

**การปรับแต่ง**:
```sql
-- ตรวจสอบ locks
SELECT mode, count(*) 
FROM pg_locks 
GROUP BY mode;

-- ตรวจสอบ lock waits
SELECT * FROM pg_stat_activity 
WHERE wait_event_type = 'Lock';

-- ตรวจสอบ transaction conflicts
SELECT * FROM pg_stat_database_conflicts 
WHERE datname = 'corebank';
```

### 3. Mixed Load Analysis

**สิ่งที่ต้องดู**:
- Read/Write ratio impact
- Lock contention patterns
- Resource utilization balance
- Query queue depth

## 📈 Performance Comparison Matrix

### Default Config vs Tuned Config

| Metric | Default | Tuned | Improvement |
|--------|---------|-------|-------------|
| **Balance Inquiry TPS** | 150-200 | 250-350 | +50-75% |
| **Balance Inquiry Latency** | 40-60ms | 20-35ms | -40-50% |
| **Transfer TPS** | 60-80 | 100-150 | +60-90% |
| **Transfer Latency** | 100-150ms | 60-90ms | -30-40% |
| **Cache Hit Ratio** | 85-90% | 95-98% | +10% |
| **Connection Overhead** | High | Low | -50% |

### Direct Connection vs PgBouncer

| Metric | Direct | PgBouncer | Difference |
|--------|--------|-----------|------------|
| **Connection Time** | 50-100ms | 5-10ms | -90% |
| **Max Connections** | 100 | 1000 (pooled) | +900% |
| **Memory per Connection** | 10MB | 1MB | -90% |
| **Connection Reuse** | No | Yes | ✓ |

## 🎓 Best Practices

### 1. Test Preparation

```bash
# 1. ตรวจสอบว่า database มีข้อมูล
kubectl exec -it -n corebank postgres-0 -- \
  psql -U postgres -d corebank -c "SELECT COUNT(*) FROM accounts;"

# 2. Clear cache ก่อนทดสอบ (optional)
kubectl exec -it -n corebank postgres-0 -- \
  psql -U postgres -d corebank -c "SELECT pg_stat_reset();"

# 3. Vacuum database
kubectl exec -it -n corebank postgres-0 -- \
  psql -U postgres -d corebank -c "VACUUM ANALYZE;"
```

### 2. During Test

- เปิด Grafana dashboard
- Monitor real-time metrics
- บันทึก screenshots
- ดู logs หา errors

### 3. After Test

```bash
# ดูสถิติ database
kubectl exec -it -n corebank postgres-0 -- \
  psql -U postgres -d corebank -c "
    SELECT 
      datname,
      xact_commit,
      xact_rollback,
      blks_read,
      blks_hit,
      tup_returned,
      tup_fetched,
      tup_inserted,
      tup_updated
    FROM pg_stat_database 
    WHERE datname = 'corebank';
  "

# ดู slow queries
kubectl exec -it -n corebank postgres-0 -- \
  psql -U postgres -d corebank -c "
    SELECT query, calls, total_exec_time, mean_exec_time
    FROM pg_stat_statements
    ORDER BY mean_exec_time DESC
    LIMIT 10;
  "
```

## 🔧 Troubleshooting

### Balance Inquiry ช้า

**สาเหตุที่เป็นไปได้**:
1. Index ไม่ถูกใช้
2. Cache hit ratio ต่ำ
3. Network latency
4. Connection pooling ไม่เพียงพอ

**วิธีแก้**:
```sql
-- ตรวจสอบ query plan
EXPLAIN ANALYZE 
SELECT * FROM accounts WHERE account_number = 'ACC00000001';

-- ควรเห็น Index Scan, ไม่ใช่ Seq Scan
```

### Transfer ล้มเหลวบ่อย

**สาเหตุที่เป็นไปได้**:
1. Insufficient balance (expected)
2. Deadlock
3. Connection timeout
4. Transaction conflicts

**วิธีแก้**:
```sql
-- ตรวจสอบ deadlocks
SELECT * FROM pg_stat_database 
WHERE datname = 'corebank';

-- ดู deadlock_count
```

### High Latency Spikes

**สาเหตุที่เป็นไปได้**:
1. Checkpoint happening
2. Autovacuum running
3. Lock contention
4. Disk I/O bottleneck

**วิธีแก้**:
- ปรับ checkpoint_timeout
- ปรับ autovacuum settings
- เพิ่ม shared_buffers
- ใช้ faster disk (SSD)

## 📝 Test Report Template

```markdown
## Load Test Report - [Date]

### Configuration
- PostgreSQL: [Default/Tuned]
- Connection: [Direct/PgBouncer]
- Accounts: 100,000
- Test Duration: 300s

### Balance Inquiry Test
- Concurrency: 50
- Total Requests: XXXXX
- TPS: XXX.XX
- Avg Latency: XX.XXms
- Min/Max Latency: XX/XXXms
- Success Rate: XX.XX%
- Cache Hit Ratio: XX.XX%

### Transfer Test
- Concurrency: 30
- Total Requests: XXXXX
- TPS: XXX.XX
- Avg Latency: XX.XXms
- Min/Max Latency: XX/XXXms
- Success Rate: XX.XX%
- Lock Waits: XXXX

### Mixed Load Test
- Concurrency: 50
- Total Requests: XXXXX
- TPS: XXX.XX
- Avg Latency: XX.XXms
- Success Rate: XX.XX%

### System Metrics
- CPU Usage: XX%
- Memory Usage: X.XGB
- Disk I/O: XX MB/s
- Context Switches: XXXX/s

### Observations
- [Key findings]
- [Bottlenecks identified]
- [Recommendations]
```

---

**Happy Testing! 🚀**
