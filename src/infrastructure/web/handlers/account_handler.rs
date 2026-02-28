use actix_web::{web, HttpResponse, Responder};
use uuid::Uuid;
use crate::infrastructure::web::AppState;
use crate::application::dto::CreateAccountRequest;
use serde::Deserialize;

#[derive(Deserialize)]
pub struct ListQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

pub async fn create_account(
    state: web::Data<AppState>,
    req: web::Json<CreateAccountRequest>,
) -> impl Responder {
    match state.account_service.create_account(req.into_inner()).await {
        Ok(account) => HttpResponse::Created().json(account),
        Err(e) => HttpResponse::BadRequest().json(serde_json::json!({
            "error": e.to_string()
        })),
    }
}

pub async fn get_account(
    state: web::Data<AppState>,
    id: web::Path<Uuid>,
) -> impl Responder {
    match state.account_service.get_account(id.into_inner()).await {
        Ok(account) => HttpResponse::Ok().json(account),
        Err(e) => HttpResponse::NotFound().json(serde_json::json!({
            "error": e.to_string()
        })),
    }
}

pub async fn get_account_by_number(
    state: web::Data<AppState>,
    account_number: web::Path<String>,
) -> impl Responder {
    match state.account_service.get_account_by_number(&account_number).await {
        Ok(account) => HttpResponse::Ok().json(account),
        Err(e) => HttpResponse::NotFound().json(serde_json::json!({
            "error": e.to_string()
        })),
    }
}

pub async fn list_accounts(
    state: web::Data<AppState>,
    query: web::Query<ListQuery>,
) -> impl Responder {
    let limit = query.limit.unwrap_or(50);
    let offset = query.offset.unwrap_or(0);

    match state.account_service.list_accounts(limit, offset).await {
        Ok(accounts) => HttpResponse::Ok().json(accounts),
        Err(e) => HttpResponse::InternalServerError().json(serde_json::json!({
            "error": e.to_string()
        })),
    }
}

pub async fn get_balance(
    state: web::Data<AppState>,
    account_number: web::Path<String>,
) -> impl Responder {
    match state.account_service.get_account_by_number(&account_number).await {
        Ok(account) => HttpResponse::Ok().json(serde_json::json!({
            "account_number": account.account_number,
            "balance": account.balance,
            "currency": account.currency
        })),
        Err(e) => HttpResponse::NotFound().json(serde_json::json!({
            "error": e.to_string()
        })),
    }
}
