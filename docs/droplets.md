# Droplet Management

DigitalOcean Droplets are Linux-based virtual machines that run on top of virtualized hardware. This guide covers comprehensive droplet management using the rsdo client.

## Overview

Droplets provide:
- Flexible compute resources (CPU, RAM, SSD)
- Multiple Linux distributions
- Private networking and VPC support
- Automated backups and snapshots
- Monitoring and alerting
- SSH key and password authentication

## Basic Setup

```rust
use rsdo::{Client, Error};
use rsdo::types::*;
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION};

async fn create_client() -> Result<Client, Box<dyn std::error::Error>> {
    let mut headers = HeaderMap::new();
    headers.insert(
        AUTHORIZATION,
        HeaderValue::from_str(&format!("Bearer {}", 
            std::env::var("DIGITALOCEAN_TOKEN")?))?,
    );
    
    let http_client = reqwest::Client::builder()
        .default_headers(headers)
        .build()?;
    
    Ok(Client::new_with_client("https://api.digitalocean.com", http_client))
}
```

## Droplet Operations

### List Available Options

```rust
async fn list_droplet_options(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    // List available sizes
    let response = client.sizes_list(None, None).await?;
    let sizes = response.into_inner().sizes;
    
    println!("Available Droplet Sizes:");
    for size in sizes.iter().take(10) {
        println!("  {} - {} vCPUs, {} GB RAM, {} GB SSD - ${}/month", 
            size.slug, 
            size.vcpus, 
            size.memory / 1024, 
            size.disk,
            size.price_monthly
        );
    }
    
    // List available images
    let response = client.images_list(
        Some(ImagesListType::Distribution), // Only OS images
        None, None, None
    ).await?;
    let images = response.into_inner().images;
    
    println!("\nAvailable OS Images:");
    for image in images.iter().take(10) {
        println!("  {} - {}", image.slug.unwrap_or_default(), image.name);
    }
    
    // List available regions
    let response = client.regions_list(None, None).await?;
    let regions = response.into_inner().regions;
    
    println!("\nAvailable Regions:");
    for region in regions.iter().filter(|r| r.available) {
        println!("  {} - {}", region.slug, region.name);
    }
    
    Ok(())
}
```

### Create a Droplet

```rust
async fn create_droplet(client: &Client) -> Result<String, Box<dyn std::error::Error>> {
    let droplet_spec = DropletsCreateBody {
        name: "web-server-1".to_string(),
        region: "nyc3".to_string(),
        size: "s-2vcpu-2gb".to_string(),
        image: "ubuntu-22-04-x64".to_string(),
        ssh_keys: Some(vec!["your-ssh-key-id".to_string()]),
        backups: Some(true),
        ipv6: Some(true),
        monitoring: Some(true),
        tags: Some(vec![
            "web".to_string(), 
            "production".to_string()
        ]),
        user_data: Some(r#"#!/bin/bash
apt-get update
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx
echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
"#.to_string()),
        private_networking: Some(true),
        vpc_uuid: None, // Use default VPC or specify VPC ID
        with_droplet_agent: Some(true),
    };
    
    let response = client.droplets_create(&droplet_spec).await?;
    let droplet = response.into_inner().droplet;
    
    println!("✅ Created droplet: {} ({})", droplet.name, droplet.id);
    println!("   Status: {:?}", droplet.status);
    println!("   Region: {}", droplet.region.slug);
    println!("   Size: {}", droplet.size.slug);
    
    Ok(droplet.id.to_string())
}
```

### Create Multiple Droplets

