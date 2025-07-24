//! List all droplets in your DigitalOcean account
//!
//! Usage: cargo run --example list_droplets
//! Requires: DIGITALOCEAN_TOKEN environment variable

use rsdo::{types::DropletsListResponseDropletsItemNetworksV4ItemType, Client};
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Get the API token from environment
    let token =
        env::var("DIGITALOCEAN_TOKEN").expect("Please set DIGITALOCEAN_TOKEN environment variable");

    // Create the client
    let client = Client::from_token(&token);

    println!("Fetching droplets...");

    // List all droplets with pagination
    let mut page = 1;
    let mut total_droplets = 0;

    loop {
        let response = client
            .droplets_list(
                None, // name filter
                Some(std::num::NonZeroU64::new(page).unwrap()),
                Some(std::num::NonZeroU64::new(25).unwrap()),
                None, // tag_name
                None, // type
            )
            .await?;

        let droplets_page = response.into_inner();

        if droplets_page.droplets.is_empty() {
            break;
        }

        println!("\n--- Page {} ---", page);
        for droplet in &droplets_page.droplets {
            total_droplets += 1;
            println!("🖥️  {} (ID: {})", droplet.name, droplet.id);
            println!("   Status: {}", droplet.status);
            println!("   Size: {}", droplet.size.slug);
            println!("   Region: {}", droplet.region.name);
            println!(
                "   Image: {}",
                droplet
                    .image
                    .name
                    .as_ref()
                    .unwrap_or(&"Unknown".to_string())
            );

            // Show IP addresses
            if !droplet.networks.v4.is_empty() {
                let public_ips: Vec<String> = droplet
                    .networks
                    .v4
                    .iter()
                    .filter(|n| {
                        matches!(
                            n.type_,
                            Some(DropletsListResponseDropletsItemNetworksV4ItemType::Public)
                        )
                    })
                    .filter_map(|n| n.ip_address.map(|ip| ip.to_string()))
                    .collect();

                if !public_ips.is_empty() {
                    println!("   Public IPs: {}", public_ips.join(", "));
                }
            }

            println!("   Created: {}", droplet.created_at);
            println!();
        }

        // Check if there are more pages
        let has_next = droplets_page
            .links
            .and_then(|l| l.pages)
            .and_then(|p| p.subtype_0.and_then(|s| s.next))
            .is_some();

        if !has_next {
            break;
        }

        page += 1;
    }

    println!("📊 Total droplets: {}", total_droplets);

    Ok(())
}
