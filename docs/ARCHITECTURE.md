# Architecture Documentation

## 🏗️ System Architecture

### Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (corebank namespace)       │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Application Layer                        │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │         Corebank API (3 replicas)                  │  │  │
│  │  │  - Actix-Web REST API                              │  │  │
│  │  │  - Clean Architecture (Domain/App/Infra)           │  │  │
│  │  │  - Health checks, Metrics                          │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Connection Pooling Layer                     │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │         PgBouncer (2 replicas)                     │  │  │
│  │  │  - Transaction pooling mode                        │  │  │
│  │  │  - Max 1000 client connections                     │  │  │
│  │  │  - Pool size: 25 per database                      │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 Database Layer                            │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │         PostgreSQL 16 (StatefulSet)                │  │  │
│  │  │  - Persistent Volume (10Gi)                        │  │  │
│  │  │  - Tunable configurations                          │  │  │
│  │  │  - Database: corebank                              │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Monitoring & Observability                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────────────┐ │  │
│  │  │Prometheus│  │ Grafana  │  │   Exporters            │ │  │
│  │  │  :9090   │  │  :30030  │  │ - PostgreSQL Exporter  │ │  │
│  │  │          │◄─┤          │◄─┤ - Node Exporter        │ │  │
│  │  │          │  │          │  │                        │ │  │
│  │  └──────────┘  └──────────┘  └────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Clean Architecture Layers

### 1. Domain Layer (`src/domain/`)

**Purpose:** Business logic และ core entities

```
domain/
├── entities/
│   ├── account.rs      # Account entity
│   ├── transaction.rs  # Transaction entity
│   └── ledger.rs       # Ledger entry entity
├── repositories/
│   ├── account_repository.rs      # Account repository trait
│   ├── transaction_repository.rs  # Transaction repository trait
│   └── ledger_repository.rs       # Ledger repository trait
└── errors.rs           # Domain-specific errors
```

**Principles:**
- ✅ ไม่มี dependencies กับ infrastructure
- ✅ Pure business logic
- ✅ Framework-agnostic
- ✅ Testable without external dependencies

### 2. Application Layer (`src/application/`)

**Purpose:** Use cases และ application services

```
application/
├── services/
│   ├── account_service.rs      # Account business logic
│   ├── transaction_service.rs  # Transaction business logic
│   └── balance_service.rs      # Balance inquiry logic
└── dto/
    ├── account_dto.rs          # Account DTOs
    ├── transaction_dto.rs      # Transaction DTOs
    └── response_dto.rs         # API responses
```

**Responsibilities:**
- ✅ Orchestrate domain entities
- ✅ Implement use cases
- ✅ Transaction management
- ✅ Business validations

### 3. Infrastructure Layer (`src/infrastructure/`)

**Purpose:** External integrations และ technical implementations

```
infrastructure/
├── persistence/
│   ├── postgres/
│   │   ├── account_repository_impl.rs      # PostgreSQL account repo
│   │   ├── transaction_repository_impl.rs  # PostgreSQL transaction repo
│   │   └── ledger_repository_impl.rs       # PostgreSQL ledger repo
│   └── connection.rs   # Database connection pool
└── web/
    ├── handlers/
    │   ├── account_handler.rs      # Account HTTP handlers
    │   ├── transaction_handler.rs  # Transaction HTTP handlers
    │   └── health_handler.rs       # Health check handlers
    ├── routes.rs       # Route definitions
    └── middleware.rs   # HTTP middleware
```

**Responsibilities:**
- ✅ Database implementations
- ✅ HTTP handlers
- ✅ External API calls
- ✅ Infrastructure concerns

---

## 🗄️ Database Schema

### Tables

#### 1. accounts
```sql
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    customer_id VARCHAR(50) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    balance NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'THB',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_accounts_account_number ON accounts(account_number);
CREATE INDEX idx_accounts_customer_id ON accounts(customer_id);
CREATE INDEX idx_accounts_created_at ON accounts(created_at);
```

#### 2. transactions
```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_ref VARCHAR(50) UNIQUE NOT NULL,
    from_account_id UUID REFERENCES accounts(id),
    to_account_id UUID REFERENCES accounts(id),
    transaction_type VARCHAR(20) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'THB',
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_from_account ON transactions(from_account_id);
CREATE INDEX idx_transactions_to_account ON transactions(to_account_id);
CREATE INDEX idx_transactions_ref ON transactions(transaction_ref);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
```

#### 3. ledger_entries
```sql
CREATE TABLE ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id),
    account_id UUID NOT NULL REFERENCES accounts(id),
    entry_type VARCHAR(10) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    balance_before NUMERIC(15,2) NOT NULL,
    balance_after NUMERIC(15,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ledger_transaction ON ledger_entries(transaction_id);
CREATE INDEX idx_ledger_account ON ledger_entries(account_id);
CREATE INDEX idx_ledger_created_at ON ledger_entries(created_at);
CREATE INDEX idx_ledger_account_created ON ledger_entries(account_id, created_at);
```

---

## 🔄 Transaction Flow

### Transfer Transaction Flow

