//! Create a new droplet
//!
//! Usage: cargo run --example create_droplet
//! Requires: DIGITALOCEAN_TOKEN environment variable

use rsdo::{Client, types::*};
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Get the API token from environment
    let token = env::var("DIGITALOCEAN_TOKEN")
        .expect("Please set DIGITALOCEAN_TOKEN environment variable");

    // Create the client
    let client = Client::from_token(&token);

    println!("Creating a new droplet...");

    // First, let's check available regions and sizes
    println!("📍 Checking available regions...");
    let regions = client.regions_list().await?;
    let available_regions: Vec<_> = regions.into_inner().regions
        .into_iter()
        .filter(|r| r.available)
        .map(|r| format!("{} ({})", r.name, r.slug))
        .take(5)
        .collect();
    
    println!("Available regions: {}", available_regions.join(", "));

    println!("\n💾 Checking available sizes...");
    let sizes = client.sizes_list().await?;
    let small_sizes: Vec<_> = sizes.into_inner().sizes
        .into_iter()
        .filter(|s| s.memory <= 2048) // Only show smaller sizes
        .map(|s| format!("{} ({}MB RAM, ${})", s.slug, s.memory, s.price_monthly))
        .take(5)
        .collect();
    
    println!("Available sizes: {}", small_sizes.join(", "));

    // Create droplet configuration
    let droplet_name = format!("rsdo-example-{}", chrono::Utc::now().timestamp());
    
    let create_request = DropletCreate {
        name: droplet_name.clone(),
        region: "nyc1".to_string(),
        size: "s-1vcpu-1gb".to_string(),
        image: DropletCreateImage::Slug("ubuntu-22-04-x64".to_string()),
        ssh_keys: None,
        backups: Some(false),
        ipv6: Some(true),
        monitoring: Some(true),
        tags: Some(vec![
            "rsdo".to_string(),
            "example".to_string(),
            "rust".to_string(),
        ]),
        user_data: Some(
            r#"#!/bin/bash
echo "Hello from rsdo!" > /tmp/rsdo-hello.txt
apt-get update
apt-get install -y curl
"#.to_string(),
        ),
        volumes: None,
        vpc_uuid: None,
        with_droplet_agent: Some(true),
    };

    println!("\n🚀 Creating droplet '{}'...", droplet_name);
    println!("   Region: nyc1");
    println!("   Size: s-1vcpu-1gb");
    println!("   Image: ubuntu-22-04-x64");

    let response = client.droplets_create(&create_request).await?;
    let new_droplet = response.into_inner();

    println!("\n✅ Droplet created successfully!");
    println!("   ID: {}", new_droplet.droplet.id);
    println!("   Name: {}", new_droplet.droplet.name);
    println!("   Status: {}", new_droplet.droplet.status);
    println!("   Created: {}", new_droplet.droplet.created_at);

    // If there are associated actions, show them
    if !new_droplet.actions.is_empty() {
        println!("\n⚡ Associated actions:");
        for action in &new_droplet.actions {
            println!("   - {} ({}): {}", 
                action.type_, 
                action.id,
                action.status
            );
        }
    }

    println!("\n💡 The droplet is being created. You can check its status with:");
    println!("   cargo run --example get_droplet {}", new_droplet.droplet.id);

    println!("\n⚠️  Remember to delete this droplet when you're done to avoid charges:");
    println!("   cargo run --example delete_droplet {}", new_droplet.droplet.id);

    Ok(())
}