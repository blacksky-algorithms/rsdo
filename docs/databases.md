# Managed Databases

DigitalOcean Managed Databases provide fully-managed database services including PostgreSQL, MySQL, Redis (Valkey), and MongoDB. This guide covers database cluster management using the rsdo client.

## Overview

Managed Databases provide:
- Automated backups and point-in-time recovery
- High availability with standby nodes
- Automatic security updates and patches
- Connection pooling and monitoring
- Read replicas for scaling
- VPC networking support

Supported database engines:
- **PostgreSQL** - Relational database with advanced features
- **MySQL** - Popular relational database
- **Redis/Valkey** - In-memory data structure store
- **MongoDB** - Document-oriented NoSQL database
- **OpenSearch** - Search and analytics engine

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

## Database Operations

### List Available Database Options

```rust
async fn list_database_options(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.databases_list_options().await?;
    let options = response.into_inner().options;
    
    println!("Available Database Engines:");
    for engine in &options.engines {
        println!("  {} - Versions: {:?}", engine.name, engine.versions);
    }
    
    println!("\nAvailable Regions:");
    for region in &options.regions {
        println!("  {} - {}", region.slug, region.name);
    }
    
    println!("\nAvailable Sizes:");
    for size in &options.sizes {
        println!("  {} - {} vCPUs, {} GB RAM - ${}/month", 
            size.slug, 
            size.vcpus, 
            size.memory_mb / 1024,
            size.price_monthly
        );
    }
    
    Ok(())
}
```

### Create PostgreSQL Database

```rust
async fn create_postgres_cluster(client: &Client) -> Result<String, Box<dyn std::error::Error>> {
    let cluster_spec = DatabasesCreateClusterBody {
        name: "postgres-prod".to_string(),
        engine: "pg".to_string(),
        version: "15".to_string(),
        region: "nyc3".to_string(),
        size: "db-s-2vcpu-2gb".to_string(),
        num_nodes: 2, // Primary + standby for HA
        db_name: Some("myapp".to_string()),
        db_user: Some("myapp_user".to_string()),
        private_network_uuid: None, // Use default VPC or specify VPC ID
        tags: Some(vec![
            "production".to_string(),
            "postgres".to_string(),
            "backend".to_string(),
        ]),
        backup_restore: None,
        storage_size_mib: Some(61440), // 60 GB storage
        project_id: None,
    };
    
    let response = client.databases_create_cluster(&cluster_spec).await?;
    let cluster = response.into_inner().database;
    
    println!("✅ Created PostgreSQL cluster: {} ({})", cluster.name, cluster.id);
    println!("   Status: {:?}", cluster.status);
    println!("   Engine: {} v{}", cluster.engine, cluster.version);
    println!("   Region: {}", cluster.region);
    println!("   Nodes: {}", cluster.num_nodes);
    
    if let Some(connection) = &cluster.connection {
        println!("   Host: {}", connection.host);
        println!("   Port: {}", connection.port);
        println!("   Database: {}", connection.database);
        println!("   User: {}", connection.user);
    }
    
    Ok(cluster.id)
}
```

### Create Valkey (Redis) Database

```rust
async fn create_valkey_cluster(client: &Client) -> Result<String, Box<dyn std::error::Error>> {
    let cluster_spec = DatabasesCreateClusterBody {
        name: "valkey-cache".to_string(),
        engine: "redis".to_string(), // Use "redis" for Valkey/Redis
        version: "7".to_string(),
        region: "nyc3".to_string(),
        size: "db-s-1vcpu-2gb".to_string(),
        num_nodes: 1, // Redis/Valkey typically runs single node
        db_name: None, // Not applicable for Redis/Valkey
        db_user: None, // Uses default authentication
        private_network_uuid: None,
        tags: Some(vec![
            "cache".to_string(),
            "redis".to_string(),
            "valkey".to_string(),
        ]),
        backup_restore: None,
        storage_size_mib: None, // In-memory storage
        project_id: None,
    };
    
    let response = client.databases_create_cluster(&cluster_spec).await?;
    let cluster = response.into_inner().database;
    
    println!("✅ Created Valkey cluster: {} ({})", cluster.name, cluster.id);
    println!("   Status: {:?}", cluster.status);
    println!("   Engine: {} v{}", cluster.engine, cluster.version);
    println!("   Region: {}", cluster.region);
    
    if let Some(connection) = &cluster.connection {
        println!("   Host: {}", connection.host);
        println!("   Port: {}", connection.port);
        // Redis/Valkey uses password authentication
        if let Some(password) = &connection.password {
            println!("   Password: [REDACTED]");
        }
    }
    
    Ok(cluster.id)
}
```