```
1. HTTP Request
   POST /api/v1/transactions/transfer
   {
     "from_account_number": "ACC00000001",
     "to_account_number": "ACC00000002",
     "amount": 500.00
   }
   │
   ▼
2. Handler Layer (infrastructure/web/handlers/transaction_handler.rs)
   - Validate request
   - Parse DTO
   │
   ▼
3. Service Layer (application/services/transaction_service.rs)
   - Begin database transaction
   - Get from_account (SELECT FOR UPDATE)
   - Get to_account (SELECT FOR UPDATE)
   - Validate balances
   │
   ▼
4. Domain Layer (domain/entities/)
   - Calculate new balances
   - Create transaction entity
   - Create ledger entries
   │
   ▼
5. Repository Layer (infrastructure/persistence/postgres/)
   - Update from_account balance
   - Update to_account balance
   - Insert transaction record
   - Insert 2 ledger entries (DEBIT, CREDIT)
   - Commit transaction
   │
   ▼
6. Response
   {
     "transaction_id": "uuid",
     "status": "COMPLETED",
     "from_balance": 500.00,
     "to_balance": 1500.00
   }
```

---

## 📊 Monitoring Architecture

### Metrics Collection Flow

```
PostgreSQL
    │
    ├─► PostgreSQL Exporter (port 9187)
    │   └─► Exposes metrics:
    │       - pg_stat_database_*
    │       - pg_settings_*
    │       - pg_stat_bgwriter_*
    │
    ▼
Prometheus (port 9090)
    │   - Scrapes every 15s
    │   - Stores time-series data
    │   - Retention: 15 days
    │
    ▼
Grafana (port 30030)
    │   - Queries Prometheus
    │   - Visualizes dashboards
    │   - Alerts (optional)
    │
    ▼
Dashboard: PostgreSQL Performance Tuning
    - 11 panels
    - Auto-refresh: 5s
    - Time range: Last 15m
```

### System Metrics Collection

```
Node (Kubernetes)
    │
    ├─► Node Exporter (port 9100)
    │   └─► Exposes metrics:
    │       - node_cpu_*
    │       - node_memory_*
    │       - node_disk_*
    │       - node_context_switches_total
    │
    ▼
Prometheus
    ▼
Grafana Dashboard
```

---

## 🚀 Deployment Architecture

### Kubernetes Resources

```yaml
Namespace: corebank
│
├── StatefulSet: postgres
│   ├── Replicas: 1
│   ├── PVC: postgres-data (10Gi)
│   └── Service: postgres (ClusterIP)
│
├── Deployment: pgbouncer
│   ├── Replicas: 2
│   └── Service: pgbouncer (ClusterIP)
│
├── Deployment: corebank-api
│   ├── Replicas: 3
│   ├── ConfigMap: app-config
│   └── Service: corebank-api (NodePort 30080)
│
├── Deployment: prometheus
│   ├── Replicas: 1
│   ├── ConfigMap: prometheus-config
│   └── Service: prometheus (NodePort 30508)
│
├── Deployment: grafana
│   ├── Replicas: 1
│   ├── ConfigMap: grafana-datasources
│   ├── ConfigMap: grafana-dashboards-config
│   ├── ConfigMap: grafana-dashboards
│   └── Service: grafana (NodePort 30030)
│
├── Deployment: postgres-exporter
│   ├── Replicas: 1
│   └── Service: postgres-exporter (ClusterIP)
│
└── DaemonSet: node-exporter
    ├── Runs on all nodes
    └── Service: node-exporter (ClusterIP)
```

---

## 🔐 Security Considerations

### Database Security
- ✅ PostgreSQL password authentication
- ✅ Network policies (ClusterIP services)
- ✅ No external database exposure
- ⚠️ Default passwords (change in production)

### Application Security
- ✅ Health check endpoints
- ✅ Graceful shutdown
- ⚠️ No authentication/authorization (demo only)
- ⚠️ No rate limiting (add in production)

### Monitoring Security
- ✅ Grafana anonymous access (read-only)
- ✅ Prometheus internal only
- ⚠️ No TLS (add in production)

---

## 📈 Scalability

### Horizontal Scaling

**Application (corebank-api):**
```bash
kubectl scale deployment corebank-api -n corebank --replicas=5
```

**PgBouncer:**
```bash
kubectl scale deployment pgbouncer -n corebank --replicas=3
```

**PostgreSQL:**
- ⚠️ StatefulSet (single instance)
- For production: Use PostgreSQL replication
  - Primary-Replica setup
  - Read replicas for read-heavy workload

### Vertical Scaling

**PostgreSQL Resources:**
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

**Application Resources:**
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

---

## 🔄 High Availability (Future)

### PostgreSQL HA Setup
- Primary-Replica with automatic failover
- Use Patroni or Stolon
- Synchronous replication for critical data

### Application HA
- ✅ Already implemented (3 replicas)
- ✅ Kubernetes handles pod failures
- ✅ Load balancing via Service

### Monitoring HA
- Add Prometheus federation
- Multiple Grafana instances
- AlertManager for notifications
