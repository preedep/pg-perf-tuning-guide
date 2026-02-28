use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use rust_decimal::Decimal;

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct LedgerEntry {
    pub id: Uuid,
    pub transaction_id: Uuid,
    pub account_id: Uuid,
    pub entry_type: String,
    pub amount: Decimal,
    pub balance_before: Decimal,
    pub balance_after: Decimal,
    pub created_at: DateTime<Utc>,
}

impl LedgerEntry {
    pub fn new(
        transaction_id: Uuid,
        account_id: Uuid,
        entry_type: String,
        amount: Decimal,
        balance_before: Decimal,
        balance_after: Decimal,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            transaction_id,
            account_id,
            entry_type,
            amount,
            balance_before,
            balance_after,
            created_at: Utc::now(),
        }
    }
}
