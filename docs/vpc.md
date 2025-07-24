# VPC (Virtual Private Cloud) Management

DigitalOcean VPCs provide private networking for your resources. This guide covers managing VPCs using the rsdo client.

## Overview

VPCs create isolated network environments where you can:
- Deploy droplets with private IP addresses
- Control network traffic with firewall rules
- Connect resources across different regions
- Enable secure communication between services

## Basic Usage

### Creating a Client

```rust
use rsdo::{Client, Error};
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION};

#[tokio::main]
async fn main() -> Result<(), Error<()>> {
    // Create HTTP client with authentication
    let mut headers = HeaderMap::new();
    headers.insert(
        AUTHORIZATION,
        HeaderValue::from_str("Bearer YOUR_DO_API_TOKEN")?,
    );
    
    let http_client = reqwest::Client::builder()
        .default_headers(headers)
        .build()?;
    
    let client = Client::new_with_client("https://api.digitalocean.com", http_client);
    
    Ok(())
}
```

## VPC Operations

### List All VPCs

```rust
use rsdo::types::{VpcsListResponse};

async fn list_vpcs(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.vpcs_list(None, None).await?;
    let vpcs = response.into_inner();
    
    println!("Found {} VPCs", vpcs.vpcs.len());
    for vpc in vpcs.vpcs {
        println!("VPC: {} ({})", vpc.name, vpc.id);
        println!("  Region: {}", vpc.region);
        println!("  IP Range: {}", vpc.ip_range);
        println!("  Created: {}", vpc.created_at);
    }
    
    Ok(())
}
```

### Create a VPC

```rust
use rsdo::types::{VpcsCreateBody, VpcsCreateResponse};

async fn create_vpc(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let vpc_spec = VpcsCreateBody {
        name: "my-app-vpc".to_string(),
        region: "nyc3".to_string(),
        ip_range: Some("10.10.0.0/24".to_string()),
        description: Some("VPC for my application".to_string()),
    };
    
    let response = client.vpcs_create(&vpc_spec).await?;
    let vpc = response.into_inner().vpc;
    
    println!("Created VPC: {} ({})", vpc.name, vpc.id);
    println!("IP Range: {}", vpc.ip_range);
    println!("Status: {:?}", vpc.default);
    
    Ok(())
}
```

### Get VPC Details

```rust
async fn get_vpc_details(client: &Client, vpc_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.vpcs_get(vpc_id).await?;
    let vpc = response.into_inner().vpc;
    
    println!("VPC Details:");
    println!("  Name: {}", vpc.name);
    println!("  ID: {}", vpc.id);
    println!("  Region: {}", vpc.region);
    println!("  IP Range: {}", vpc.ip_range);
    println!("  URN: {}", vpc.urn);
    
    if let Some(description) = vpc.description {
        println!("  Description: {}", description);
    }
    
    Ok(())
}
```

### Update VPC

```rust
use rsdo::types::VpcsUpdateBody;

async fn update_vpc(client: &Client, vpc_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let update_spec = VpcsUpdateBody {
        name: Some("updated-vpc-name".to_string()),
        description: Some("Updated VPC description".to_string()),
        default: None,
    };
    
    let response = client.vpcs_update(vpc_id, &update_spec).await?;
    let vpc = response.into_inner().vpc;
    
    println!("Updated VPC: {}", vpc.name);
    
    Ok(())
}
```

### Delete VPC

```rust
async fn delete_vpc(client: &Client, vpc_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    client.vpcs_delete(vpc_id).await?;
    println!("VPC {} deleted successfully", vpc_id);
    
    Ok(())
}
```

### List VPC Members

```rust
async fn list_vpc_members(client: &Client, vpc_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.vpcs_list_members(
        vpc_id,
        None, // resource_type filter
        None, // per_page
        None, // page
    ).await?;
    
    let members = response.into_inner();
    
    println!("VPC Members:");
    for member in members.members {
        println!("  Resource: {} ({})", member.name, member.urn);
        println!("    Type: {:?}", member.resource_type);
        if let Some(created_at) = member.created_at {
            println!("    Created: {}", created_at);
        }
    }
    
    Ok(())
}
```

## Complete Example

