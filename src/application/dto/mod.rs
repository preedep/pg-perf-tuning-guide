use serde::{Deserialize, Serialize};
use uuid::Uuid;
use rust_decimal::Decimal;

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateAccountRequest {
    pub account_number: String,
    pub customer_id: String,
    pub account_type: String,
    pub currency: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DepositRequest {
    pub account_number: String,
    pub amount: Decimal,
    pub description: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WithdrawRequest {
    pub account_number: String,
    pub amount: Decimal,
    pub description: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TransferRequest {
    pub from_account_number: String,
    pub to_account_number: String,
    pub amount: Decimal,
    pub description: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AccountResponse {
    pub id: Uuid,
    pub account_number: String,
    pub customer_id: String,
    pub account_type: String,
    pub balance: Decimal,
    pub currency: String,
    pub status: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TransactionResponse {
    pub id: Uuid,
    pub transaction_ref: String,
    pub from_account_id: Option<Uuid>,
    pub to_account_id: Option<Uuid>,
    pub transaction_type: String,
    pub amount: Decimal,
    pub currency: String,
    pub description: Option<String>,
    pub status: String,
}