### Get Database Cluster Details

```rust
async fn get_database_cluster(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.databases_get_cluster(cluster_id).await?;
    let cluster = response.into_inner().database;
    
    println!("Database Cluster Details:");
    println!("  Name: {}", cluster.name);
    println!("  ID: {}", cluster.id);
    println!("  Engine: {} v{}", cluster.engine, cluster.version);
    println!("  Status: {:?}", cluster.status);
    println!("  Region: {}", cluster.region);
    println!("  Size: {}", cluster.size);
    println!("  Nodes: {}", cluster.num_nodes);
    println!("  Created: {}", cluster.created_at);
    
    if let Some(connection) = &cluster.connection {
        println!("  Connection:");
        println!("    Host: {}", connection.host);
        println!("    Port: {}", connection.port);
        println!("    SSL: {}", connection.ssl);
        
        match cluster.engine.as_str() {
            "pg" | "mysql" => {
                println!("    Database: {}", connection.database);
                println!("    User: {}", connection.user);
            }
            "redis" => {
                println!("    Authentication: Password-based");
            }
            _ => {}
        }
    }
    
    if let Some(maintenance_window) = &cluster.maintenance_window {
        println!("  Maintenance Window:");
        println!("    Day: {:?}", maintenance_window.day);
        println!("    Hour: {}", maintenance_window.hour);
    }
    
    println!("  Tags: {:?}", cluster.tags);
    
    Ok(())
}
```

### List All Database Clusters

```rust
async fn list_database_clusters(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.databases_list_clusters(None, None).await?;
    let clusters = response.into_inner().databases;
    
    println!("Database Clusters ({}):", clusters.len());
    for cluster in clusters {
        println!("  {} - {} {} ({}) - {} nodes",
            cluster.name,
            cluster.engine,
            cluster.version,
            cluster.status,
            cluster.num_nodes
        );
        
        if let Some(connection) = &cluster.connection {
            println!("    Connection: {}:{}", connection.host, connection.port);
        }
    }
    
    Ok(())
}
```

### Update Database Cluster

```rust
async fn update_database_cluster(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    // Update cluster configuration
    let update_spec = DatabasesUpdateClusterBody {
        name: Some("postgres-prod-updated".to_string()),
        tags: Some(vec![
            "production".to_string(),
            "postgres".to_string(),
            "updated".to_string(),
        ]),
        maintenance_window: Some(DatabaseMaintenanceWindow {
            day: "monday".to_string(),
            hour: "02:00".to_string(),
            pending: None,
        }),
    };
    
    let response = client.databases_update_cluster(cluster_id, &update_spec).await?;
    let cluster = response.into_inner().database;
    
    println!("✅ Updated cluster: {}", cluster.name);
    
    Ok(())
}
```

### Resize Database Cluster

```rust
async fn resize_database_cluster(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let resize_spec = DatabasesUpdateClusterSizeBody {
        size: "db-s-4vcpu-8gb".to_string(), // Upgrade to larger size
        num_nodes: Some(3), // Add additional standby node
        storage_size_mib: Some(122880), // Increase to 120 GB
    };
    
    let response = client.databases_update_cluster_size(cluster_id, &resize_spec).await?;
    let cluster = response.into_inner().database;
    
    println!("📈 Cluster resize initiated");
    println!("   New size: {}", cluster.size);
    println!("   Nodes: {}", cluster.num_nodes);
    
    Ok(())
}
```

## Database Management

### Create Database User

