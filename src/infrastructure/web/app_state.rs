use std::sync::Arc;
use crate::application::services::{AccountService, TransactionService};

#[derive(Clone)]
pub struct AppState {
    pub account_service: Arc<AccountService>,
    pub transaction_service: Arc<TransactionService>,
}

impl AppState {
    pub fn new(
        account_service: Arc<AccountService>,
        transaction_service: Arc<TransactionService>,
    ) -> Self {
        Self {
            account_service,
            transaction_service,
        }
    }
}
