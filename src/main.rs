mod domain;
mod application;
mod infrastructure;

use std::sync::Arc;
use actix_web::{web, App, HttpServer};
use sqlx::postgres::PgPoolOptions;
use dotenv::dotenv;
use std::env;

use application::services::{AccountService, TransactionService};
use infrastructure::persistence::{
    PostgresAccountRepository, PostgresTransactionRepository, PostgresLedgerRepository,
};
use infrastructure::web::{AppState, configure_routes};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();
    env_logger::init();

    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    let max_connections = env::var("DATABASE_MAX_CONNECTIONS")
        .unwrap_or_else(|_| "10".to_string())
        .parse::<u32>()
        .expect("DATABASE_MAX_CONNECTIONS must be a number");
    let host = env::var("SERVER_HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
    let port = env::var("SERVER_PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .expect("SERVER_PORT must be a number");

    log::info!("Connecting to database...");
    let pool = PgPoolOptions::new()
        .max_connections(max_connections)
        .connect(&database_url)
        .await
        .expect("Failed to connect to database");

    log::info!("Running migrations...");
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("Failed to run migrations");

    let account_repo = Arc::new(PostgresAccountRepository::new(pool.clone()));
    let transaction_repo = Arc::new(PostgresTransactionRepository::new(pool.clone()));
    let ledger_repo = Arc::new(PostgresLedgerRepository::new(pool.clone()));

    let account_service = Arc::new(AccountService::new(account_repo.clone()));
    let transaction_service = Arc::new(TransactionService::new(
        account_repo,
        transaction_repo,
        ledger_repo,
        pool.clone(),
    ));

    let app_state = AppState::new(account_service, transaction_service);

    log::info!("Starting server at {}:{}", host, port);

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(app_state.clone()))
            .configure(configure_routes)
    })
    .bind((host.as_str(), port))?
    .run()
    .await
}
