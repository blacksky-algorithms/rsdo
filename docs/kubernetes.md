# Kubernetes Cluster Management

DigitalOcean Kubernetes (DOKS) provides managed Kubernetes clusters. This guide covers managing clusters, node pools, and related resources using the rsdo client.

## Overview

DigitalOcean Kubernetes service provides:
- Fully managed Kubernetes control plane
- Automatic updates and security patches
- Integrated monitoring and logging
- Built-in load balancing and storage
- VPC networking support

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

## Cluster Operations

### List Available Kubernetes Options

```rust
async fn list_kubernetes_options(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.kubernetes_list_options().await?;
    let options = response.into_inner().options;
    
    println!("Available Kubernetes versions:");
    for version in options.versions {
        println!("  {} - {}", version.slug, version.kubernetes_version);
    }
    
    println!("\nAvailable regions:");
    for region in options.regions {
        println!("  {} - {}", region.slug, region.name);
    }
    
    println!("\nAvailable node sizes:");
    for size in options.sizes {
        println!("  {} - {} vCPUs, {} GB RAM", size.slug, size.vcpus, size.memory);
    }
    
    Ok(())
}
```

### Create a Kubernetes Cluster

```rust
async fn create_cluster(client: &Client) -> Result<String, Box<dyn std::error::Error>> {
    let cluster_spec = KubernetesCreateClusterBody {
        name: "my-k8s-cluster".to_string(),
        region: "nyc3".to_string(),
        version: "1.28.2-do.0".to_string(),
        auto_upgrade: Some(true),
        surge_upgrade: Some(true),
        ha: Some(false), // High availability control plane
        vpc_uuid: None, // Use default VPC or specify VPC ID
        tags: Some(vec!["production".to_string(), "web-app".to_string()]),
        node_pools: vec![
            KubernetesNodePool {
                name: "worker-pool".to_string(),
                size: "s-2vcpu-2gb".to_string(),
                count: 3,
                auto_scale: Some(true),
                min_nodes: Some(1),
                max_nodes: Some(5),
                tags: Some(vec!["worker".to_string()]),
                labels: Some(std::collections::HashMap::from([
                    ("node-type".to_string(), "worker".to_string()),
                    ("environment".to_string(), "production".to_string()),
                ])),
                taints: None,
            }
        ],
        maintenance_policy: Some(KubernetesMaintenancePolicy {
            start_time: "04:00".to_string(),
            day: KubernetesMaintenancePolicyDay::Sunday,
        }),
    };
    
    let response = client.kubernetes_create_cluster(&cluster_spec).await?;
    let cluster = response.into_inner().kubernetes_cluster;
    
    println!("✅ Created cluster: {} ({})", cluster.name, cluster.id);
    println!("   Status: {:?}", cluster.status.state);
    println!("   Version: {}", cluster.version);
    println!("   Endpoint: {}", cluster.endpoint);
    
    Ok(cluster.id)
}
```

### Get Cluster Details

```rust
async fn get_cluster(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.kubernetes_get_cluster(cluster_id).await?;
    let cluster = response.into_inner().kubernetes_cluster;
    
    println!("Cluster Details:");
    println!("  Name: {}", cluster.name);
    println!("  ID: {}", cluster.id);
    println!("  Status: {:?}", cluster.status.state);
    println!("  Version: {}", cluster.version);
    println!("  Region: {}", cluster.region);
    println!("  Endpoint: {}", cluster.endpoint);
    println!("  IPv4: {}", cluster.ipv4);
    
    if let Some(vpc_uuid) = cluster.vpc_uuid {
        println!("  VPC: {}", vpc_uuid);
    }
    
    println!("  Node Pools:");
    for pool in cluster.node_pools {
        println!("    - {} ({} nodes, size: {})", pool.name, pool.count, pool.size);
        if let Some(auto_scale) = pool.auto_scale {
            if auto_scale {
                println!("      Auto-scale: {}-{} nodes", 
                    pool.min_nodes.unwrap_or(pool.count),
                    pool.max_nodes.unwrap_or(pool.count));
            }
        }
    }
    
    Ok(())
}
```

### List All Clusters

