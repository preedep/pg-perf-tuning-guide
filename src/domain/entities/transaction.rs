use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use rust_decimal::Decimal;

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "transaction_type", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TransactionType {
    Deposit,
    Withdrawal,
    Transfer,
    Fee,
    Interest,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Transaction {
    pub id: Uuid,
    pub transaction_ref: String,
    pub from_account_id: Option<Uuid>,
    pub to_account_id: Option<Uuid>,
    pub transaction_type: String,
    pub amount: Decimal,
    pub currency: String,
    pub description: Option<String>,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

impl Transaction {
    pub fn new(
        transaction_ref: String,
        from_account_id: Option<Uuid>,
        to_account_id: Option<Uuid>,
        transaction_type: String,
        amount: Decimal,
        currency: String,
        description: Option<String>,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            transaction_ref,
            from_account_id,
            to_account_id,
            transaction_type,
            amount,
            currency,
            description,
            status: "COMPLETED".to_string(),
            created_at: Utc::now(),
        }
    }
}
