use async_trait::async_trait;
use sqlx::PgPool;
use uuid::Uuid;
use crate::domain::entities::LedgerEntry;
use crate::domain::repositories::LedgerRepository;
use crate::domain::errors::DomainError;

pub struct PostgresLedgerRepository {
    pool: PgPool,
}

impl PostgresLedgerRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl LedgerRepository for PostgresLedgerRepository {
    async fn create(&self, entry: &LedgerEntry) -> Result<LedgerEntry, DomainError> {
        let result = sqlx::query_as::<_, LedgerEntry>(
            r#"
            INSERT INTO ledger_entries (id, transaction_id, account_id, entry_type, amount, balance_before, balance_after, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING *
            "#
        )
        .bind(&entry.id)
        .bind(&entry.transaction_id)
        .bind(&entry.account_id)
        .bind(&entry.entry_type)
        .bind(&entry.amount)
        .bind(&entry.balance_before)
        .bind(&entry.balance_after)
        .bind(&entry.created_at)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result)
    }

    async fn find_by_account(&self, account_id: Uuid, limit: i64, offset: i64) -> Result<Vec<LedgerEntry>, DomainError> {
        let results = sqlx::query_as::<_, LedgerEntry>(
            r#"
            SELECT * FROM ledger_entries 
            WHERE account_id = $1
            ORDER BY created_at DESC 
            LIMIT $2 OFFSET $3
            "#
        )
        .bind(account_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(results)
    }

    async fn find_by_transaction(&self, transaction_id: Uuid) -> Result<Vec<LedgerEntry>, DomainError> {
        let results = sqlx::query_as::<_, LedgerEntry>(
            "SELECT * FROM ledger_entries WHERE transaction_id = $1 ORDER BY created_at"
        )
        .bind(transaction_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(results)
    }
}
