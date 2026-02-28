use reqwest::Client;
use serde_json::json;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use std::env;

// Helper function to format numbers with commas
fn format_number(n: u64) -> String {
    let s = n.to_string();
    let mut result = String::new();
    let mut count = 0;
    
    for c in s.chars().rev() {
        if count > 0 && count % 3 == 0 {
            result.push(',');
        }
        result.push(c);
        count += 1;
    }
    
    result.chars().rev().collect()
}

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

    while start.elapsed().as_secs() < duration_secs {
        let account_num = fastrand::u32(0..100000);
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

    while start.elapsed().as_secs() < duration_secs {
        let from_account_num = fastrand::u32(0..100000);
        let to_account_num = fastrand::u32(0..100000);
        let from_account = format!("ACC{:08}", from_account_num);
        let to_account = format!("ACC{:08}", to_account_num);
        let amount = fastrand::f64() * 499.0 + 1.0;
        
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

    while start.elapsed().as_secs() < duration_secs {
        let operation = fastrand::u32(0..100);
        
        let (success, latency) = if operation < 60 {
            let account_num = fastrand::u32(0..100000);
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
            let from_account_num = fastrand::u32(0..100000);
            let to_account_num = fastrand::u32(0..100000);
            let from_account = format!("ACC{:08}", from_account_num);
            let to_account = format!("ACC{:08}", to_account_num);
            let amount = fastrand::f64() * 499.0 + 1.0;
            
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
                format_number(stats.total_requests),
                format_number(stats.successful_requests),
                format_number(stats.failed_requests),
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
    println!("Total Requests: {}", format_number(final_stats.total_requests));
    println!("Successful Requests: {}", format_number(final_stats.successful_requests));
    println!("Failed Requests: {}", format_number(final_stats.failed_requests));
    println!("Success Rate: {:.2}%", final_stats.success_rate());
    println!("---");
    println!("TPS (Transactions Per Second): {:.2}", final_stats.total_requests as f64 / elapsed.as_secs_f64());
    println!("QPS (Queries Per Second): {:.2}", final_stats.total_requests as f64 / elapsed.as_secs_f64());
    println!("---");
    println!("Min Latency: {}ms", format_number(final_stats.min_latency_ms));
    println!("Avg Latency: {:.2}ms", final_stats.avg_latency_ms());
    println!("Max Latency: {}ms", format_number(final_stats.max_latency_ms));
    println!("========================\n");
    
    // Generate CSV report
    generate_csv_report(
        test_type,
        concurrency,
        duration_secs,
        &final_stats,
        elapsed.as_secs_f64(),
    )?;
    
    Ok(())
}

fn generate_csv_report(
    test_type: &str,
    concurrency: usize,
    duration_secs: u64,
    stats: &Stats,
    elapsed_secs: f64,
) -> Result<(), Box<dyn std::error::Error>> {
    use std::fs::OpenOptions;
    use std::io::Write;
    
    let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S").to_string();
    let filename = format!("/tmp/loadtest_{}_{}.csv", test_type, timestamp);
    
    let mut file = OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(&filename)?;
    
    // Write professional CSV report
    writeln!(file, "PostgreSQL Performance Test Report")?;
    writeln!(file, "Generated,{}", chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"))?;
    writeln!(file, "")?;
    
    // Test Configuration
    writeln!(file, "Test Configuration")?;
    writeln!(file, "Parameter,Value")?;
    writeln!(file, "Test Type,{}", test_type)?;
    writeln!(file, "Concurrency,{}", concurrency)?;
    writeln!(file, "Duration (seconds),{}", duration_secs)?;
    writeln!(file, "Actual Duration (seconds),{:.2}", elapsed_secs)?;
    writeln!(file, "")?;
    
    // Summary Statistics
    writeln!(file, "Summary Statistics")?;
    writeln!(file, "Metric,Value,Unit")?;
    writeln!(file, "Total Requests,{},requests", stats.total_requests)?;
    writeln!(file, "Successful Requests,{},requests", stats.successful_requests)?;
    writeln!(file, "Failed Requests,{},requests", stats.failed_requests)?;
    writeln!(file, "Success Rate,{:.2},%", stats.success_rate())?;
    writeln!(file, "TPS (Transactions Per Second),{:.2},tps", stats.total_requests as f64 / elapsed_secs)?;
    writeln!(file, "QPS (Queries Per Second),{:.2},qps", stats.total_requests as f64 / elapsed_secs)?;
    writeln!(file, "")?;
    
    // Latency Statistics
    writeln!(file, "Latency Statistics")?;
    writeln!(file, "Metric,Value (ms)")?;
    writeln!(file, "Minimum Latency,{}", stats.min_latency_ms)?;
    writeln!(file, "Average Latency,{:.2}", stats.avg_latency_ms())?;
    writeln!(file, "Maximum Latency,{}", stats.max_latency_ms)?;
    writeln!(file, "")?;
    
    // Performance Indicators
    writeln!(file, "Performance Indicators")?;
    writeln!(file, "Indicator,Status,Threshold,Actual")?;
    
    let success_rate = stats.success_rate();
    let success_status = if success_rate >= 99.5 { "EXCELLENT" } else if success_rate >= 99.0 { "GOOD" } else if success_rate >= 95.0 { "ACCEPTABLE" } else { "POOR" };
    writeln!(file, "Success Rate,{},>=99.5%,{:.2}%", success_status, success_rate)?;
    
    let avg_latency = stats.avg_latency_ms();
    let latency_status = if avg_latency < 50.0 { "EXCELLENT" } else if avg_latency < 100.0 { "GOOD" } else if avg_latency < 200.0 { "ACCEPTABLE" } else { "POOR" };
    writeln!(file, "Average Latency,{},<50ms,{:.2}ms", latency_status, avg_latency)?;
    
    let max_latency = stats.max_latency_ms;
    let max_latency_status = if max_latency < 500 { "EXCELLENT" } else if max_latency < 1000 { "GOOD" } else if max_latency < 2000 { "ACCEPTABLE" } else { "POOR" };
    writeln!(file, "Maximum Latency,{},<500ms,{}ms", max_latency_status, max_latency)?;
    
    let tps = stats.total_requests as f64 / elapsed_secs;
    let tps_status = if tps >= 1000.0 { "EXCELLENT" } else if tps >= 500.0 { "GOOD" } else if tps >= 100.0 { "ACCEPTABLE" } else { "POOR" };
    writeln!(file, "Throughput (TPS),{},>=1000,{:.2}", tps_status, tps)?;
    
    writeln!(file, "")?;
    writeln!(file, "End of Report")?;
    
    println!("📊 CSV Report generated: {}", filename);
    println!("   Copy from container: kubectl cp corebank/<pod-name>:{} ./reports/", filename);
    
    Ok(())
}
