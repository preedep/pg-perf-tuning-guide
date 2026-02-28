use async_trait::async_trait;
use uuid::Uuid;
use crate::domain::entities::Transaction;
use crate::domain::errors::DomainError;

#[async_trait]
pub trait TransactionRepository: Send + Sync {
    async fn create(&self, transaction: &Transaction) -> Result<Transaction, DomainError>;
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Transaction>, DomainError>;
    async fn find_by_account(&self, account_id: Uuid, limit: i64, offset: i64) -> Result<Vec<Transaction>, DomainError>;
    async fn count_by_account(&self, account_id: Uuid) -> Result<i64, DomainError>;
}
