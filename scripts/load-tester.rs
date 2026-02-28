use reqwest::Client;
use serde_json::json;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use std::env;
use rand::{Rng, SeedableRng};
use rand::rngs::StdRng;

#[derive(Debug, Clone)]
struct Stats {
    total_requests: u64,
    successful_requests: u64,
    failed_requests: u64,
    total_latency_ms: u64,
    min_latency_ms: u64,
    max_latency_ms: u64,
}

impl Stats {
    fn new() -> Self {
        Self {
            total_requests: 0,
            successful_requests: 0,
            failed_requests: 0,
            total_latency_ms: 0,
            min_latency_ms: u64::MAX,
            max_latency_ms: 0,
        }
    }

    fn record(&mut self, success: bool, latency_ms: u64) {
        self.total_requests += 1;
        if success {
            self.successful_requests += 1;
        } else {
            self.failed_requests += 1;
        }
        self.total_latency_ms += latency_ms;
        self.min_latency_ms = self.min_latency_ms.min(latency_ms);
        self.max_latency_ms = self.max_latency_ms.max(latency_ms);
    }

    fn avg_latency_ms(&self) -> f64 {
        if self.total_requests > 0 {
            self.total_latency_ms as f64 / self.total_requests as f64
        } else {
            0.0
        }
    }

    fn success_rate(&self) -> f64 {
        if self.total_requests > 0 {
            (self.successful_requests as f64 / self.total_requests as f64) * 100.0
        } else {
            0.0
        }
    }
}

async fn heavy_read_test(
    client: &Client,
    base_url: &str,
    stats: Arc<Mutex<Stats>>,
    duration_secs: u64,
) {
    let start = Instant::now();
    let mut rng = StdRng::from_entropy();

    while start.elapsed().as_secs() < duration_secs {
        let account_num = rng.gen_range(0..100000);
        let account_number = format!("ACC{:08}", account_num);
        
        let req_start = Instant::now();
        let result = client
            .get(format!("{}/api/v1/accounts/balance/{}", base_url, account_number))
            .send()
            .await;
        
        let latency = req_start.elapsed().as_millis() as u64;
        let success = result.is_ok() && result.unwrap().status().is_success();
        
        let mut stats = stats.lock().await;
        stats.record(success, latency);
    }
}

async fn heavy_write_test(
    client: &Client,
    base_url: &str,
    stats: Arc<Mutex<Stats>>,
    duration_secs: u64,
) {
    let start = Instant::now();
    let mut rng = StdRng::from_entropy();

    while start.elapsed().as_secs() < duration_secs {
        let from_account_num = rng.gen_range(0..100000);
        let to_account_num = rng.gen_range(0..100000);
        let from_account = format!("ACC{:08}", from_account_num);
        let to_account = format!("ACC{:08}", to_account_num);
        let amount = rng.gen_range(1.0..500.0);
        
        let payload = json!({
            "from_account_number": from_account,
            "to_account_number": to_account,
            "amount": amount,
            "description": "Load test transfer"
        });
        
        let req_start = Instant::now();
        let result = client
            .post(format!("{}/api/v1/transactions/transfer", base_url))
            .json(&payload)
            .send()
            .await;
        
        let latency = req_start.elapsed().as_millis() as u64;
        let success = result.is_ok() && result.unwrap().status().is_success();
        
        let mut stats = stats.lock().await;
        stats.record(success, latency);
    }
}

