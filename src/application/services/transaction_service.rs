use std::sync::Arc;
use rust_decimal::Decimal;
use uuid::Uuid;
use sqlx::PgPool;
use crate::domain::entities::{Transaction, LedgerEntry};
use crate::domain::repositories::{AccountRepository, TransactionRepository, LedgerRepository};
use crate::domain::errors::DomainError;
use crate::application::dto::{DepositRequest, WithdrawRequest, TransferRequest, TransactionResponse};

pub struct TransactionService {
    account_repo: Arc<dyn AccountRepository>,
    transaction_repo: Arc<dyn TransactionRepository>,
    ledger_repo: Arc<dyn LedgerRepository>,
    pool: PgPool,
}

impl TransactionService {
    pub fn new(
        account_repo: Arc<dyn AccountRepository>,
        transaction_repo: Arc<dyn TransactionRepository>,
        ledger_repo: Arc<dyn LedgerRepository>,
        pool: PgPool,
    ) -> Self {
        Self {
            account_repo,
            transaction_repo,
            ledger_repo,
            pool,
        }
    }

    pub async fn deposit(&self, req: DepositRequest) -> Result<TransactionResponse, DomainError> {
        if req.amount <= Decimal::ZERO {
            return Err(DomainError::InvalidAmount("Amount must be positive".to_string()));
        }

        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        let mut account = self.account_repo.find_by_account_number(&req.account_number).await?
            .ok_or_else(|| DomainError::AccountNotFound(req.account_number.clone()))?;

        let balance_before = account.balance.clone();
        account.balance += &req.amount;
        
        let transaction = Transaction::new(
            Uuid::new_v4().to_string(),
            None,
            Some(account.id),
            "DEPOSIT".to_string(),
            req.amount.clone(),
            account.currency.clone(),
            req.description,
        );

        let created_tx = self.transaction_repo.create(&transaction).await?;

        let ledger = LedgerEntry::new(
            created_tx.id,
            account.id,
            "CREDIT".to_string(),
            req.amount,
            balance_before,
            account.balance.clone(),
        );

        self.ledger_repo.create(&ledger).await?;
        self.account_repo.update(&account).await?;

        tx.commit().await
            .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(self.to_response(&created_tx))
    }

    pub async fn withdraw(&self, req: WithdrawRequest) -> Result<TransactionResponse, DomainError> {
        if req.amount <= Decimal::ZERO {
            return Err(DomainError::InvalidAmount("Amount must be positive".to_string()));
        }

        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        let mut account = self.account_repo.find_by_account_number(&req.account_number).await?
            .ok_or_else(|| DomainError::AccountNotFound(req.account_number.clone()))?;

        if account.balance < req.amount {
            return Err(DomainError::InsufficientBalance {
                available: account.balance.to_string(),
                required: req.amount.to_string(),
            });
        }

        let balance_before = account.balance.clone();
        account.balance -= &req.amount;

        let transaction = Transaction::new(
            Uuid::new_v4().to_string(),
            Some(account.id),
            None,
            "WITHDRAWAL".to_string(),
            req.amount.clone(),
            account.currency.clone(),
            req.description,
        );

        let created_tx = self.transaction_repo.create(&transaction).await?;

        let ledger = LedgerEntry::new(
            created_tx.id,
            account.id,
            "DEBIT".to_string(),
            req.amount,
            balance_before,
            account.balance.clone(),
        );

        self.ledger_repo.create(&ledger).await?;
        self.account_repo.update(&account).await?;

        tx.commit().await
            .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(self.to_response(&created_tx))
    }

    pub async fn transfer(&self, req: TransferRequest) -> Result<TransactionResponse, DomainError> {
        if req.amount <= Decimal::ZERO {
            return Err(DomainError::InvalidAmount("Amount must be positive".to_string()));
        }

        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        let mut from_account = self.account_repo.find_by_account_number(&req.from_account_number).await?
            .ok_or_else(|| DomainError::AccountNotFound(req.from_account_number.clone()))?;

        let mut to_account = self.account_repo.find_by_account_number(&req.to_account_number).await?
            .ok_or_else(|| DomainError::AccountNotFound(req.to_account_number.clone()))?;

        if from_account.balance < req.amount {
            return Err(DomainError::InsufficientBalance {
                available: from_account.balance.to_string(),
                required: req.amount.to_string(),
            });
        }

        let from_balance_before = from_account.balance.clone();
        let to_balance_before = to_account.balance.clone();

        from_account.balance -= &req.amount;
        to_account.balance += &req.amount;

        let transaction = Transaction::new(
            Uuid::new_v4().to_string(),
            Some(from_account.id),
            Some(to_account.id),
            "TRANSFER".to_string(),
            req.amount.clone(),
            from_account.currency.clone(),
            req.description,
        );

        let created_tx = self.transaction_repo.create(&transaction).await?;

        let debit_ledger = LedgerEntry::new(
            created_tx.id,
            from_account.id,
            "DEBIT".to_string(),
            req.amount.clone(),
            from_balance_before,
            from_account.balance.clone(),
        );

        let credit_ledger = LedgerEntry::new(
            created_tx.id,
            to_account.id,
            "CREDIT".to_string(),
            req.amount,
            to_balance_before,
            to_account.balance.clone(),
        );

        self.ledger_repo.create(&debit_ledger).await?;
        self.ledger_repo.create(&credit_ledger).await?;
        self.account_repo.update(&from_account).await?;
        self.account_repo.update(&to_account).await?;

        tx.commit().await
            .map_err(|e| DomainError::DatabaseError(e.to_string()))?;

        Ok(self.to_response(&created_tx))
    }

    fn to_response(&self, transaction: &Transaction) -> TransactionResponse {
        TransactionResponse {
            id: transaction.id,
            transaction_ref: transaction.transaction_ref.clone(),
            from_account_id: transaction.from_account_id,
            to_account_id: transaction.to_account_id,
            transaction_type: transaction.transaction_type.clone(),
            amount: transaction.amount.clone(),
            currency: transaction.currency.clone(),
            description: transaction.description.clone(),
            status: transaction.status.clone(),
        }
    }
}
