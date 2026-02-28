use thiserror::Error;

#[derive(Error, Debug)]
pub enum DomainError {
    #[error("Account not found: {0}")]
    AccountNotFound(String),
    
    #[error("Insufficient balance: available {available}, required {required}")]
    InsufficientBalance { available: String, required: String },
    
    #[error("Invalid amount: {0}")]
    InvalidAmount(String),
    
    #[error("Transaction failed: {0}")]
    TransactionFailed(String),
    
    #[error("Database error: {0}")]
    DatabaseError(String),
    
    #[error("Validation error: {0}")]
    ValidationError(String),
}
