use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;
use std::env;
use rand::Rng;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv::dotenv().ok();
    
    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    
    println!("Connecting to database...");
    let pool = PgPoolOptions::new()
        .max_connections(20)
        .connect(&database_url)
        .await?;
    
    println!("Starting to seed 100,000 accounts...");
    
    let mut rng = rand::thread_rng();
    let batch_size = 1000;
    let total_accounts = 100_000;
    
    for batch in 0..(total_accounts / batch_size) {
        let mut tx = pool.begin().await?;
        
        for i in 0..batch_size {
            let account_number = format!("ACC{:08}", batch * batch_size + i);
            let customer_id = format!("CUST{:08}", batch * batch_size + i);
            let account_type = if rng.gen_bool(0.7) { "SAVINGS" } else { "CHECKING" };
            let balance = rng.gen_range(1000.0..1000000.0);
            
            sqlx::query(
                r#"
                INSERT INTO accounts (id, account_number, customer_id, account_type, balance, currency, status, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, 'THB', 'ACTIVE', NOW(), NOW())
                "#
            )
            .bind(Uuid::new_v4())
            .bind(&account_number)
            .bind(&customer_id)
            .bind(account_type)
            .bind(balance)
            .execute(&mut *tx)
            .await?;
        }
        
        tx.commit().await?;
        
        if (batch + 1) % 10 == 0 {
            println!("Seeded {} accounts...", (batch + 1) * batch_size);
        }
    }
    
    println!("Successfully seeded 100,000 accounts!");
    
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM accounts")
        .fetch_one(&pool)
        .await?;
    
    println!("Total accounts in database: {}", count.0);
    
    Ok(())
}