```rust
async fn create_multiple_droplets(client: &Client) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let droplets_spec = DropletsCreateBody {
        names: Some(vec![
            "web-server-1".to_string(),
            "web-server-2".to_string(),
            "web-server-3".to_string(),
        ]),
        region: "nyc3".to_string(),
        size: "s-2vcpu-2gb".to_string(),
        image: "ubuntu-22-04-x64".to_string(),
        ssh_keys: Some(vec!["your-ssh-key-id".to_string()]),
        backups: Some(false),
        monitoring: Some(true),
        tags: Some(vec!["web-cluster".to_string()]),
        // ... other common settings
    };
    
    let response = client.droplets_create(&droplets_spec).await?;
    let droplets = response.into_inner().droplets;
    
    let droplet_ids: Vec<String> = droplets.iter()
        .map(|d| d.id.to_string())
        .collect();
    
    println!("✅ Created {} droplets:", droplets.len());
    for droplet in droplets {
        println!("   {} ({})", droplet.name, droplet.id);
    }
    
    Ok(droplet_ids)
}
```

### Get Droplet Details

```rust
async fn get_droplet(client: &Client, droplet_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.droplets_get(droplet_id).await?;
    let droplet = response.into_inner().droplet;
    
    println!("Droplet Details:");
    println!("  Name: {}", droplet.name);
    println!("  ID: {}", droplet.id);
    println!("  Status: {:?}", droplet.status);
    println!("  Created: {}", droplet.created_at);
    
    println!("  Specs:");
    println!("    vCPUs: {}", droplet.vcpus);
    println!("    Memory: {} GB", droplet.memory / 1024);
    println!("    Disk: {} GB", droplet.disk);
    println!("    Size: {}", droplet.size.slug);
    
    println!("  Network:");
    for network in droplet.networks.v4 {
        println!("    IPv4: {} ({})", network.ip_address, network.type_);
    }
    for network in droplet.networks.v6 {
        println!("    IPv6: {} ({})", network.ip_address, network.type_);
    }
    
    println!("  Features:");
    println!("    Backups: {}", droplet.features.contains(&"backups".to_string()));
    println!("    Monitoring: {}", droplet.features.contains(&"monitoring".to_string()));
    println!("    IPv6: {}", droplet.features.contains(&"ipv6".to_string()));
    
    if let Some(vpc_uuid) = droplet.vpc_uuid {
        println!("    VPC: {}", vpc_uuid);
    }
    
    Ok(())
}
```

### List All Droplets

```rust
async fn list_droplets(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.droplets_list(
        None, // per_page
        None, // page  
        None, // tag_name filter
        None, // name filter
    ).await?;
    let droplets = response.into_inner().droplets;
    
    println!("Droplets ({}):", droplets.len());
    for droplet in droplets {
        println!("  {} - {} ({}) - {}", 
            droplet.name, 
            droplet.status, 
            droplet.size.slug,
            droplet.region.slug
        );
        
        // Show primary IP
        if let Some(network) = droplet.networks.v4.iter()
            .find(|n| n.type_ == "public") {
            println!("    IP: {}", network.ip_address);
        }
    }
    
    Ok(())
}
```

### Filter Droplets by Tag

```rust
async fn list_droplets_by_tag(client: &Client, tag: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.droplets_list(
        None, None, 
        Some(tag.to_string()), // Filter by tag
        None
    ).await?;
    let droplets = response.into_inner().droplets;
    
    println!("Droplets tagged '{}' ({}):", tag, droplets.len());
    for droplet in droplets {
        println!("  {} - {}", droplet.name, droplet.status);
    }
    
    Ok(())
}
```

## Droplet Actions

### Power Operations

```rust
async fn power_operations(client: &Client, droplet_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    // Reboot droplet
    let action_spec = DropletActionsPostBody {
        type_: "reboot".to_string(),
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(droplet_id, &action_spec).await?;
    let action = response.into_inner().action;
    println!("🔄 Reboot initiated (Action ID: {})", action.id);
    
    // Wait for action to complete
    wait_for_action(client, droplet_id, action.id).await?;
    
    // Power off
    let action_spec = DropletActionsPostBody {
        type_: "power_off".to_string(),
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(droplet_id, &action_spec).await?;
    println!("⏹️  Power off initiated");
    
    // Power on
    let action_spec = DropletActionsPostBody {
        type_: "power_on".to_string(),
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(droplet_id, &action_spec).await?;
    println!("▶️  Power on initiated");
    
    Ok(())
}

async fn wait_for_action(
    client: &Client, 
    droplet_id: &str, 
    action_id: i64
) -> Result<(), Box<dyn std::error::Error>> {
    use tokio::time::{sleep, Duration};
    
    loop {
        let response = client.droplet_actions_get(droplet_id, &action_id.to_string()).await?;
        let action = response.into_inner().action;
        
        match action.status.as_str() {
            "completed" => {
                println!("✅ Action completed");
                break;
            }
            "errored" => {
                println!("❌ Action failed");
                break;
            }
            _ => {
                println!("⏳ Action in progress...");
                sleep(Duration::from_secs(5)).await;
            }
        }
    }
    
    Ok(())
}
```

