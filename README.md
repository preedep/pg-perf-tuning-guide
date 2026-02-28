# PostgreSQL Performance Tuning Guide - Core Banking Simulation

โปรเจคนี้สร้างขึ้นเพื่อทดสอบและเปรียบเทียบประสิทธิภาพของ PostgreSQL ในสถานการณ์ Core Banking โดยใช้ Kubernetes, Rust, และ Actix-Web

## 📋 สารบัญ

- [ภาพรวมโปรเจค](#ภาพรวมโปรเจค)
- [สถาปัตยกรรม](#สถาปัตยกรรม)
- [ข้อกำหนดระบบ](#ข้อกำหนดระบบ)
- [การติดตั้ง](#การติดตั้ง)
- [โครงสร้างฐานข้อมูล](#โครงสร้างฐานข้อมูล)
- [การใช้งาน](#การใช้งาน)
- [การทดสอบประสิทธิภาพ](#การทดสอบประสิทธิภาพ)
- [การตรวจสอบและ Monitoring](#การตรวจสอบและ-monitoring)
- [PostgreSQL Tuning Configurations](#postgresql-tuning-configurations)

## 🎯 ภาพรวมโปรเจค

### วัตถุประสงค์

สร้าง project เพื่อทำ PostgreSQL performance tuning โดยจำลองระบบ Core Banking ที่มี:
- **100,000 บัญชี** (accounts)
- ทดสอบ **Heavy Read, Heavy Write, และ Mixed Load**
- เปรียบเทียบประสิทธิภาพระหว่าง **Default Config vs Tuned Config**
- เปรียบเทียบการใช้ **Direct PostgreSQL vs PgBouncer**

### คุณสมบัติหลัก

- ✅ Rust Microservice ด้วย Actix-Web
- ✅ Clean Architecture (Domain, Application, Infrastructure)
- ✅ PostgreSQL 16 พร้อม Configuration แบบ Default และ Tuned
- ✅ PgBouncer สำหรับ Connection Pooling
- ✅ Prometheus + Grafana สำหรับ Monitoring
- ✅ Load Testing Tool ที่เขียนด้วย Rust (lightweight และแสดง TPS/QPS/Latency)
- ✅ รองรับทั้ง Docker Desktop และ Minikube บน Ubuntu

## 🏗️ สถาปัตยกรรม

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│  ┌────────────┐  ┌──────────────┐  ┌─────────────────┐ │
│  │ Load Test  │  │  Corebank    │  │   PgBouncer     │ │
│  │   Jobs     │─▶│     API      │─▶│   (Optional)    │ │
│  └────────────┘  │  (3 replicas)│  └─────────────────┘ │
│                  └──────────────┘           │           │
│                         │                   │           │
│                         └───────────────────┘           │
│                                 │                       │
│                         ┌───────▼────────┐              │
│                         │   PostgreSQL   │              │
│                         │  (StatefulSet) │              │
│                         └────────────────┘              │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │            Monitoring Stack                       │  │
│  │  ┌──────────┐  ┌─────────┐  ┌──────────────────┐│  │
│  │  │Prometheus│  │ Grafana │  │ Postgres Exporter││  │
│  │  └──────────┘  └─────────┘  └──────────────────┘│  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Clean Architecture Layers

```
src/
├── domain/              # Business Logic Layer
│   ├── entities/        # Account, Transaction, Ledger
│   ├── repositories/    # Repository Traits
│   └── errors.rs        # Domain Errors
├── application/         # Application Layer
│   ├── services/        # Business Services
│   └── dto/             # Data Transfer Objects
└── infrastructure/      # Infrastructure Layer
    ├── persistence/     # PostgreSQL Implementations
    └── web/             # Actix-Web Handlers & Routes
```

## 💻 ข้อกำหนดระบบ

### สำหรับ Development
- Rust 1.75+
- Docker Desktop หรือ Minikube
- kubectl
- PostgreSQL Client (psql)

### สำหรับ Production Testing
- Kubernetes Cluster (Docker Desktop K8s หรือ Minikube)
- 4GB+ RAM สำหรับ cluster
- 10GB+ Disk Space

## 🚀 การติดตั้ง

### 1. Clone และ Setup

```bash
git clone <repository-url>
cd pg-perf-tuning-guide

# สร้าง .env file (สำหรับ local development)
cat > .env << EOF
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/corebank
RUST_LOG=info
HOST=0.0.0.0
PORT=8080
EOF
```

### 2. Build Docker Image

```bash
# Build image พร้อม seed-data และ load-tester binaries
docker build -t corebank-api:latest .
```

### 3. Deploy ไปยัง Kubernetes

```bash
# ให้สิทธิ์ execute scripts
chmod +x scripts/*.sh

# Deploy ทั้งหมด (PostgreSQL, PgBouncer, Monitoring, Application)
./scripts/deploy.sh
```

**Script จะ deploy:**
- ✅ PostgreSQL 16 (StatefulSet)
- ✅ PgBouncer (Connection Pooling)
- ✅ Prometheus (Metrics Collection)
- ✅ Grafana (Visualization) - Port **30030**
- ✅ Node Exporter (System Metrics)
- ✅ PostgreSQL Exporter (Database Metrics)
- ✅ Corebank API (3 replicas)

**หลัง deploy เสร็จ จะแสดง:**
```
========================================
  Deployment Summary
========================================

Services:
  - Grafana:     http://localhost:30030
  - Prometheus:  http://localhost:30508
  - API:         http://localhost:30080

Grafana Credentials:
  Username: admin
  Password: admin

Next Steps:
  1. Seed database:
     ./scripts/seed-database.sh

  2. Run performance tests:
     ./scripts/run-load-test.sh mixed 60 10

  3. View metrics in Grafana:
     http://localhost:30030/d/postgresql-perf/postgresql-performance-tuning-dashboard
```

### 4. Seed ข้อมูล 100,000 บัญชี

```bash
# ใช้ script ที่เตรียมไว้
./scripts/seed-database.sh
```

Script จะ:
- ✅ ตรวจสอบว่า API pod พร้อมใช้งาน
- ✅ Seed 100,000 accounts (ใช้เวลา 2-3 นาที)
- ✅ Verify ข้อมูลหลัง seed เสร็จ

## 🗄️ โครงสร้างฐานข้อมูล

### Tables

#### 1. accounts
```sql
- id (UUID, PK)
- account_number (VARCHAR, UNIQUE)
- customer_id (VARCHAR)
- account_type (VARCHAR) -- SAVINGS, CHECKING
- balance (NUMERIC)
- currency (VARCHAR)
- status (VARCHAR)
- created_at, updated_at (TIMESTAMPTZ)

Indexes:
- account_number
- customer_id
- created_at
```

#### 2. transactions
```sql
- id (UUID, PK)
- transaction_ref (VARCHAR, UNIQUE)
- from_account_id (UUID, FK)
- to_account_id (UUID, FK)
- transaction_type (VARCHAR) -- DEPOSIT, WITHDRAWAL, TRANSFER
- amount (NUMERIC)
- currency (VARCHAR)
- description (TEXT)
- status (VARCHAR)
- created_at (TIMESTAMPTZ)

Indexes:
- from_account_id
- to_account_id
- transaction_ref
- transaction_type
- created_at
```

#### 3. ledger_entries
```sql
- id (UUID, PK)
- transaction_id (UUID, FK)
- account_id (UUID, FK)
- entry_type (VARCHAR) -- DEBIT, CREDIT
- amount (NUMERIC)
- balance_before (NUMERIC)
- balance_after (NUMERIC)
- created_at (TIMESTAMPTZ)

Indexes:
- transaction_id
- account_id
- created_at
- (account_id, created_at) -- Composite
```

## 📖 การใช้งาน

### API Endpoints

#### Health Checks
```bash
GET /health       # Health check
GET /ready        # Readiness check
```

#### Accounts
```bash
POST   /api/v1/accounts                    # สร้างบัญชี
GET    /api/v1/accounts                    # ดูรายการบัญชี
GET    /api/v1/accounts/{id}               # ดูบัญชีตาม ID
GET    /api/v1/accounts/number/{number}    # ดูบัญชีตามเลขบัญชี
GET    /api/v1/accounts/balance/{number}   # ตรวจสอบยอดเงิน (Balance Inquiry) ⭐
```

#### Transactions
```bash
POST   /api/v1/transactions/deposit        # ฝากเงิน
POST   /api/v1/transactions/withdraw       # ถอนเงิน
POST   /api/v1/transactions/transfer       # โอนเงิน (Transfer) ⭐
```

**⭐ = API หลักที่ใช้ทดสอบ Performance**

### ตัวอย่างการใช้งาน

```bash
# Port forward API
kubectl port-forward -n corebank svc/corebank-api 8080:8080

# สร้างบัญชี
curl -X POST http://localhost:8080/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "account_number": "ACC00000001",
    "customer_id": "CUST001",
    "account_type": "SAVINGS",
    "currency": "THB"
  }'

# ฝากเงิน
curl -X POST http://localhost:8080/api/v1/transactions/deposit \
  -H "Content-Type: application/json" \
  -d '{
    "account_number": "ACC00000001",
    "amount": 1000.00,
    "description": "Initial deposit"
  }'

# ตรวจสอบยอดเงิน (Balance Inquiry)
curl http://localhost:8080/api/v1/accounts/balance/ACC00000001

# โอนเงิน (Transfer)
curl -X POST http://localhost:8080/api/v1/transactions/transfer \
  -H "Content-Type: application/json" \
  -d '{
    "from_account_number": "ACC00000001",
    "to_account_number": "ACC00000002",
    "amount": 500.00,
    "description": "Transfer to friend"
  }'
```

## 🔥 การทดสอบประสิทธิภาพ

### Load Testing Tool

โปรเจคมี Load Testing Tool ที่เขียนด้วย Rust ซึ่งมีคุณสมบัติ:
- **Lightweight** - ใช้ทรัพยากรน้อย
- แสดง **TPS (Transactions Per Second)**
- แสดง **QPS (Queries Per Second)**
- แสดง **Latency** (Min, Avg, Max)
- แสดง **Success Rate**

### 🎯 Quick Start - Performance Test Suite

รัน test suite ครบชุดด้วยคำสั่งเดียว:

```bash
./scripts/performance-test-suite.sh
```

**Test Suite จะรัน:**
1. ✅ Seed database (100,000 accounts)
2. ✅ Heavy-read test (60s, 10 users)
3. ⏸️ Cooldown 30s
4. ✅ Heavy-write test (60s, 10 users)
5. ⏸️ Cooldown 30s
6. ✅ Mixed load test (120s, 20 users)
7. ✅ Collect CSV reports from pods
8. ✅ Generate consolidated summary report

**ใช้เวลารวม:** ~8 นาที

**Output:**
- Individual CSV reports สำหรับแต่ละ test
- Summary report รวมทุก tests
- Performance indicators และ recommendations

### 📊 รัน Load Test แบบเดียว

#### วิธีใช้ Script

```bash
./scripts/run-load-test.sh [test-type] [duration] [concurrent-users]
```

**ตัวอย่าง:**

```bash
# Heavy Read Test (60 seconds, 10 concurrent users)
./scripts/run-load-test.sh heavy-read 60 10

# Heavy Write Test (120 seconds, 20 concurrent users)
./scripts/run-load-test.sh heavy-write 120 20

# Mixed Load Test (300 seconds, 50 concurrent users)
./scripts/run-load-test.sh mixed 300 50
```

### 🔬 Test Types

#### 1. Heavy Read Test - Balance Inquiry
ทดสอบการตรวจสอบยอดเงิน (100% Read Operations)

```bash
./scripts/run-load-test.sh heavy-read 60 10
```

**API ที่ทดสอบ**: `GET /api/v1/accounts/balance/{account_number}`

**Database Operations:**
- SELECT account by account_number
- อ่าน balance

#### 2. Heavy Write Test - Transfer
ทดสอบการโอนเงินระหว่างบัญชี (100% Write Operations)

```bash
./scripts/run-load-test.sh heavy-write 60 10
```

**API ที่ทดสอบ**: `POST /api/v1/transactions/transfer`

**Database Operations:**
- SELECT 2 accounts (from + to) with FOR UPDATE
- UPDATE balance 2 accounts
- INSERT 1 transaction
- INSERT 2 ledger entries
- ทั้งหมดใน 1 database transaction

#### 3. Mixed Load Test
ทดสอบแบบ realistic workload (60% Read, 40% Write)

```bash
./scripts/run-load-test.sh mixed 120 20
```

**API ที่ทดสอบ:**
- 60% Balance Inquiry
- 40% Transfer

### 📈 ตัวอย่างผลลัพธ์

```
==========================================
  PostgreSQL Performance Load Test
==========================================

Test Configuration:
  Type:              mixed
  Duration:          60 seconds
  Concurrent Users:  10

🚀 Load test started!
==========================================

=== Load Test Results ===
Total Duration: 60.00s
Total Requests: 9,046
Successful Requests: 9,012
Failed Requests: 34
Success Rate: 99.62%
---
TPS (Transactions Per Second): 150.77
QPS (Queries Per Second): 150.77
---
Min Latency: 12ms
Avg Latency: 45.23ms
Max Latency: 523ms
========================

📊 CSV Report generated: /tmp/loadtest_mixed_20260228_103045.csv
   Copy from container: kubectl cp corebank/<pod-name>:/tmp/loadtest_mixed_20260228_103045.csv ./reports/

✅ Load test completed!
==========================================

📊 View detailed metrics in Grafana:
   http://localhost:30030/d/postgresql-perf/postgresql-performance-tuning-dashboard
```

### 📊 CSV Reports และ Analysis

#### รวบรวม Reports

หลังรัน load tests แล้ว ให้ดึง CSV reports ออกมา:

```bash
./scripts/collect-reports.sh
```

**Output:**
```
==========================================
  Collecting Performance Test Reports
==========================================

Using pod: corebank-api-xxx

Available reports in pod:
-rw-r--r-- 1 root root 2.1K loadtest_heavy-read_20260228_103045.csv
-rw-r--r-- 1 root root 2.0K loadtest_heavy-write_20260228_104120.csv
-rw-r--r-- 1 root root 2.1K loadtest_mixed_20260228_105200.csv

Copying reports from pod to ./reports/ ...
  ✅ Copied: loadtest_heavy-read_20260228_103045.csv
  ✅ Copied: loadtest_heavy-write_20260228_104120.csv
  ✅ Copied: loadtest_mixed_20260228_105200.csv

==========================================
  ✅ Collected 3 report(s)
==========================================
```

#### สร้าง Summary Report

```bash
./scripts/generate-summary-report.sh
```

**สร้าง consolidated report:**
- เปรียบเทียบผลลัพธ์ทุก tests
- Performance indicators (EXCELLENT/GOOD/ACCEPTABLE/POOR)
- Recommendations สำหรับการ tune

#### โครงสร้าง CSV Report

แต่ละ report มี 4 sections:

**1. Test Configuration**
```csv
Test Configuration
Parameter,Value
Test Type,heavy-read
Concurrency,10
Duration (seconds),60
Actual Duration (seconds),60.23
```

**2. Summary Statistics**
```csv
Summary Statistics
Metric,Value,Unit
Total Requests,45230,requests
Successful Requests,45100,requests
Failed Requests,130,requests
Success Rate,99.71,%
TPS (Transactions Per Second),750.45,tps
```

**3. Latency Statistics**
```csv
Latency Statistics
Metric,Value (ms)
Minimum Latency,12
Average Latency,45.23
Maximum Latency,523
```

**4. Performance Indicators**
```csv
Performance Indicators
Indicator,Status,Threshold,Actual
Success Rate,EXCELLENT,>=99.5%,99.71%
Average Latency,GOOD,<50ms,45.23ms
Maximum Latency,ACCEPTABLE,<500ms,523ms
Throughput (TPS),GOOD,>=1000,750.45
```

**Performance Status Levels:**
- 🟢 **EXCELLENT** - เกินเป้าหมาย
- 🟡 **GOOD** - ดี
- 🟠 **ACCEPTABLE** - พอใช้ได้
- 🔴 **POOR** - ต้องปรับปรุง

#### เปิด Reports

```bash
# View with cat
cat reports/loadtest_*.csv

# Open with Excel/Google Sheets
open reports/SUMMARY_*.csv

# View summary
ls -lh reports/
```

## 📊 การตรวจสอบและ Monitoring

### 🎨 เข้าถึง Grafana Dashboard

```bash
# เปิด browser ที่
http://localhost:30030

# Login (หรือใช้ anonymous access)
Username: admin
Password: admin
```

**Dashboard URL:**
```
http://localhost:30030/d/postgresql-perf/postgresql-performance-tuning-dashboard
```

### 📈 PostgreSQL Performance Tuning Dashboard

Dashboard มี **11 panels** สำหรับ performance tuning:

#### 🔥 Core Performance Metrics
1. **Transactions Per Second (TPS)**
   - วัดจำนวน transactions ที่ commit + rollback
   - ควรเพิ่มขึ้นตอน load test

2. **Cache Hit Ratio** (Gauge)
   - วัดประสิทธิภาพของ shared_buffers
   - **เป้าหมาย: >95%** (สีเขียว)
   - <90% = ต้องเพิ่ม shared_buffers

#### ⚡ System Resources
3. **Context Switches** (Performance Impact)
   - วัดจำนวน context switches per second
   - สูงเกินไป = CPU thrashing
   - **Tuning:** ลด max_connections, ใช้ PgBouncer

4. **CPU Usage Breakdown**
   - CPU Usage %
   - IO Wait % (สูง = disk bottleneck)
   - System %

5. **Memory Usage**
   - Used Memory
   - Cache + Buffers
   - Available
   - **Tuning:** shared_buffers, work_mem

#### 🔧 Database Tuning Metrics
6. **Database Connections**
   - Active Connections vs Max Connections
   - **Tuning:** max_connections

7. **Disk I/O**
   - Disk Read/Write throughput
   - **Tuning:** effective_io_concurrency, random_page_cost

8. **Active Connections & Deadlocks**
   - จำนวน active connections
   - Deadlocks (ควรเป็น 0)
   - **Tuning:** deadlock_timeout

9. **Table Bloat - Dead Tuples**
   - Dead tuples ต่อ table
   - **Tuning:** autovacuum settings

10. **Database Activity**
    - Inserts/sec
    - Updates/sec
    - Deletes/sec

11. **Block I/O**
    - Disk Blocks Read/sec
    - Cache Blocks Hit/sec
    - **Tuning:** shared_buffers, effective_cache_size

### 🔍 เข้าถึง Prometheus

```bash
http://localhost:30508

# Query ตัวอย่าง
pg_stat_database_numbackends{datname="corebank"}
rate(pg_stat_database_xact_commit[1m])
node_context_switches_total
```

### 📊 Metrics ที่ติดตาม

#### PostgreSQL Metrics (จาก postgres-exporter)
- ✅ `pg_stat_database_*` - Database statistics
- ✅ `pg_settings_*` - PostgreSQL configuration
- ✅ `pg_stat_bgwriter_*` - Background writer stats
- ✅ `pg_stat_user_tables_*` - Table statistics
- ✅ `pg_up` - Database availability

#### System Metrics (จาก node-exporter)
- ✅ `node_context_switches_total` - Context switches
- ✅ `node_cpu_seconds_total` - CPU usage
- ✅ `node_memory_*` - Memory metrics
- ✅ `node_disk_*` - Disk I/O metrics

### 🎯 การใช้งาน Dashboard

**ระหว่าง Load Test:**
1. เปิด Dashboard ก่อนรัน test
2. ตั้ง Time Range = "Last 5 minutes"
3. ตั้ง Refresh = "5s"
4. รัน load test
5. สังเกต metrics real-time

**หลัง Load Test:**
1. ตั้ง Time Range ให้ครอบคลุมช่วงที่ test
2. ดู peak values ใน legend
3. Export หรือ screenshot สำหรับเปรียบเทียบ

## ⚙️ PostgreSQL Tuning Configurations

### Default Configuration

ใช้สำหรับ baseline testing:
- `shared_buffers = 128MB`
- `max_connections = 100`
- `work_mem = 4MB`
- `effective_cache_size = 4GB`

### Tuned Configuration

ปรับแต่งสำหรับ high-performance:
- `shared_buffers = 2GB`
- `max_connections = 200`
- `work_mem = 16MB`
- `effective_cache_size = 6GB`
- `synchronous_commit = off`
- `random_page_cost = 1.1`
- `effective_io_concurrency = 200`

### สลับไปใช้ Tuned Configuration

```bash
# Switch to tuned config (recommended)
./scripts/switch-to-tuned-config.sh
```

**Script จะทำอัตโนมัติ:**
- ✅ Apply tuned ConfigMap
- ✅ Update StatefulSet environment variables
- ✅ Update volume configuration
- ✅ Restart PostgreSQL pod
- ✅ Wait for pod ready

**หรือทำ manual:**
```bash
kubectl apply -f k8s/postgres/configmap-tuned.yaml
kubectl set env statefulset/postgres -n corebank --from=configmap/postgres-config-tuned
kubectl delete pod postgres-0 -n corebank
```

### เปรียบเทียบผลลัพธ์

1. รัน load test กับ Default Config
2. บันทึกผลลัพธ์จาก Grafana
3. Switch ไปใช้ Tuned Config
4. รัน load test อีกครั้ง
5. เปรียบเทียบ TPS, Latency, Resource Usage

## 🔄 การใช้งาน PgBouncer

### เปิดใช้งาน PgBouncer

แก้ไข `k8s/app/configmap.yaml`:
```yaml
# Comment out direct connection
# DATABASE_URL: "postgresql://postgres:postgres@postgres.corebank.svc.cluster.local:5432/corebank"

# Uncomment PgBouncer connection
DATABASE_URL: "postgresql://postgres:postgres@pgbouncer.corebank.svc.cluster.local:6432/corebank"
```

```bash
# Apply changes
kubectl apply -f k8s/app/configmap.yaml
kubectl rollout restart deployment/corebank-api -n corebank
```

### เปรียบเทียบ Direct vs PgBouncer

รัน load tests และเปรียบเทียบ:
- Connection overhead
- Query throughput
- Resource usage
- Latency

## 🧹 การลบทิ้ง

```bash
./scripts/cleanup.sh
```

## 📁 โครงสร้าง Project

```
pg-perf-tuning-guide/
├── src/
│   ├── domain/              # Domain layer (Business logic)
│   ├── application/         # Application layer (Use cases)
│   ├── infrastructure/      # Infrastructure layer (DB, Web)
│   └── main.rs
├── migrations/              # Database migrations (SQL)
├── k8s/                     # Kubernetes manifests
│   ├── namespace.yaml
│   ├── postgres/            # PostgreSQL StatefulSet & configs
│   ├── pgbouncer/           # PgBouncer deployment
│   ├── app/                 # Application deployment & configs
│   └── monitoring/          # Prometheus, Grafana, Exporters
├── scripts/
│   ├── seed-data.rs         # Data seeding binary (100k accounts)
│   ├── load-tester.rs       # Load testing binary (Rust + CSV reports)
│   ├── deploy.sh            # Main deployment script
│   ├── seed-database.sh     # Seed database script
│   ├── run-load-test.sh     # Run single load test
│   ├── performance-test-suite.sh  # Full test suite + reports
│   ├── collect-reports.sh   # Collect CSV reports from pods
│   ├── generate-summary-report.sh # Generate summary report
│   ├── switch-to-tuned-config.sh  # Switch to tuned config
│   └── cleanup.sh           # Cleanup script
├── reports/                 # CSV reports (auto-generated)
│   ├── loadtest_*.csv       # Individual test reports
│   └── SUMMARY_*.csv        # Consolidated summary reports
├── docs/
│   ├── ARCHITECTURE.md      # Architecture documentation
│   └── PERFORMANCE_TUNING_GUIDE.md  # Performance tuning guide
├── Dockerfile               # Multi-stage build
├── Cargo.toml              # Rust dependencies
├── .env                    # Environment variables
└── README.md               # This file
```

## 🎓 การทดสอบที่แนะนำ

### Scenario 1: Baseline Performance
1. Deploy ด้วย default config
2. Seed 100k accounts
3. รัน mixed load test
4. บันทึก metrics

### Scenario 2: Tuned Configuration
1. Switch to tuned config
2. รัน mixed load test
3. เปรียบเทียบกับ baseline

### Scenario 3: PgBouncer Impact
1. เปิดใช้งาน PgBouncer
2. รัน heavy-read test
3. เปรียบเทียบ connection overhead

### Scenario 4: Stress Testing
1. เพิ่ม concurrency ใน load test
2. ตรวจสอบ context switching
3. ดู resource limits

## 📚 เอกสารเพิ่มเติม

### Architecture Documentation
รายละเอียดสถาปัตยกรรมระบบ, Clean Architecture layers, และ deployment architecture

👉 **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**

### Performance Tuning Guide
คู่มือการ tune PostgreSQL parameters ตาม metrics ที่เห็นใน Grafana Dashboard

👉 **[docs/PERFORMANCE_TUNING_GUIDE.md](docs/PERFORMANCE_TUNING_GUIDE.md)**

**เนื้อหาใน Performance Tuning Guide:**
- 📊 วิธีอ่าน metrics จาก dashboard แต่ละ panel
- ⚙️ PostgreSQL parameters ที่ควร tune
- 🎯 เป้าหมายของแต่ละ metric
- 🔧 วิธีแก้ปัญหาเมื่อ metrics ผิดปกติ
- ✅ Tuning checklist สำหรับ workload แต่ละแบบ
- 📈 Performance testing workflow

## 🐛 Troubleshooting

### PostgreSQL ไม่ขึ้น
```bash
kubectl logs -n corebank postgres-0
kubectl describe pod -n corebank postgres-0
```

### Application ไม่สามารถเชื่อมต่อ Database
```bash
kubectl exec -it -n corebank postgres-0 -- psql -U postgres -d corebank
# ตรวจสอบว่า database สร้างแล้ว
```

### Load Test ล้มเหลว
```bash
# ตรวจสอบว่า API พร้อมใช้งาน
kubectl port-forward -n corebank svc/corebank-api 8080:8080
curl http://localhost:8080/health
```

## 📝 License

MIT License

## 👥 Contributors

สร้างโดย: [Your Name]

---

**Happy Performance Tuning! 🚀**