```rust
async fn create_database_user(
    client: &Client, 
    cluster_id: &str, 
    username: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let user_spec = DatabasesCreateUserBody {
        name: username.to_string(),
        mysql_settings: None, // Only needed for MySQL
    };
    
    let response = client.databases_create_user(cluster_id, &user_spec).await?;
    let user = response.into_inner().user;
    
    println!("✅ Created database user: {}", user.name);
    if let Some(password) = user.password {
        println!("   Password: {} (save this securely!)", password);
    }
    
    Ok(())
}
```

### Create Database

```rust
async fn create_database(
    client: &Client, 
    cluster_id: &str, 
    db_name: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let db_spec = DatabasesCreateDbBody {
        name: db_name.to_string(),
    };
    
    let response = client.databases_create_db(cluster_id, &db_spec).await?;
    let database = response.into_inner().db;
    
    println!("✅ Created database: {}", database.name);
    
    Ok(())
}
```

### List Database Users and Databases

```rust
async fn list_database_resources(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    // List users
    let response = client.databases_list_users(cluster_id, None, None).await?;
    let users = response.into_inner().users;
    
    println!("Database Users ({}):", users.len());
    for user in users {
        println!("  {} - Role: {:?}", user.name, user.role);
    }
    
    // List databases
    let response = client.databases_list_dbs(cluster_id, None, None).await?;
    let databases = response.into_inner().dbs;
    
    println!("Databases ({}):", databases.len());
    for db in databases {
        println!("  {}", db.name);
    }
    
    Ok(())
}
```

## Backup and Recovery

### List Backups

```rust
async fn list_database_backups(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.databases_list_backups(cluster_id, None, None).await?;
    let backups = response.into_inner().backups;
    
    println!("Database Backups ({}):", backups.len());
    for backup in backups {
        println!("  {} - {} ({} GB)",
            backup.created_at,
            backup.backup_id,
            backup.size_gigabytes
        );
    }
    
    Ok(())
}
```

### Create Cluster from Backup

```rust
async fn restore_from_backup(
    client: &Client, 
    backup_id: &str
) -> Result<String, Box<dyn std::error::Error>> {
    let restore_spec = DatabasesCreateClusterBody {
        name: "postgres-restored".to_string(),
        engine: "pg".to_string(),
        version: "15".to_string(),
        region: "nyc3".to_string(),
        size: "db-s-2vcpu-2gb".to_string(),
        num_nodes: 1,
        db_name: None,
        db_user: None,
        private_network_uuid: None,
        tags: Some(vec!["restored".to_string()]),
        backup_restore: Some(DatabaseBackupRestore {
            database_name: "original-cluster-id".to_string(),
            backup_created_at: backup_id.to_string(),
        }),
        storage_size_mib: None,
        project_id: None,
    };
    
    let response = client.databases_create_cluster(&restore_spec).await?;
    let cluster = response.into_inner().database;
    
    println!("✅ Created cluster from backup: {} ({})", cluster.name, cluster.id);
    
    Ok(cluster.id)
}
```

## Read Replicas

### Create Read Replica

```rust
async fn create_read_replica(
    client: &Client, 
    cluster_id: &str
) -> Result<String, Box<dyn std::error::Error>> {
    let replica_spec = DatabasesCreateReplicaBody {
        name: "postgres-read-replica".to_string(),
        region: "sfo3".to_string(), // Different region for geographic distribution
        size: "db-s-1vcpu-2gb".to_string(), // Can be smaller than primary
        tags: Some(vec![
            "replica".to_string(),
            "read-only".to_string(),
        ]),
        private_network_uuid: None,
    };
    
    let response = client.databases_create_replica(cluster_id, &replica_spec).await?;
    let replica = response.into_inner().replica;
    
    println!("✅ Created read replica: {} ({})", replica.name, replica.id);
    println!("   Region: {}", replica.region);
    
    if let Some(connection) = &replica.connection {
        println!("   Read-only endpoint: {}:{}", connection.host, connection.port);
    }
    
    Ok(replica.id)
}
```

### List Read Replicas

```rust
async fn list_read_replicas(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.databases_list_replicas(cluster_id, None, None).await?;
    let replicas = response.into_inner().replicas;
    
    println!("Read Replicas ({}):", replicas.len());
    for replica in replicas {
        println!("  {} - {} ({}) - {}",
            replica.name,
            replica.size,
            replica.status,
            replica.region
        );
        
        if let Some(connection) = &replica.connection {
            println!("    Endpoint: {}:{}", connection.host, connection.port);
        }
    }
    
    Ok(())
}
```

