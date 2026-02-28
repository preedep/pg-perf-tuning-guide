use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use rust_decimal::Decimal;

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Account {
    pub id: Uuid,
    pub account_number: String,
    pub customer_id: String,
    pub account_type: String,
    pub balance: Decimal,
    pub currency: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Account {
    pub fn new(
        account_number: String,
        customer_id: String,
        account_type: String,
        currency: String,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            account_number,
            customer_id,
            account_type,
            balance: Decimal::ZERO,
            currency,
            status: "ACTIVE".to_string(),
            created_at: now,
            updated_at: now,
        }
    }
}