### Resize Droplet

```rust
async fn resize_droplet(client: &Client, droplet_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    // First power off the droplet for disk resize
    let power_off_spec = DropletActionsPostBody {
        type_: "power_off".to_string(),
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(droplet_id, &power_off_spec).await?;
    let action = response.into_inner().action;
    wait_for_action(client, droplet_id, action.id).await?;
    
    // Resize droplet
    let resize_spec = DropletActionsPostBody {
        type_: "resize".to_string(),
        size: Some("s-4vcpu-8gb".to_string()), // Upgrade to larger size
        disk: Some(true), // Include disk resize
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(droplet_id, &resize_spec).await?;
    let action = response.into_inner().action;
    println!("📈 Resize initiated (Action ID: {})", action.id);
    
    wait_for_action(client, droplet_id, action.id).await?;
    
    // Power back on
    let power_on_spec = DropletActionsPostBody {
        type_: "power_on".to_string(),
        ..Default::default()
    };
    
    client.droplet_actions_post(droplet_id, &power_on_spec).await?;
    println!("🚀 Droplet resized and powered on");
    
    Ok(())
}
```

### Create Snapshot

```rust
async fn create_snapshot(
    client: &Client, 
    droplet_id: &str, 
    snapshot_name: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let snapshot_spec = DropletActionsPostBody {
        type_: "snapshot".to_string(),
        name: Some(snapshot_name.to_string()),
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(droplet_id, &snapshot_spec).await?;
    let action = response.into_inner().action;
    
    println!("📸 Snapshot '{}' initiated (Action ID: {})", snapshot_name, action.id);
    wait_for_action(client, droplet_id, action.id).await?;
    
    Ok(())
}
```

### Restore from Snapshot

```rust
async fn restore_from_snapshot(
    client: &Client, 
    droplet_id: &str, 
    snapshot_id: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let restore_spec = DropletActionsPostBody {
        type_: "restore".to_string(),
        image: Some(snapshot_id.to_string()),
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(droplet_id, &restore_spec).await?;
    let action = response.into_inner().action;
    
    println!("🔄 Restore initiated (Action ID: {})", action.id);
    wait_for_action(client, droplet_id, action.id).await?;
    
    Ok(())
}
```

## Backup Management

### Enable/Disable Backups

```rust
async fn manage_backups(client: &Client, droplet_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    // Enable backups
    let enable_backups = DropletActionsPostBody {
        type_: "enable_backups".to_string(),
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(droplet_id, &enable_backups).await?;
    println!("💾 Backups enabled");
    
    // List existing backups
    let response = client.droplets_list_backups(droplet_id, None, None).await?;
    let backups = response.into_inner().backups;
    
    println!("Available backups ({}):", backups.len());
    for backup in backups {
        println!("  {} - {} ({})", 
            backup.name, 
            backup.id,
            backup.created_at
        );
    }
    
    Ok(())
}
```

### List Snapshots

```rust
async fn list_snapshots(client: &Client, droplet_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.droplets_list_snapshots(droplet_id, None, None).await?;
    let snapshots = response.into_inner().snapshots;
    
    println!("Droplet Snapshots ({}):", snapshots.len());
    for snapshot in snapshots {
        println!("  {} - {} ({} GB)", 
            snapshot.name, 
            snapshot.id,
            snapshot.size_gigabytes
        );
        println!("    Created: {}", snapshot.created_at);
    }
    
    Ok(())
}
```

