//! List all droplets in your DigitalOcean account
//!
//! Usage: cargo run --example list_droplets
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

    println!("Fetching droplets...");

    // List all droplets with pagination
    let mut page = 1;
    let mut total_droplets = 0;

    loop {
        let response = client.droplets_list()
            .page(Some(page))
            .per_page(Some(25))
            .await?;

        let droplets_page = response.into_inner();

        if droplets_page.droplets.is_empty() {
            break;
        }

        println!("\n--- Page {} ---", page);
        for droplet in &droplets_page.droplets {
            total_droplets += 1;
            println!(
                "🖥️  {} (ID: {})",
                droplet.name,
                droplet.id
            );
            println!("   Status: {}", droplet.status);
            println!("   Size: {}", droplet.size.slug);
            println!("   Region: {}", droplet.region.name);
            println!("   Image: {}", droplet.image.name);
            
            // Show IP addresses
            if !droplet.networks.v4.is_empty() {
                let public_ips: Vec<&str> = droplet.networks.v4
                    .iter()
                    .filter(|n| n.type_ == "public")
                    .map(|n| n.ip_address.as_str())
                    .collect();
                
                if !public_ips.is_empty() {
                    println!("   Public IPs: {}", public_ips.join(", "));
                }
            }

            println!("   Created: {}", droplet.created_at);
            println!();
        }

        // Check if there are more pages
        if droplets_page.links.pages.as_ref()
            .and_then(|p| p.next.as_ref())
            .is_none() {
            break;
        }
        
        page += 1;
    }

    println!("📊 Total droplets: {}", total_droplets);

    Ok(())
}