```rust
async fn list_clusters(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.kubernetes_list_clusters(None, None).await?;
    let clusters = response.into_inner().kubernetes_clusters;
    
    println!("Kubernetes Clusters ({}):", clusters.len());
    for cluster in clusters {
        println!("  {} - {} ({})", 
            cluster.name, 
            cluster.status.state, 
            cluster.region
        );
        println!("    Version: {} | Nodes: {}", 
            cluster.version,
            cluster.node_pools.iter().map(|p| p.count).sum::<i32>()
        );
    }
    
    Ok(())
}
```

### Update Cluster

```rust
async fn update_cluster(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let update_spec = KubernetesUpdateClusterBody {
        name: Some("updated-cluster-name".to_string()),
        tags: Some(vec!["production".to_string(), "updated".to_string()]),
        auto_upgrade: Some(true),
        surge_upgrade: Some(false),
        ha: None, // Cannot change HA after creation
        maintenance_policy: Some(KubernetesMaintenancePolicy {
            start_time: "02:00".to_string(),
            day: KubernetesMaintenancePolicyDay::Monday,
        }),
    };
    
    let response = client.kubernetes_update_cluster(cluster_id, &update_spec).await?;
    let cluster = response.into_inner().kubernetes_cluster;
    
    println!("✅ Updated cluster: {}", cluster.name);
    
    Ok(())
}
```

### Delete Cluster

```rust
async fn delete_cluster(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    // Get cluster details before deletion
    let response = client.kubernetes_get_cluster(cluster_id).await?;
    let cluster = response.into_inner().kubernetes_cluster;
    
    println!("⚠️  Deleting cluster: {} with {} node pools", 
        cluster.name, 
        cluster.node_pools.len()
    );
    
    // Delete the cluster
    client.kubernetes_delete_cluster(cluster_id).await?;
    println!("🗑️  Cluster deletion initiated");
    
    Ok(())
}
```

## Node Pool Management

### Add Node Pool

```rust
async fn add_node_pool(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let node_pool_spec = KubernetesAddNodePoolBody {
        name: "high-memory-pool".to_string(),
        size: "s-4vcpu-8gb".to_string(),
        count: 2,
        auto_scale: Some(true),
        min_nodes: Some(1),
        max_nodes: Some(4),
        tags: Some(vec!["high-memory".to_string()]),
        labels: Some(std::collections::HashMap::from([
            ("pool-type".to_string(), "high-memory".to_string()),
            ("workload".to_string(), "database".to_string()),
        ])),
        taints: Some(vec![
            KubernetesNodePoolTaint {
                key: "workload".to_string(),
                value: Some("database".to_string()),
                effect: KubernetesNodePoolTaintEffect::NoSchedule,
            }
        ]),
    };
    
    let response = client.kubernetes_add_node_pool(cluster_id, &node_pool_spec).await?;
    let node_pool = response.into_inner().node_pool;
    
    println!("✅ Added node pool: {} ({} nodes)", node_pool.name, node_pool.count);
    
    Ok(())
}
```

### Update Node Pool

```rust
async fn update_node_pool(
    client: &Client, 
    cluster_id: &str, 
    node_pool_id: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let update_spec = KubernetesUpdateNodePoolBody {
        name: Some("updated-pool-name".to_string()),
        count: Some(4), // Scale to 4 nodes
        auto_scale: Some(true),
        min_nodes: Some(2),
        max_nodes: Some(6),
        tags: Some(vec!["updated-pool".to_string()]),
        labels: Some(std::collections::HashMap::from([
            ("updated".to_string(), "true".to_string()),
        ])),
    };
    
    let response = client.kubernetes_update_node_pool(
        cluster_id, 
        node_pool_id, 
        &update_spec
    ).await?;
    let node_pool = response.into_inner().node_pool;
    
    println!("✅ Updated node pool: {} to {} nodes", node_pool.name, node_pool.count);
    
    Ok(())
}
```

### Delete Node Pool

```rust
async fn delete_node_pool(
    client: &Client, 
    cluster_id: &str, 
    node_pool_id: &str
) -> Result<(), Box<dyn std::error::Error>> {
    client.kubernetes_delete_node_pool(cluster_id, node_pool_id).await?;
    println!("🗑️  Node pool deleted");
    
    Ok(())
}
```

## Cluster Configuration

