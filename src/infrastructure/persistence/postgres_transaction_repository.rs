use async_trait::async_trait;
use sqlx::PgPool;
use uuid::Uuid;
use crate::domain::entities::Transaction;
use crate::domain::repositories::TransactionRepository;
use crate::domain::errors::DomainError;

pub struct PostgresTransactionRepository {
    pool: PgPool,
}

impl PostgresTransactionRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl TransactionRepository for PostgresTransactionRepository {
    async fn create(&self, transaction: &Transaction) -> Result<Transaction, DomainError> {
        let result = sqlx::query_as::<_, Transaction>(
            r#"
            INSERT INTO transactions (id, transaction_ref, from_account_id, to_account_id, transaction_type, amount, currency, description, status, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING *
            "#
        )
        .bind(&transaction.id)
        .bind(&transaction.transaction_ref)
        .bind(&transaction.from_account_id)
        .bind(&transaction.to_account_id)
        .bind(&transaction.transaction_type)
        .bind(&transaction.amount)
        .bind(&transaction.currency)
        .bind(&transaction.description)
        .bind(&transaction.status)
        .bind(&transaction.created_at)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result)
    }

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Transaction>, DomainError> {
        let result = sqlx::query_as::<_, Transaction>(
            "SELECT * FROM transactions WHERE id = $1"
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result)
    }

    async fn find_by_account(&self, account_id: Uuid, limit: i64, offset: i64) -> Result<Vec<Transaction>, DomainError> {
        let results = sqlx::query_as::<_, Transaction>(
            r#"
            SELECT * FROM transactions 
            WHERE from_account_id = $1 OR to_account_id = $1
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

    async fn count_by_account(&self, account_id: Uuid) -> Result<i64, DomainError> {
        let result: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM transactions WHERE from_account_id = $1 OR to_account_id = $1"
        )
        .bind(account_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result.0)
    }
}
