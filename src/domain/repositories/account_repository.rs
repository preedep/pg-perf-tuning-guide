use async_trait::async_trait;
use uuid::Uuid;
use crate::domain::entities::Account;
use crate::domain::errors::DomainError;

#[async_trait]
pub trait AccountRepository: Send + Sync {
    async fn create(&self, account: &Account) -> Result<Account, DomainError>;
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Account>, DomainError>;
    async fn find_by_account_number(&self, account_number: &str) -> Result<Option<Account>, DomainError>;
    async fn update(&self, account: &Account) -> Result<Account, DomainError>;
    async fn list(&self, limit: i64, offset: i64) -> Result<Vec<Account>, DomainError>;
    async fn count(&self) -> Result<i64, DomainError>;
}