async fn mixed_load_test(
    client: &Client,
    base_url: &str,
    stats: Arc<Mutex<Stats>>,
    duration_secs: u64,
) {
    let start = Instant::now();
    let mut rng = StdRng::from_entropy();

    while start.elapsed().as_secs() < duration_secs {
        let operation = rng.gen_range(0..100);
        
        let (success, latency) = if operation < 60 {
            let account_num = rng.gen_range(0..100000);
            let account_number = format!("ACC{:08}", account_num);
            
            let req_start = Instant::now();
            let result = client
                .get(format!("{}/api/v1/accounts/balance/{}", base_url, account_number))
                .send()
                .await;
            
            let latency = req_start.elapsed().as_millis() as u64;
            let success = result.is_ok() && result.unwrap().status().is_success();
            (success, latency)
        } else {
            let from_account_num = rng.gen_range(0..100000);
            let to_account_num = rng.gen_range(0..100000);
            let from_account = format!("ACC{:08}", from_account_num);
            let to_account = format!("ACC{:08}", to_account_num);
            let amount = rng.gen_range(1.0..500.0);
            
            let payload = json!({
                "from_account_number": from_account,
                "to_account_number": to_account,
                "amount": amount,
                "description": "Load test transfer"
            });
            
            let req_start = Instant::now();
            let result = client
                .post(format!("{}/api/v1/transactions/transfer", base_url))
                .json(&payload)
                .send()
                .await;
            
            let latency = req_start.elapsed().as_millis() as u64;
            let success = result.is_ok() && result.unwrap().status().is_success();
            (success, latency)
        };
        
        let mut stats = stats.lock().await;
        stats.record(success, latency);
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    
    if args.len() < 5 {
        eprintln!("Usage: {} <base_url> <test_type> <concurrency> <duration_secs>", args[0]);
        eprintln!("  test_type: heavy-read | heavy-write | mixed");
        eprintln!("  Example: {} http://localhost:8080 mixed 50 60", args[0]);
        std::process::exit(1);
    }
    
    let base_url = &args[1];
    let test_type = &args[2];
    let concurrency: usize = args[3].parse()?;
    let duration_secs: u64 = args[4].parse()?;
    
    println!("=== Load Test Configuration ===");
    println!("Base URL: {}", base_url);
    println!("Test Type: {}", test_type);
    println!("Concurrency: {}", concurrency);
    println!("Duration: {} seconds", duration_secs);
    println!("================================\n");
    
    let client = Arc::new(Client::builder()
        .timeout(Duration::from_secs(30))
        .build()?);
    
    let stats = Arc::new(Mutex::new(Stats::new()));
    let start_time = Instant::now();
    
    let mut handles = vec![];
    
    for _ in 0..concurrency {
        let client = Arc::clone(&client);
        let base_url = base_url.clone();
        let stats = Arc::clone(&stats);
        let test_type = test_type.clone();
        
        let handle = tokio::spawn(async move {
            match test_type.as_str() {
                "heavy-read" => heavy_read_test(&client, &base_url, stats, duration_secs).await,
                "heavy-write" => heavy_write_test(&client, &base_url, stats, duration_secs).await,
                "mixed" => mixed_load_test(&client, &base_url, stats, duration_secs).await,
                _ => eprintln!("Unknown test type: {}", test_type),
            }
        });
        
        handles.push(handle);
    }
    
    let stats_clone = stats.clone();
    let monitor_handle = tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(5));
        loop {
            interval.tick().await;
            let stats = stats_clone.lock().await;
            println!(
                "[Progress] Requests: {}, Success: {}, Failed: {}, Avg Latency: {:.2}ms",
                stats.total_requests,
                stats.successful_requests,
                stats.failed_requests,
                stats.avg_latency_ms()
            );
        }
    });
    
    for handle in handles {
        handle.await?;
    }
    
    monitor_handle.abort();
    
    let elapsed = start_time.elapsed();
    let final_stats = stats.lock().await;
    
    println!("\n=== Load Test Results ===");
    println!("Total Duration: {:.2}s", elapsed.as_secs_f64());
    println!("Total Requests: {}", final_stats.total_requests);
    println!("Successful Requests: {}", final_stats.successful_requests);
    println!("Failed Requests: {}", final_stats.failed_requests);
    println!("Success Rate: {:.2}%", final_stats.success_rate());
    println!("---");
    println!("TPS (Transactions Per Second): {:.2}", final_stats.total_requests as f64 / elapsed.as_secs_f64());
    println!("QPS (Queries Per Second): {:.2}", final_stats.total_requests as f64 / elapsed.as_secs_f64());
    println!("---");
    println!("Min Latency: {}ms", final_stats.min_latency_ms);
    println!("Avg Latency: {:.2}ms", final_stats.avg_latency_ms());
    println!("Max Latency: {}ms", final_stats.max_latency_ms);
    println!("========================\n");
    
    Ok(())
}
