use actix_web::{web, HttpResponse, Responder};
use crate::infrastructure::web::AppState;
use crate::application::dto::{DepositRequest, WithdrawRequest, TransferRequest};

pub async fn deposit(
    state: web::Data<AppState>,
    req: web::Json<DepositRequest>,
) -> impl Responder {
    match state.transaction_service.deposit(req.into_inner()).await {
        Ok(transaction) => HttpResponse::Created().json(transaction),
        Err(e) => HttpResponse::BadRequest().json(serde_json::json!({
            "error": e.to_string()
        })),
    }
}

pub async fn withdraw(
    state: web::Data<AppState>,
    req: web::Json<WithdrawRequest>,
) -> impl Responder {
    match state.transaction_service.withdraw(req.into_inner()).await {
        Ok(transaction) => HttpResponse::Created().json(transaction),
        Err(e) => HttpResponse::BadRequest().json(serde_json::json!({
            "error": e.to_string()
        })),
    }
}

pub async fn transfer(
    state: web::Data<AppState>,
    req: web::Json<TransferRequest>,
) -> impl Responder {
    match state.transaction_service.transfer(req.into_inner()).await {
        Ok(transaction) => HttpResponse::Created().json(transaction),
        Err(e) => HttpResponse::BadRequest().json(serde_json::json!({
            "error": e.to_string()
        })),
    }
}
