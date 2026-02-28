use async_trait::async_trait;
use sqlx::PgPool;
use uuid::Uuid;
use crate::domain::entities::Account;
use crate::domain::repositories::AccountRepository;
use crate::domain::errors::DomainError;

pub struct PostgresAccountRepository {
    pool: PgPool,
}

impl PostgresAccountRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl AccountRepository for PostgresAccountRepository {
    async fn create(&self, account: &Account) -> Result<Account, DomainError> {
        let result = sqlx::query_as::<_, Account>(
            r#"
            INSERT INTO accounts (id, account_number, customer_id, account_type, balance, currency, status, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
            "#
        )
        .bind(&account.id)
        .bind(&account.account_number)
        .bind(&account.customer_id)
        .bind(&account.account_type)
        .bind(&account.balance)
        .bind(&account.currency)
        .bind(&account.status)
        .bind(&account.created_at)
        .bind(&account.updated_at)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result)
    }

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Account>, DomainError> {
        let result = sqlx::query_as::<_, Account>(
            "SELECT * FROM accounts WHERE id = $1"
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result)
    }

    async fn find_by_account_number(&self, account_number: &str) -> Result<Option<Account>, DomainError> {
        let result = sqlx::query_as::<_, Account>(
            "SELECT * FROM accounts WHERE account_number = $1"
        )
        .bind(account_number)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result)
    }

    async fn update(&self, account: &Account) -> Result<Account, DomainError> {
        let result = sqlx::query_as::<_, Account>(
            r#"
            UPDATE accounts 
            SET balance = $1, updated_at = $2
            WHERE id = $3
            RETURNING *
            "#
        )
        .bind(&account.balance)
        .bind(&account.updated_at)
        .bind(&account.id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result)
    }

    async fn list(&self, limit: i64, offset: i64) -> Result<Vec<Account>, DomainError> {
        let results = sqlx::query_as::<_, Account>(
            "SELECT * FROM accounts ORDER BY created_at DESC LIMIT $1 OFFSET $2"
        )
        .bind(limit)
        .bind(offset)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(results)
    }

    async fn count(&self) -> Result<i64, DomainError> {
        let result: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM accounts"
        )
        .fetch_one(&self.pool)
        .await
        .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(result.0)
    }
}