### Get Kubeconfig

```rust
async fn get_kubeconfig(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.kubernetes_get_kubeconfig(cluster_id).await?;
    let kubeconfig = response.into_inner();
    
    // Save kubeconfig to file
    use std::fs;
    fs::write("kubeconfig.yaml", kubeconfig)?;
    println!("📄 Kubeconfig saved to kubeconfig.yaml");
    
    Ok(())
}
```

### Get Cluster Credentials

```rust
async fn get_credentials(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.kubernetes_get_credentials(cluster_id, None).await?;
    let creds = response.into_inner();
    
    println!("Cluster Credentials:");
    println!("  Server: {}", creds.server);
    println!("  Certificate Authority Data: [REDACTED]");
    println!("  Client Certificate Data: [REDACTED]");
    println!("  Client Key Data: [REDACTED]");
    println!("  Token: [REDACTED]");
    println!("  Expires At: {:?}", creds.expires_at);
    
    Ok(())
}
```

## Monitoring and Maintenance

### List Available Upgrades

```rust
async fn list_available_upgrades(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.kubernetes_get_available_upgrades(cluster_id).await?;
    let upgrades = response.into_inner().available_upgrade_versions;
    
    println!("Available upgrades:");
    for upgrade in upgrades {
        println!("  {} - {}", upgrade.slug, upgrade.kubernetes_version);
    }
    
    Ok(())
}
```

### Upgrade Cluster

```rust
async fn upgrade_cluster(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let upgrade_spec = KubernetesUpgradeClusterBody {
        version: "1.28.3-do.0".to_string(),
    };
    
    client.kubernetes_upgrade_cluster(cluster_id, &upgrade_spec).await?;
    println!("🔄 Cluster upgrade initiated");
    
    Ok(())
}
```

### Run Clusterlint

```rust
async fn run_clusterlint(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let lint_spec = KubernetesRunClusterlintBody {
        include_checks: Some(vec![
            "unused-config-map".to_string(),
            "privileged-containers".to_string(),
        ]),
        exclude_checks: Some(vec![
            "default-namespace".to_string(),
        ]),
    };
    
    let response = client.kubernetes_run_clusterlint(cluster_id, &lint_spec).await?;
    let lint_results = response.into_inner();
    
    println!("Clusterlint Results:");
    println!("  Run ID: {}", lint_results.run_id);
    println!("  Requested At: {}", lint_results.requested_at);
    
    Ok(())
}
```

