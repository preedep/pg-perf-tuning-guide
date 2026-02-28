use std::sync::Arc;
use uuid::Uuid;
use crate::domain::entities::Account;
use crate::domain::repositories::AccountRepository;
use crate::domain::errors::DomainError;
use crate::application::dto::{CreateAccountRequest, AccountResponse};

pub struct AccountService {
    account_repo: Arc<dyn AccountRepository>,
}

impl AccountService {
    pub fn new(account_repo: Arc<dyn AccountRepository>) -> Self {
        Self { account_repo }
    }

    pub async fn create_account(&self, req: CreateAccountRequest) -> Result<AccountResponse, DomainError> {
        let account = Account::new(
            req.account_number,
            req.customer_id,
            req.account_type,
            req.currency,
        );

        let created = self.account_repo.create(&account).await?;
        Ok(self.to_response(&created))
    }

    pub async fn get_account(&self, id: Uuid) -> Result<AccountResponse, DomainError> {
        let account = self.account_repo.find_by_id(id).await?
            .ok_or_else(|| DomainError::AccountNotFound(id.to_string()))?;
        Ok(self.to_response(&account))
    }

    pub async fn get_account_by_number(&self, account_number: &str) -> Result<AccountResponse, DomainError> {
        let account = self.account_repo.find_by_account_number(account_number).await?
            .ok_or_else(|| DomainError::AccountNotFound(account_number.to_string()))?;
        Ok(self.to_response(&account))
    }

    pub async fn list_accounts(&self, limit: i64, offset: i64) -> Result<Vec<AccountResponse>, DomainError> {
        let accounts = self.account_repo.list(limit, offset).await?;
        Ok(accounts.iter().map(|a| self.to_response(a)).collect())
    }

    fn to_response(&self, account: &Account) -> AccountResponse {
        AccountResponse {
            id: account.id,
            account_number: account.account_number.clone(),
            customer_id: account.customer_id.clone(),
            account_type: account.account_type.clone(),
            balance: account.balance.clone(),
            currency: account.currency.clone(),
            status: account.status.clone(),
        }
    }
}