## Connection Pooling

### Configure Connection Pool

```rust
async fn configure_connection_pool(
    client: &Client, 
    cluster_id: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let pool_spec = DatabasesCreateConnectionPoolBody {
        name: "api-pool".to_string(),
        mode: "transaction".to_string(), // "session" or "transaction"
        size: 20, // Pool size
        db: "myapp".to_string(),
        user: "myapp_user".to_string(),
    };
    
    let response = client.databases_create_connection_pool(cluster_id, &pool_spec).await?;
    let pool = response.into_inner().pool;
    
    println!("✅ Created connection pool: {}", pool.name);
    println!("   Mode: {}", pool.mode);
    println!("   Size: {}", pool.size);
    
    if let Some(connection) = &pool.connection {
        println!("   Pool endpoint: {}:{}", connection.host, connection.port);
    }
    
    Ok(())
}
```

## Firewall Rules

### Configure Database Firewall

```rust
async fn configure_database_firewall(
    client: &Client, 
    cluster_id: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let firewall_spec = DatabasesUpdateFirewallRulesBody {
        rules: vec![
            DatabaseFirewallRule {
                type_: "droplet".to_string(),
                value: "web-servers".to_string(), // Tag name
            },
            DatabaseFirewallRule {
                type_: "ip_addr".to_string(),
                value: "203.0.113.0/24".to_string(), // Office IP range
            },
            DatabaseFirewallRule {
                type_: "k8s".to_string(),
                value: "k8s-cluster-id".to_string(), // Kubernetes cluster
            },
        ],
    };
    
    let response = client.databases_update_firewall_rules(cluster_id, &firewall_spec).await?;
    let rules = response.into_inner().rules;
    
    println!("✅ Updated firewall rules ({} rules):", rules.len());
    for rule in rules {
        println!("   {} - {}", rule.type_, rule.value);
    }
    
    Ok(())
}
```

