use actix_web::web;
use crate::infrastructure::web::handlers::{
    account_handler, transaction_handler, health_handler,
};

pub fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api/v1")
            .service(
                web::scope("/accounts")
                    .route("", web::post().to(account_handler::create_account))
                    .route("", web::get().to(account_handler::list_accounts))
                    .route("/{id}", web::get().to(account_handler::get_account))
                    .route("/number/{account_number}", web::get().to(account_handler::get_account_by_number))
                    .route("/balance/{account_number}", web::get().to(account_handler::get_balance))
            )
            .service(
                web::scope("/transactions")
                    .route("/deposit", web::post().to(transaction_handler::deposit))
                    .route("/withdraw", web::post().to(transaction_handler::withdraw))
                    .route("/transfer", web::post().to(transaction_handler::transfer))
            )
    )
    .route("/health", web::get().to(health_handler::health_check))
    .route("/ready", web::get().to(health_handler::readiness_check));
}
