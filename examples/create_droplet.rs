//! Create a new droplet
//!
//! Usage: cargo run --example create_droplet
//! Requires: DIGITALOCEAN_TOKEN environment variable

use rsdo::{types::*, Client};
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Get the API token from environment
    let token =
        env::var("DIGITALOCEAN_TOKEN").expect("Please set DIGITALOCEAN_TOKEN environment variable");

    // Create the client
    let client = Client::from_token(&token);

    println!("Creating a new droplet...");

    // First, let's check available regions and sizes
    println!("📍 Checking available regions...");
    let regions = client.regions_list(None, None).await?;
    let available_regions: Vec<_> = regions
        .into_inner()
        .regions
        .into_iter()
        .filter(|r| r.available)
        .map(|r| format!("{} ({})", r.name, r.slug))
        .take(5)
        .collect();

    println!("Available regions: {}", available_regions.join(", "));

    println!("\n💾 Checking available sizes...");
    let sizes = client.sizes_list(None, None).await?;
    let small_sizes: Vec<_> = sizes
        .into_inner()
        .sizes
        .into_iter()
        .filter(|s| s.memory <= 2048) // Only show smaller sizes
        .map(|s| format!("{} ({}MB RAM, ${})", s.slug, s.memory, s.price_monthly))
        .take(5)
        .collect();

    println!("Available sizes: {}", small_sizes.join(", "));

    // Create droplet configuration
    let droplet_name = format!(
        "rsdo-example-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs()
    );

    // Build the request by deserializing from JSON rather than with a struct
    // literal. `DropletsCreateBody` is generated from the upstream DigitalOcean
    // OpenAPI spec, and a struct literal has to name *every* field -- so each
    // time DigitalOcean adds an optional field to the create-droplet request,
    // a literal here stops compiling and breaks the release build. Every
    // generated field carries `#[serde(default)]`, so deserializing from JSON
    // only names the fields we actually care about and tolerates additive
    // upstream changes.
    let create_request: DropletsCreateBody = serde_json::from_value(serde_json::json!({
        "name": droplet_name.clone(),
        "region": "nyc1",
        "size": "s-1vcpu-1gb",
        "image": "ubuntu-22-04-x64",
        "ipv6": true,
        "monitoring": true,
        "tags": ["rsdo", "example", "rust"],
        "user_data": r#"#!/bin/bash
echo "Hello from rsdo!" > /tmp/rsdo-hello.txt
apt-get update
apt-get install -y curl
"#,
        "with_droplet_agent": true,
    }))?;

    println!("\n🚀 Creating droplet '{}'...", droplet_name);
    println!("   Region: nyc1");
    println!("   Size: s-1vcpu-1gb");
    println!("   Image: ubuntu-22-04-x64");

    let response = client.droplets_create(&create_request).await?;
    let new_droplet = response.into_inner();

    match new_droplet {
        DropletsCreateResponse::SingleDropletResponse { droplet, .. } => {
            println!("\n✅ Droplet created successfully!");
            println!("   ID: {}", droplet.id);
            println!("   Name: {}", droplet.name);
            println!("   Status: {}", droplet.status);
            println!("   Created: {}", droplet.created_at);

            println!("\n💡 The droplet is being created. You can check its status with:");
            println!("   cargo run --example get_droplet {}", droplet.id);

            println!("\n⚠️  Remember to delete this droplet when you're done to avoid charges:");
            println!("   cargo run --example delete_droplet {}", droplet.id);
        }
        DropletsCreateResponse::MultipleDropletResponse { droplets, .. } => {
            println!("\n✅ Multiple droplets created successfully!");
            for droplet in droplets {
                println!("   ID: {}, Name: {}", droplet.id, droplet.name);
            }
        }
    }

    Ok(())
}
