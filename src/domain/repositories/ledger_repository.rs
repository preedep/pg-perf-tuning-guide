use async_trait::async_trait;
use uuid::Uuid;
use crate::domain::entities::LedgerEntry;
use crate::domain::errors::DomainError;

#[async_trait]
pub trait LedgerRepository: Send + Sync {
    async fn create(&self, entry: &LedgerEntry) -> Result<LedgerEntry, DomainError>;
    async fn find_by_account(&self, account_id: Uuid, limit: i64, offset: i64) -> Result<Vec<LedgerEntry>, DomainError>;
    async fn find_by_transaction(&self, transaction_id: Uuid) -> Result<Vec<LedgerEntry>, DomainError>;
}