## Networking

### Add Floating IP

```rust
async fn assign_floating_ip(client: &Client, droplet_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    // First create a floating IP
    let floating_ip_spec = FloatingIpsCreateBody {
        type_: "assign".to_string(),
        region: None,
        droplet: Some(droplet_id.parse()?),
    };
    
    let response = client.floating_ips_create(&floating_ip_spec).await?;
    let floating_ip = response.into_inner().floating_ip;
    
    println!("🌐 Assigned floating IP: {}", floating_ip.ip);
    
    Ok(())
}
```

### Configure Firewall

```rust
async fn configure_firewall(client: &Client, droplet_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let firewall_spec = FirewallsCreateBody {
        name: "web-server-fw".to_string(),
        inbound_rules: Some(vec![
            // SSH access
            FirewallInboundRule {
                protocol: "tcp".to_string(),
                ports: "22".to_string(),
                sources: FirewallRuleSources {
                    addresses: Some(vec!["0.0.0.0/0".to_string(), "::/0".to_string()]),
                    droplet_ids: None,
                    load_balancer_uids: None,
                    tags: None,
                },
            },
            // HTTP access
            FirewallInboundRule {
                protocol: "tcp".to_string(),
                ports: "80".to_string(),
                sources: FirewallRuleSources {
                    addresses: Some(vec!["0.0.0.0/0".to_string(), "::/0".to_string()]),
                    droplet_ids: None,
                    load_balancer_uids: None,
                    tags: None,
                },
            },
            // HTTPS access
            FirewallInboundRule {
                protocol: "tcp".to_string(),
                ports: "443".to_string(),
                sources: FirewallRuleSources {
                    addresses: Some(vec!["0.0.0.0/0".to_string(), "::/0".to_string()]),
                    droplet_ids: None,
                    load_balancer_uids: None,
                    tags: None,
                },
            },
        ]),
        outbound_rules: Some(vec![
            // Allow all outbound traffic
            FirewallOutboundRule {
                protocol: "tcp".to_string(),
                ports: "1-65535".to_string(),
                destinations: FirewallRuleDestinations {
                    addresses: Some(vec!["0.0.0.0/0".to_string(), "::/0".to_string()]),
                    droplet_ids: None,
                    load_balancer_uids: None,
                    tags: None,
                },
            },
        ]),
        droplet_ids: Some(vec![droplet_id.parse()?]),
        tags: None,
    };
    
    let response = client.firewalls_create(&firewall_spec).await?;
    let firewall = response.into_inner().firewall;
    
    println!("🛡️  Created firewall: {} ({})", firewall.name, firewall.id);
    
    Ok(())
}
```

## Monitoring and Metrics

### Get Droplet Metrics

```rust
async fn get_droplet_metrics(client: &Client, droplet_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    use chrono::{Duration, Utc};
    
    let end_time = Utc::now();
    let start_time = end_time - Duration::hours(1);
    
    // Get CPU metrics
    let response = client.monitoring_get_droplet_cpu_metrics(
        droplet_id,
        &start_time.to_rfc3339(),
        &end_time.to_rfc3339(),
    ).await?;
    let cpu_metrics = response.into_inner();
    
    println!("CPU Metrics (last hour):");
    if let Some(data) = cpu_metrics.data {
        for point in data.result.iter().take(5) {
            println!("  Time: {} - Value: {}", 
                point.timestamp, 
                point.value
            );
        }
    }
    
    // Get memory metrics
    let response = client.monitoring_get_droplet_memory_metrics(
        droplet_id,
        &start_time.to_rfc3339(),
        &end_time.to_rfc3339(),
    ).await?;
    let memory_metrics = response.into_inner();
    
    println!("Memory Metrics (last hour):");
    if let Some(data) = memory_metrics.data {
        for point in data.result.iter().take(5) {
            println!("  Time: {} - Value: {} MB", 
                point.timestamp, 
                point.value / 1024.0 / 1024.0
            );
        }
    }
    
    Ok(())
}
```

