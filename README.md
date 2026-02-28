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

# สร้าง .env file
cp .env.example .env
```

### 2. Build Docker Image

```bash
docker build -t corebank-api:latest .
```

### 3. Deploy ไปยัง Kubernetes

```bash
# ให้สิทธิ์ execute scripts
chmod +x scripts/*.sh

# Deploy ทั้งหมด (PostgreSQL, Monitoring, Application)
./scripts/deploy.sh
```

Script จะถามว่าต้องการติดตั้ง PgBouncer หรือไม่

### 4. Seed ข้อมูล 100,000 บัญชี

```bash
# วิธีที่ 1: รันจาก local (ต้อง port-forward ก่อน)
kubectl port-forward -n corebank svc/postgres 5432:5432 &
cargo run --bin seed-data

# วิธีที่ 2: รันใน Kubernetes
kubectl exec -it -n corebank postgres-0 -- bash
# จากนั้นรัน seed script
```

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

### วิธีรัน Load Test

#### 1. Heavy Read Test - Balance Inquiry
ทดสอบการตรวจสอบยอดเงิน (100% Read Operations)

```bash
# รันจาก Kubernetes
kubectl apply -f k8s/loadtest/job-heavy-read.yaml
kubectl logs -n corebank -f job/loadtest-heavy-read

# รันจาก local
cargo run --bin load-tester -- http://localhost:8080 heavy-read 50 300
# Parameters: <url> <test-type> <concurrency> <duration-seconds>
```

**API ที่ทดสอบ**: `GET /api/v1/accounts/balance/{account_number}`

#### 2. Heavy Write Test - Transfer
ทดสอบการโอนเงินระหว่างบัญชี (100% Write Operations)

```bash
kubectl apply -f k8s/loadtest/job-heavy-write.yaml
kubectl logs -n corebank -f job/loadtest-heavy-write

# หรือ
cargo run --bin load-tester -- http://localhost:8080 heavy-write 30 300
```

**API ที่ทดสอบ**: `POST /api/v1/transactions/transfer`

**Database Operations**:
- อ่าน 2 accounts (from + to)
- อัพเดท balance 2 accounts
- สร้าง 1 transaction
- สร้าง 2 ledger entries
- ทั้งหมดใน 1 transaction

#### 3. Mixed Load Test (60% Balance Inquiry, 40% Transfer)
ทดสอบแบบ realistic workload

```bash
kubectl apply -f k8s/loadtest/job-mixed-load.yaml
kubectl logs -n corebank -f job/loadtest-mixed-load

# หรือ
cargo run --bin load-tester -- http://localhost:8080 mixed 50 300
```

### ตัวอย่างผลลัพธ์

```
=== Load Test Results ===
Total Duration: 300.00s
Total Requests: 45230
Successful Requests: 45100
Failed Requests: 130
Success Rate: 99.71%
---
TPS (Transactions Per Second): 150.77
QPS (Queries Per Second): 150.77
---
Min Latency: 12ms
Avg Latency: 45.23ms
Max Latency: 523ms
========================
```

## 📊 การตรวจสอบและ Monitoring

### เข้าถึง Grafana

```bash
# ดู NodePort ของ Grafana
kubectl get svc -n corebank grafana

# เข้าถึงผ่าน browser
# http://localhost:<NodePort>
# Username: admin
# Password: admin
```

### เข้าถึง Prometheus

```bash
kubectl get svc -n corebank prometheus
# http://localhost:<NodePort>
```

### Metrics ที่ติดตาม

#### PostgreSQL Metrics
- **Connections**: จำนวน active connections
- **TPS**: Transactions per second
- **Cache Hit Ratio**: ประสิทธิภาพ cache
- **Query Duration**: เวลาในการ execute queries
- **Locks**: จำนวน locks ในระบบ
- **Table Bloat**: Dead tuples

#### System Metrics
- **CPU Usage**: การใช้งาน CPU
- **Memory Usage**: การใช้งาน RAM
- **Disk I/O**: การอ่าน/เขียน disk
- **Context Switches**: จำนวน context switches (สำคัญสำหรับ performance)

### Grafana Dashboards

Dashboard ที่สร้างไว้แล้ว:
1. **PostgreSQL Performance Dashboard**
   - Database connections
   - Transaction rate
   - Query performance
   - Cache efficiency
   - Lock monitoring
   - Context switching
   - Resource usage

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
# Apply tuned configuration
kubectl apply -f k8s/postgres/configmap-tuned.yaml

# Switch to tuned config
./scripts/switch-to-tuned-config.sh
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
│   ├── domain/              # Domain layer
│   ├── application/         # Application layer
│   ├── infrastructure/      # Infrastructure layer
│   └── main.rs
├── migrations/              # Database migrations
├── k8s/                     # Kubernetes manifests
│   ├── namespace.yaml
│   ├── postgres/            # PostgreSQL configs
│   ├── pgbouncer/           # PgBouncer configs
│   ├── app/                 # Application configs
│   ├── monitoring/          # Prometheus & Grafana
│   └── loadtest/            # Load test jobs
├── scripts/
│   ├── seed-data.rs         # Data seeding tool
│   ├── load-tester.rs       # Load testing tool
│   ├── deploy.sh            # Deployment script
│   ├── switch-to-tuned-config.sh
│   └── cleanup.sh
├── Dockerfile
├── Cargo.toml
└── README.md
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