```rust
use rsdo::{Client, Error};
use rsdo::types::*;
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Setup client
    let mut headers = HeaderMap::new();
    headers.insert(
        AUTHORIZATION,
        HeaderValue::from_str(&format!("Bearer {}", 
            std::env::var("DIGITALOCEAN_TOKEN")?))?,
    );
    
    let http_client = reqwest::Client::builder()
        .default_headers(headers)
        .build()?;
    
    let client = Client::new_with_client("https://api.digitalocean.com", http_client);
    
    // Create a new VPC
    let vpc_spec = VpcsCreateBody {
        name: "example-vpc".to_string(),
        region: "nyc3".to_string(),
        ip_range: Some("10.10.0.0/24".to_string()),
        description: Some("Example VPC for testing".to_string()),
    };
    
    let response = client.vpcs_create(&vpc_spec).await?;
    let vpc = response.into_inner().vpc;
    let vpc_id = vpc.id.clone();
    
    println!("✅ Created VPC: {} ({})", vpc.name, vpc.id);
    
    // Get VPC details
    let response = client.vpcs_get(&vpc_id).await?;
    let vpc = response.into_inner().vpc;
    println!("📋 VPC IP Range: {}", vpc.ip_range);
    
    // List all VPCs
    let response = client.vpcs_list(None, None).await?;
    let vpcs = response.into_inner();
    println!("📝 Total VPCs: {}", vpcs.vpcs.len());
    
    // Update VPC description
    let update_spec = VpcsUpdateBody {
        name: None,
        description: Some("Updated description via rsdo".to_string()),
        default: None,
    };
    
    client.vpcs_update(&vpc_id, &update_spec).await?;
    println!("✏️  Updated VPC description");
    
    // List VPC members
    let response = client.vpcs_list_members(&vpc_id, None, None, None).await?;
    let members = response.into_inner();
    println!("👥 VPC has {} members", members.members.len());
    
    // Clean up - delete VPC
    client.vpcs_delete(&vpc_id).await?;
    println!("🗑️  Deleted VPC {}", vpc_id);
    
    Ok(())
}
```

## Error Handling

```rust
use rsdo::{Client, Error};

async fn handle_vpc_errors(client: &Client) {
    match client.vpcs_get("invalid-vpc-id").await {
        Ok(response) => {
            let vpc = response.into_inner().vpc;
            println!("Found VPC: {}", vpc.name);
        }
        Err(Error::ErrorResponse(resp)) => {
            println!("API Error: {}", resp.status());
            // Handle specific error codes
            match resp.status().as_u16() {
                404 => println!("VPC not found"),
                401 => println!("Authentication failed"),
                429 => println!("Rate limit exceeded"),
                _ => println!("Other API error"),
            }
        }
        Err(Error::InvalidRequest(msg)) => {
            println!("Invalid request: {}", msg);
        }
        Err(Error::CommunicationError(err)) => {
            println!("Network error: {}", err);
        }
        Err(err) => {
            println!("Unexpected error: {:?}", err);
        }
    }
}
```

## Best Practices

### 1. VPC Naming and Organization

```rust
// Use descriptive names with environment prefixes
let vpc_name = format!("{}-{}-vpc", env, app_name);

// Example: "production-webapp-vpc", "staging-api-vpc"
```

### 2. IP Range Planning

```rust
// Use non-overlapping IP ranges for different environments
let ip_ranges = vec![
    ("production", "10.0.0.0/16"),   // Large range for production
    ("staging", "10.1.0.0/16"),     // Separate range for staging  
    ("development", "10.2.0.0/16"), // Development environment
];
```

### 3. Resource Cleanup

```rust
async fn cleanup_vpc_resources(client: &Client, vpc_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    // List all members before deletion
    let response = client.vpcs_list_members(vpc_id, None, None, None).await?;
    let members = response.into_inner();
    
    if !members.members.is_empty() {
        println!("Warning: VPC has {} resources that must be removed first", members.members.len());
        for member in members.members {
            println!("  - {} ({})", member.name, member.resource_type.unwrap_or_default());
        }
        return Ok(());
    }
    
    // Safe to delete empty VPC
    client.vpcs_delete(vpc_id).await?;
    println!("VPC deleted successfully");
    
    Ok(())
}
```

## Integration with Other Services

### Using VPC with Droplets

When creating droplets, specify the VPC to deploy them into:

```rust
use rsdo::types::DropletsCreateBody;

let droplet_spec = DropletsCreateBody {
    name: "web-server".to_string(),
    region: "nyc3".to_string(),
    size: "s-1vcpu-1gb".to_string(),
    image: "ubuntu-20-04-x64".to_string(),
    vpc_uuid: Some(vpc_id.clone()), // Deploy into specific VPC
    private_networking: Some(true),
    // ... other fields
};
```

### VPC with Load Balancers

```rust
// Load balancers can be associated with VPCs for private networking
let lb_spec = LoadBalancersCreateBody {
    name: "app-lb".to_string(),
    algorithm: "round_robin".to_string(),
    vpc_uuid: Some(vpc_id.clone()),
    // ... other configuration
};
```

This covers the essential VPC operations and best practices for managing Virtual Private Clouds with the rsdo client.