## Complete Example: Multi-tier Application

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
    
    println!("🚀 Setting up multi-tier application infrastructure...");
    
    // 1. Create PostgreSQL cluster for primary data
    println!("📊 Creating PostgreSQL cluster...");
    let postgres_spec = DatabasesCreateClusterBody {
        name: "webapp-postgres".to_string(),
        engine: "pg".to_string(),
        version: "15".to_string(),
        region: "nyc3".to_string(),
        size: "db-s-2vcpu-2gb".to_string(),
        num_nodes: 2, // HA setup
        db_name: Some("webapp".to_string()),
        db_user: Some("webapp_user".to_string()),
        private_network_uuid: None,
        tags: Some(vec![
            "production".to_string(),
            "postgres".to_string(),
            "primary-db".to_string(),
        ]),
        backup_restore: None,
        storage_size_mib: Some(61440), // 60 GB
        project_id: None,
    };
    
    let response = client.databases_create_cluster(&postgres_spec).await?;
    let postgres_cluster = response.into_inner().database;
    let postgres_id = postgres_cluster.id.clone();
    
    println!("✅ PostgreSQL cluster created: {} ({})", postgres_cluster.name, postgres_id);
    
    // 2. Create Valkey/Redis cluster for caching
    println!("⚡ Creating Valkey cache cluster...");
    let valkey_spec = DatabasesCreateClusterBody {
        name: "webapp-cache".to_string(),
        engine: "redis".to_string(),
        version: "7".to_string(),
        region: "nyc3".to_string(),
        size: "db-s-1vcpu-2gb".to_string(),
        num_nodes: 1,
        db_name: None,
        db_user: None,
        private_network_uuid: None,
        tags: Some(vec![
            "production".to_string(),
            "redis".to_string(),
            "cache".to_string(),
        ]),
        backup_restore: None,
        storage_size_mib: None,
        project_id: None,
    };
    
    let response = client.databases_create_cluster(&valkey_spec).await?;
    let valkey_cluster = response.into_inner().database;
    let valkey_id = valkey_cluster.id.clone();
    
    println!("✅ Valkey cluster created: {} ({})", valkey_cluster.name, valkey_id);
    
    // 3. Wait for clusters to be ready
    println!("⏳ Waiting for databases to be ready...");
    
    // Wait for PostgreSQL
    loop {
        let response = client.databases_get_cluster(&postgres_id).await?;
        let cluster = response.into_inner().database;
        
        match cluster.status {
            DatabaseStatus::Online => {
                println!("✅ PostgreSQL cluster is online");
                break;
            }
            DatabaseStatus::Creating => {
                println!("   PostgreSQL still creating...");
                sleep(Duration::from_secs(30)).await;
            }
            status => {
                println!("   PostgreSQL status: {:?}", status);
                sleep(Duration::from_secs(10)).await;
            }
        }
    }
    
    // Wait for Valkey
    loop {
        let response = client.databases_get_cluster(&valkey_id).await?;
        let cluster = response.into_inner().database;
        
        match cluster.status {
            DatabaseStatus::Online => {
                println!("✅ Valkey cluster is online");
                break;
            }
            DatabaseStatus::Creating => {
                println!("   Valkey still creating...");
                sleep(Duration::from_secs(30)).await;
            }
            status => {
                println!("   Valkey status: {:?}", status);
                sleep(Duration::from_secs(10)).await;
            }
        }
    }
    
    // 4. Create additional database and user for PostgreSQL
    println!("👤 Setting up PostgreSQL database structure...");
    
    // Create additional database
    let db_spec = DatabasesCreateDbBody {
        name: "analytics".to_string(),
    };
    client.databases_create_db(&postgres_id, &db_spec).await?;
    println!("   Created 'analytics' database");
    
    // Create read-only user
    let user_spec = DatabasesCreateUserBody {
        name: "readonly_user".to_string(),
        mysql_settings: None,
    };
    let response = client.databases_create_user(&postgres_id, &user_spec).await?;
    let user = response.into_inner().user;
    println!("   Created read-only user: {}", user.name);
    
    // 5. Create read replica in different region
    println!("📖 Creating read replica...");
    let replica_spec = DatabasesCreateReplicaBody {
        name: "webapp-postgres-replica".to_string(),
        region: "sfo3".to_string(),
        size: "db-s-1vcpu-2gb".to_string(),
        tags: Some(vec!["replica".to_string(), "west-coast".to_string()]),
        private_network_uuid: None,
    };
    
    let response = client.databases_create_replica(&postgres_id, &replica_spec).await?;
    let replica = response.into_inner().replica;
    println!("✅ Read replica created: {} in {}", replica.name, replica.region);
    
    // 6. Configure connection pooling for PostgreSQL
    println!("🏊 Setting up connection pooling...");
    let pool_spec = DatabasesCreateConnectionPoolBody {
        name: "webapp-pool".to_string(),
        mode: "transaction".to_string(),
        size: 25,
        db: "webapp".to_string(),
        user: "webapp_user".to_string(),
    };
    
    let response = client.databases_create_connection_pool(&postgres_id, &pool_spec).await?;
    let pool = response.into_inner().pool;
    println!("✅ Connection pool created: {} (size: {})", pool.name, pool.size);
    
    // 7. Configure firewall rules
    println!("🛡️  Setting up database firewall...");
    let firewall_spec = DatabasesUpdateFirewallRulesBody {
        rules: vec![
            DatabaseFirewallRule {
                type_: "tag".to_string(),
                value: "webapp-servers".to_string(),
            },
            DatabaseFirewallRule {
                type_: "ip_addr".to_string(),
                value: "10.0.0.0/8".to_string(), // Private network
            },
        ],
    };
    
    client.databases_update_firewall_rules(&postgres_id, &firewall_spec).await?;
    client.databases_update_firewall_rules(&valkey_id, &firewall_spec).await?;
    println!("✅ Firewall rules configured for both clusters");
    
    // 8. Display connection information
    println!("\n🎉 Multi-tier database setup completed!");
    
    // Get final cluster details
    let pg_response = client.databases_get_cluster(&postgres_id).await?;
    let pg_cluster = pg_response.into_inner().database;
    
    let valkey_response = client.databases_get_cluster(&valkey_id).await?;
    let valkey_cluster = valkey_response.into_inner().database;
    
    println!("\n📊 PostgreSQL Cluster:");
    if let Some(connection) = &pg_cluster.connection {
        println!("   Host: {}", connection.host);
        println!("   Port: {}", connection.port);
        println!("   Database: {}", connection.database);
        println!("   User: {}", connection.user);
        println!("   SSL: {}", connection.ssl);
    }
    
    // Get connection pool info
    let pool_response = client.databases_list_connection_pools(&postgres_id, None, None).await?;
    let pools = pool_response.into_inner().pools;
    if let Some(pool) = pools.first() {
        if let Some(connection) = &pool.connection {
            println!("   Pool Host: {}", connection.host);
            println!("   Pool Port: {}", connection.port);
        }
    }
    
    println!("\n⚡ Valkey/Redis Cluster:");
    if let Some(connection) = &valkey_cluster.connection {
        println!("   Host: {}", connection.host);
        println!("   Port: {}", connection.port);
        println!("   SSL: {}", connection.ssl);
    }
    
    println!("\n📖 Read Replica:");
    if let Some(connection) = &replica.connection {
        println!("   Host: {}", connection.host);
        println!("   Port: {}", connection.port);
        println!("   Region: {}", replica.region);
    }
    
    println!("\n📋 Next steps:");
    println!("   1. Configure your application to use these connection details");
    println!("   2. Set up monitoring and alerting");
    println!("   3. Configure automated backups as needed");
    println!("   4. Consider setting up additional read replicas for scaling");
    
    Ok(())
}
```

## Best Practices

### 1. High Availability

```rust
// Always use multiple nodes for production
let ha_cluster = DatabasesCreateClusterBody {
    num_nodes: 2, // Primary + standby
    // For critical systems, consider 3 nodes
    // num_nodes: 3, // Primary + 2 standby nodes
    // ...
};
```

### 2. Security

```rust
// Use VPC networking
private_network_uuid: Some(vpc_id.clone()),

