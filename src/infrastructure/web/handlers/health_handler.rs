use actix_web::{web, HttpResponse, Responder};
use serde_json::json;

pub async fn health_check() -> impl Responder {
    HttpResponse::Ok().json(json!({
        "status": "healthy",
        "service": "core-banking-api"
    }))
}

pub async fn readiness_check() -> impl Responder {
    HttpResponse::Ok().json(json!({
        "status": "ready"
    }))
}