## Complete Example: Web Server Deployment

```rust
use rsdo::{Client, Error};
use rsdo::types::*;
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION};
use tokio::time::{sleep, Duration};

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
    
    println!("🚀 Deploying web server infrastructure...");
    
    // 1. Create droplet with nginx setup
    let user_data = r#"#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install nginx and certbot
apt-get install -y nginx certbot python3-certbot-nginx

# Configure nginx
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create custom index page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to RSDO Web Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; text-align: center; }
        .status { color: #28a745; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 RSDO Web Server</h1>
        <p class="status">✅ Successfully deployed with DigitalOcean Rust Client</p>
        <p>Server deployed on: $(date)</p>
        <p>Hostname: $(hostname)</p>
    </div>
</body>
</html>
EOF

# Start and enable nginx
systemctl start nginx
systemctl enable nginx

# Configure firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "Web server setup completed!" > /var/log/deployment.log
"#;

    let droplet_spec = DropletsCreateBody {
        name: "rsdo-web-server".to_string(),
        region: "nyc3".to_string(),
        size: "s-2vcpu-2gb".to_string(),
        image: "ubuntu-22-04-x64".to_string(),
        ssh_keys: None, // Add your SSH key IDs here
        backups: Some(true),
        ipv6: Some(true),
        monitoring: Some(true),
        tags: Some(vec![
            "web".to_string(),
            "nginx".to_string(),
            "rsdo-example".to_string(),
        ]),
        user_data: Some(user_data.to_string()),
        private_networking: Some(true),
        with_droplet_agent: Some(true),
    };
    
    let response = client.droplets_create(&droplet_spec).await?;
    let droplet = response.into_inner().droplet;
    let droplet_id = droplet.id.to_string();
    
    println!("✅ Created droplet: {} ({})", droplet.name, droplet.id);
    
    // 2. Wait for droplet to be active
    println!("⏳ Waiting for droplet to be active...");
    loop {
        let response = client.droplets_get(&droplet_id).await?;
        let droplet = response.into_inner().droplet;
        
        match droplet.status {
            DropletStatus::Active => {
                println!("✅ Droplet is active!");
                
                // Get public IP
                if let Some(network) = droplet.networks.v4.iter()
                    .find(|n| n.type_ == "public") {
                    println!("🌐 Public IP: {}", network.ip_address);
                    println!("🔗 Access your server: http://{}", network.ip_address);
                }
                break;
            }
            DropletStatus::New => {
                println!("   Still initializing...");
                sleep(Duration::from_secs(10)).await;
            }
            status => {
                println!("   Status: {:?}", status);
                sleep(Duration::from_secs(5)).await;
            }
        }
    }
    
    // 3. Create and assign floating IP
    println!("🌐 Creating floating IP...");
    let floating_ip_spec = FloatingIpsCreateBody {
        type_: "assign".to_string(),
        region: None,
        droplet: Some(droplet_id.parse()?),
    };
    
    let response = client.floating_ips_create(&floating_ip_spec).await?;
    let floating_ip = response.into_inner().floating_ip;
    println!("✅ Floating IP assigned: {}", floating_ip.ip);
    println!("🔗 Static URL: http://{}", floating_ip.ip);
    
    // 4. Create firewall
    println!("🛡️  Setting up firewall...");
    let firewall_spec = FirewallsCreateBody {
        name: "rsdo-web-firewall".to_string(),
        inbound_rules: Some(vec![
            FirewallInboundRule {
                protocol: "tcp".to_string(),
                ports: "22".to_string(),
                sources: FirewallRuleSources {
                    addresses: Some(vec!["0.0.0.0/0".to_string()]),
                    droplet_ids: None,
                    load_balancer_uids: None,
                    tags: None,
                },
            },
            FirewallInboundRule {
                protocol: "tcp".to_string(),
                ports: "80".to_string(),
                sources: FirewallRuleSources {
                    addresses: Some(vec!["0.0.0.0/0".to_string()]),
                    droplet_ids: None,
                    load_balancer_uids: None,
                    tags: None,
                },
            },
            FirewallInboundRule {
                protocol: "tcp".to_string(),
                ports: "443".to_string(),
                sources: FirewallRuleSources {
                    addresses: Some(vec!["0.0.0.0/0".to_string()]),
                    droplet_ids: None,
                    load_balancer_uids: None,
                    tags: None,
                },
            },
        ]),
        outbound_rules: Some(vec![
            FirewallOutboundRule {
                protocol: "tcp".to_string(),
                ports: "1-65535".to_string(),
                destinations: FirewallRuleDestinations {
                    addresses: Some(vec!["0.0.0.0/0".to_string()]),
                    droplet_ids: None,
                    load_balancer_uids: None,
                    tags: None,
                },
            },
        ]),
        droplet_ids: Some(vec![droplet_id.parse()?]),
        tags: None,
    };
    
    let response = client.firewalls_create(&firewall_spec).await?;
    let firewall = response.into_inner().firewall;
    println!("✅ Firewall created: {}", firewall.name);
    
    // 5. Enable monitoring alerts (if supported)
    println!("📊 Setting up monitoring...");
    
    // 6. Create initial snapshot
    println!("📸 Creating initial snapshot...");
    let snapshot_spec = DropletActionsPostBody {
        type_: "snapshot".to_string(),
        name: Some("rsdo-web-server-initial".to_string()),
        ..Default::default()
    };
    
    let response = client.droplet_actions_post(&droplet_id, &snapshot_spec).await?;
    let action = response.into_inner().action;
    println!("✅ Snapshot initiated (Action ID: {})", action.id);
    
    println!("\n🎉 Web server deployment completed!");
    println!("   Droplet ID: {}", droplet_id);
    println!("   Floating IP: {}", floating_ip.ip);
    println!("   Firewall: {}", firewall.id);
    println!("\n📋 Next steps:");
    println!("   1. Wait a few minutes for user-data script to complete");
    println!("   2. Visit: http://{}", floating_ip.ip);
    println!("   3. Set up SSL with: ssh root@{} 'certbot --nginx'", floating_ip.ip);
    
    Ok(())
}
```