## Complete Example: Full Cluster Lifecycle

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
    
    // 1. Check available options
    println!("🔍 Checking available Kubernetes options...");
    let response = client.kubernetes_list_options().await?;
    let options = response.into_inner().options;
    let latest_version = options.versions.first().unwrap();
    println!("   Latest K8s version: {}", latest_version.kubernetes_version);
    
    // 2. Create cluster
    println!("🚀 Creating Kubernetes cluster...");
    let cluster_spec = KubernetesCreateClusterBody {
        name: "example-cluster".to_string(),
        region: "nyc3".to_string(),
        version: latest_version.slug.clone(),
        auto_upgrade: Some(true),
        surge_upgrade: Some(true),
        ha: Some(false),
        vpc_uuid: None,
        tags: Some(vec!["example".to_string()]),
        node_pools: vec![
            KubernetesNodePool {
                name: "worker-pool".to_string(),
                size: "s-2vcpu-2gb".to_string(),
                count: 2,
                auto_scale: Some(true),
                min_nodes: Some(1),
                max_nodes: Some(3),
                tags: Some(vec!["worker".to_string()]),
                labels: Some(std::collections::HashMap::from([
                    ("node-type".to_string(), "worker".to_string()),
                ])),
                taints: None,
            }
        ],
        maintenance_policy: Some(KubernetesMaintenancePolicy {
            start_time: "04:00".to_string(),
            day: KubernetesMaintenancePolicyDay::Sunday,
        }),
    };
    
    let response = client.kubernetes_create_cluster(&cluster_spec).await?;
    let cluster = response.into_inner().kubernetes_cluster;
    let cluster_id = cluster.id.clone();
    
    println!("✅ Created cluster: {} ({})", cluster.name, cluster.id);
    
    // 3. Wait for cluster to be ready
    println!("⏳ Waiting for cluster to be ready...");
    loop {
        let response = client.kubernetes_get_cluster(&cluster_id).await?;
        let cluster = response.into_inner().kubernetes_cluster;
        
        match cluster.status.state {
            KubernetesClusterStatusState::Running => {
                println!("✅ Cluster is ready!");
                break;
            }
            KubernetesClusterStatusState::Provisioning => {
                println!("   Still provisioning...");
                sleep(Duration::from_secs(30)).await;
            }
            state => {
                println!("   Cluster state: {:?}", state);
                sleep(Duration::from_secs(10)).await;
            }
        }
    }
    
    // 4. Get kubeconfig
    println!("📄 Downloading kubeconfig...");
    let response = client.kubernetes_get_kubeconfig(&cluster_id).await?;
    let kubeconfig = response.into_inner();
    std::fs::write("example-cluster-kubeconfig.yaml", kubeconfig)?;
    println!("   Saved to example-cluster-kubeconfig.yaml");
    
    // 5. Add additional node pool
    println!("➕ Adding additional node pool...");
    let node_pool_spec = KubernetesAddNodePoolBody {
        name: "compute-pool".to_string(),
        size: "s-4vcpu-8gb".to_string(),
        count: 1,
        auto_scale: Some(false),
        min_nodes: None,
        max_nodes: None,
        tags: Some(vec!["compute".to_string()]),
        labels: Some(std::collections::HashMap::from([
            ("pool-type".to_string(), "compute".to_string()),
        ])),
        taints: None,
    };
    
    let response = client.kubernetes_add_node_pool(&cluster_id, &node_pool_spec).await?;
    let node_pool = response.into_inner().node_pool;
    println!("✅ Added node pool: {}", node_pool.name);
    
    // 6. List cluster resources
    println!("📋 Cluster summary:");
    let response = client.kubernetes_get_cluster(&cluster_id).await?;
    let cluster = response.into_inner().kubernetes_cluster;
    
    println!("   Name: {}", cluster.name);
    println!("   Version: {}", cluster.version);
    println!("   Endpoint: {}", cluster.endpoint);
    println!("   Node Pools: {}", cluster.node_pools.len());
    
    let total_nodes: i32 = cluster.node_pools.iter().map(|p| p.count).sum();
    println!("   Total Nodes: {}", total_nodes);
    
    // 7. Clean up (optional - uncomment to delete)
    // println!("🗑️  Cleaning up...");
    // client.kubernetes_delete_cluster(&cluster_id).await?;
    // println!("✅ Cluster deletion initiated");
    
    println!("🎉 Kubernetes cluster example completed!");
    println!("   Use: kubectl --kubeconfig=example-cluster-kubeconfig.yaml get nodes");
    
    Ok(())
}
```

## Best Practices

### 1. Cluster Sizing and Scaling

```rust
// Start with smaller nodes and use auto-scaling
let node_pool = KubernetesNodePool {
    name: "general-pool".to_string(),
    size: "s-2vcpu-2gb".to_string(), // Start small
    count: 2,                         // Minimum viable
    auto_scale: Some(true),
    min_nodes: Some(1),               // Allow scaling down
    max_nodes: Some(10),              // Set reasonable limit
    // ...
};
```

### 2. Resource Organization

```rust
// Use consistent labeling strategy
let labels = std::collections::HashMap::from([
    ("environment".to_string(), "production".to_string()),
    ("team".to_string(), "platform".to_string()),
    ("cost-center".to_string(), "engineering".to_string()),
    ("auto-scaling".to_string(), "enabled".to_string()),
]);
```

### 3. Security and Compliance

```rust
// Use taints for workload isolation
let security_taint = KubernetesNodePoolTaint {
    key: "workload".to_string(),
    value: Some("sensitive".to_string()),
    effect: KubernetesNodePoolTaintEffect::NoSchedule,
};

// Enable cluster security features
let secure_cluster = KubernetesCreateClusterBody {
    // ... other fields
    ha: Some(true),           // High availability
    auto_upgrade: Some(true), // Security updates
    surge_upgrade: Some(true), // Zero-downtime upgrades
    // ...
};
```

This covers comprehensive Kubernetes cluster management with the rsdo client, including best practices for production use.