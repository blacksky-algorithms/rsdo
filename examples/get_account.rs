//! Get account information and current usage
//!
//! Usage: cargo run --example get_account
//! Requires: DIGITALOCEAN_TOKEN environment variable

use rsdo::Client;
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Get the API token from environment
    let token = env::var("DIGITALOCEAN_TOKEN")
        .expect("Please set DIGITALOCEAN_TOKEN environment variable");

    // Create the client
    let client = Client::from_token(&token);

    println!("Fetching account information...");

    // Get account details
    let account_response = client.account_get().await?;
    let account = account_response.into_inner().account.ok_or("No account found")?;

    println!("\n👤 Account Information:");
    println!("   Email: {}", account.email);
    println!("   UUID: {}", account.uuid);
    println!("   Status: {}", account.status);
    println!("   Status Message: {}", account.status_message);
    println!("   Email Verified: {}", account.email_verified);

    // Get current balance
    println!("\n💰 Account Balance:");
    match client.balance_get().await {
        Ok(balance_response) => {
            let balance = balance_response.into_inner();
            println!("   Current Balance: ${}", balance.account_balance.unwrap_or("N/A".to_string()));
            println!("   Month-to-Date Balance: ${}", balance.month_to_date_balance.unwrap_or("N/A".to_string()));
            println!("   Month-to-Date Usage: ${}", balance.month_to_date_usage.unwrap_or("N/A".to_string()));
        }
        Err(e) => {
            println!("   ❌ Could not fetch balance: {}", e);
        }
    }

    // Show resource limits and usage
    println!("\n📊 Resource Limits:");
    println!("   Droplet Limit: {}", account.droplet_limit);
    println!("   Floating IP Limit: {}", account.floating_ip_limit);
    // Note: Volume limit not available in account info

    // Get some usage statistics by counting resources
    println!("\n📈 Current Usage:");

    // Count droplets
    match client.droplets_list(None, None, None, None, None).await {
        Ok(droplets_response) => {
            let droplets = droplets_response.into_inner();
            println!("   Droplets: {}/{}", droplets.droplets.len(), account.droplet_limit);
        }
        Err(_) => println!("   Droplets: Unable to fetch"),
    }

    // Count floating IPs
    match client.floating_i_ps_list(None, None).await {
        Ok(floating_ips_response) => {
            let floating_ips = floating_ips_response.into_inner();
            println!("   Floating IPs: {}/{}", floating_ips.floating_ips.len(), account.floating_ip_limit);
        }
        Err(_) => println!("   Floating IPs: Unable to fetch"),
    }

    // Count volumes
    match client.volumes_list(None, None, None, None).await {
        Ok(volumes_response) => {
            let volumes = volumes_response.into_inner();
            println!("   Volumes: {}", volumes.volumes.len());
        }
        Err(_) => println!("   Volumes: Unable to fetch"),
    }

    // Count domains
    match client.domains_list(None, None).await {
        Ok(domains_response) => {
            let domains = domains_response.into_inner();
            println!("   Domains: {}", domains.domains.len());
        }
        Err(_) => println!("   Domains: Unable to fetch"),
    }

    // Count SSH keys
    match client.ssh_keys_list(None, None).await {
        Ok(keys_response) => {
            let keys = keys_response.into_inner();
            println!("   SSH Keys: {}", keys.ssh_keys.len());
        }
        Err(_) => println!("   SSH Keys: Unable to fetch"),
    }

    Ok(())
}