## Best Practices

### 1. Resource Management

```rust
// Use descriptive naming conventions
let droplet_name = format!("{}-{}-{}", 
    environment,      // "prod", "staging", "dev"
    application,      // "web", "api", "db"
    instance_number   // "001", "002"
);

// Tag resources consistently
let tags = vec![
    environment.to_string(),
    application.to_string(),
    team.to_string(),
    format!("cost-center-{}", cost_center),
];
```

### 2. Security

```rust
// Always use SSH keys, never passwords
let droplet_spec = DropletsCreateBody {
    // ... other fields
    ssh_keys: Some(vec![ssh_key_id.clone()]),
    // Never set: password: Some(...),
};

// Enable monitoring for security insights
monitoring: Some(true),
with_droplet_agent: Some(true),
```

### 3. High Availability

```rust
// Deploy across multiple regions
let regions = vec!["nyc3", "sfo3", "ams3"];
let mut droplet_ids = Vec::new();

for (i, region) in regions.iter().enumerate() {
    let droplet_spec = DropletsCreateBody {
        name: format!("web-server-{}", i + 1),
        region: region.to_string(),
        // ... other common settings
    };
    
    let response = client.droplets_create(&droplet_spec).await?;
    droplet_ids.push(response.into_inner().droplet.id);
}
```

### 4. Cost Optimization

```rust
// Start small and resize as needed
let droplet_spec = DropletsCreateBody {
    size: "s-1vcpu-1gb".to_string(), // Start with basic size
    // Enable backups only for production
    backups: Some(environment == "production"),
    // ...
};

// Use snapshots for dev/staging instead of always-on droplets
if environment != "production" {
    // Create snapshot and destroy droplet when not in use
}
```

This comprehensive guide covers all aspects of Droplet management with the rsdo client, from basic CRUD operations to complex deployment scenarios.