// Configure restrictive firewall rules
let firewall_rules = vec![
    DatabaseFirewallRule {
        type_: "tag".to_string(),
        value: "app-servers".to_string(), // Only allow tagged droplets
    },
    // Avoid: type_: "ip_addr", value: "0.0.0.0/0" (too permissive)
];
```

### 3. Performance Optimization

```rust
// Use connection pooling for high-traffic applications
let pool_spec = DatabasesCreateConnectionPoolBody {
    name: "high-traffic-pool".to_string(),
    mode: "transaction".to_string(), // Better for many short transactions
    size: 50, // Adjust based on your load
    // ...
};

// Create read replicas for read-heavy workloads
let replica_spec = DatabasesCreateReplicaBody {
    region: "sfo3".to_string(), // Geographic distribution
    size: "db-s-1vcpu-2gb".to_string(), // Can be smaller for read-only
    // ...
};
```

### 4. Cost Management

```rust
// Start with appropriate sizing
let cluster_spec = DatabasesCreateClusterBody {
    size: "db-s-1vcpu-1gb".to_string(), // Start small
    num_nodes: 1, // Single node for development
    storage_size_mib: Some(20480), // 20 GB - minimum needed
    // ...
};

// Use tags for cost tracking
tags: Some(vec![
    environment.to_string(),
    team.to_string(),
    format!("cost-center-{}", cost_center),
]),
```

### 5. Backup Strategy

```rust
// Regularly check backup status
async fn monitor_backups(client: &Client, cluster_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.databases_list_backups(cluster_id, None, None).await?;
    let backups = response.into_inner().backups;
    
    // Ensure we have recent backups
    let recent_backup = backups.iter()
        .find(|b| {
            // Check if backup is less than 24 hours old
            // Implementation depends on your time parsing logic
            true
        });
    
    if recent_backup.is_none() {
        println!("⚠️ No recent backups found for cluster {}", cluster_id);
    }
    
    Ok(())
}
```

This comprehensive guide covers all aspects of managed database operations with the rsdo client, from basic cluster management to advanced multi-tier architectures.