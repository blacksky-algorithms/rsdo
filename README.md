# RSDO - DigitalOcean Rust Client

> Pronunciation: `/ˈrɪz.doʊ/` (rizz-do)

- because every crate needs a catchy name.


[![Crates.io](https://img.shields.io/crates/v/rsdo.svg)](https://crates.io/crates/rsdo)
[![Documentation](https://docs.rs/rsdo/badge.svg)](https://docs.rs/rsdo)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![CI](https://github.com/blacksky-algorithms/rsdo/workflows/CI/badge.svg)](https://github.com/blacksky-algorithms/rsdo/actions/workflows/ci.yml)
[![MSRV](https://img.shields.io/badge/MSRV-1.70.0-blue.svg)](https://github.com/blacksky-algorithms/rsdo#minimum-supported-rust-version-msrv)
[![Codecov](https://codecov.io/gh/blacksky-algorithms/rsdo/branch/main/graph/badge.svg)](https://codecov.io/gh/blacksky-algorithms/rsdo)

A comprehensive, type-safe Rust client for the DigitalOcean API, automatically generated from the official OpenAPI specification using [progenitor](https://github.com/oxidecomputer/progenitor).

## Features

- 🚀 **Complete API Coverage** - All 500+ DigitalOcean API endpoints
- 🔒 **Type Safety** - Fully typed request/response models
- ⚡ **Async/Await** - Built on tokio and reqwest
- 📚 **Auto-Generated** - Always up-to-date with the latest API
- 🛡️ **Error Handling** - Comprehensive error types
- 📖 **Rich Documentation** - Extensive examples and guides
- 🔄 **Pagination Support** - Built-in pagination helpers
- 🏷️ **Resource Tagging** - Full support for DigitalOcean tags

## Supported Services

| Service | Description | Documentation |
|---------|-------------|---------------|
| **Droplets** | Virtual machines and compute resources | [📖 Guide](docs/droplets.md) |
| **Kubernetes** | Managed Kubernetes clusters (DOKS) | [📖 Guide](docs/kubernetes.md) |
| **Databases** | Managed databases (PostgreSQL, MySQL, Redis/Valkey, MongoDB) | [📖 Guide](docs/databases.md) |
| **VPC** | Virtual Private Cloud networking | [📖 Guide](docs/vpc.md) |
| **Spaces** | S3-compatible object storage with CDN | [📖 Guide](docs/spaces.md) |
| **Load Balancers** | Application and network load balancing | API Reference |
| **Firewalls** | Cloud firewall rules and policies | API Reference |
| **Volumes** | Block storage volumes | API Reference |
| **Snapshots** | Backup and restore functionality | API Reference |
| **Images** | Custom images and distributions | API Reference |
| **SSH Keys** | SSH key management | API Reference |
| **Domains** | DNS management | API Reference |
| **Certificates** | SSL/TLS certificate management | API Reference |
| **Monitoring** | Metrics and alerting | API Reference |
| **Projects** | Resource organization | API Reference |

## Quick Start

### Installation

Add this to your `Cargo.toml`:

```toml
[dependencies]
rsdo = "0.1.0"
reqwest = { version = "0.12", features = ["json"] }
tokio = { version = "1.0", features = ["full"] }
```

### Authentication

Get your API token from the [DigitalOcean Control Panel](https://cloud.digitalocean.com/account/api/tokens):

```rust
use rsdo::{Client, Error};
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create HTTP client with authentication
    let mut headers = HeaderMap::new();
    headers.insert(
        AUTHORIZATION,
        HeaderValue::from_str("Bearer YOUR_DO_API_TOKEN")?,
    );
    
    let http_client = reqwest::Client::builder()
        .default_headers(headers)
        .build()?;
    
    // Create DigitalOcean client
    let client = Client::new_with_client("https://api.digitalocean.com", http_client);
    
    // List your droplets
    let response = client.droplets_list(None, None, None, None).await?;
    let droplets = response.into_inner().droplets;
    
    println!("Found {} droplets:", droplets.len());
    for droplet in droplets {
        println!("  {} - {} ({})", 
            droplet.name, 
            droplet.status, 
            droplet.region.slug
        );
    }
    
    Ok(())
}
```

### Environment Variable Setup

For convenience, set your API token as an environment variable:

```bash
export DIGITALOCEAN_TOKEN="your-api-token-here"
```

Then use it in your code:

```rust
let token = std::env::var("DIGITALOCEAN_TOKEN")?;
headers.insert(
    AUTHORIZATION,
    HeaderValue::from_str(&format!("Bearer {}", token))?,
);
```

## Examples

### Create a Droplet

```rust
use rsdo::types::*;

let droplet_spec = DropletsCreateBody {
    name: "my-server".to_string(),
    region: "nyc3".to_string(),
    size: "s-2vcpu-2gb".to_string(),
    image: "ubuntu-22-04-x64".to_string(),
    ssh_keys: Some(vec!["your-ssh-key-id".to_string()]),
    backups: Some(true),
    ipv6: Some(true),
    monitoring: Some(true),
    tags: Some(vec!["web".to_string(), "production".to_string()]),
    user_data: Some("#!/bin/bash\napt-get update\napt-get install -y nginx".to_string()),
};

let response = client.droplets_create(&droplet_spec).await?;
let droplet = response.into_inner().droplet;
println!("Created droplet: {} ({})", droplet.name, droplet.id);
```

### Create a Kubernetes Cluster

```rust
let cluster_spec = KubernetesCreateClusterBody {
    name: "my-k8s-cluster".to_string(),
    region: "nyc3".to_string(),
    version: "1.28.2-do.0".to_string(),
    auto_upgrade: Some(true),
    node_pools: vec![
        KubernetesNodePool {
            name: "worker-pool".to_string(),
            size: "s-2vcpu-2gb".to_string(),
            count: 3,
            auto_scale: Some(true),
            min_nodes: Some(1),
            max_nodes: Some(5),
            // ... other fields
        }
    ],
    // ... other fields
};

let response = client.kubernetes_create_cluster(&cluster_spec).await?;
let cluster = response.into_inner().kubernetes_cluster;
println!("Created cluster: {} ({})", cluster.name, cluster.id);
```

### Create a Database

```rust
let db_spec = DatabasesCreateClusterBody {
    name: "my-postgres-db".to_string(),
    engine: "pg".to_string(),
    version: "15".to_string(),
    region: "nyc3".to_string(),
    size: "db-s-2vcpu-2gb".to_string(),
    num_nodes: 2, // High availability
    db_name: Some("myapp".to_string()),
    db_user: Some("myapp_user".to_string()),
    tags: Some(vec!["production".to_string(), "postgres".to_string()]),
    // ... other fields
};

let response = client.databases_create_cluster(&db_spec).await?;
let database = response.into_inner().database;
println!("Created database: {} ({})", database.name, database.id);
```

### Upload to Spaces (S3-Compatible)

```rust
use aws_sdk_s3::{Client as S3Client, Config, Credentials, Region};

// Setup S3 client for Spaces
let credentials = Credentials::new("access_key", "secret_key", None, None, "spaces");
let config = aws_sdk_s3::config::Builder::new()
    .credentials_provider(credentials)
    .region(Region::new("nyc3"))
    .endpoint_url("https://nyc3.digitaloceanspaces.com")
    .build();

let s3_client = S3Client::from_conf(config);

// Upload file
s3_client
    .put_object()
    .bucket("my-space")
    .key("uploads/file.jpg")
    .body(aws_sdk_s3::primitives::ByteStream::from_path("local-file.jpg").await?)
    .acl("public-read".into())
    .send()
    .await?;

println!("File uploaded to Spaces!");
```

## Error Handling

The client provides comprehensive error handling:

```rust
use rsdo::Error;

match client.droplets_get("invalid-id").await {
    Ok(response) => {
        let droplet = response.into_inner().droplet;
        println!("Droplet: {}", droplet.name);
    }
    Err(Error::ErrorResponse(resp)) => {
        match resp.status().as_u16() {
            404 => println!("Droplet not found"),
            401 => println!("Authentication failed - check your API token"),
            429 => println!("Rate limit exceeded - slow down requests"),
            _ => println!("API error: {}", resp.status()),
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
```

## Pagination

Many API endpoints support pagination:

```rust
let mut page = 1;
let per_page = 50;

loop {
    let response = client.droplets_list(
        Some(per_page),
        Some(page),
        None, // tag filter
        None, // name filter
    ).await?;
    
    let droplets_response = response.into_inner();
    let droplets = droplets_response.droplets;
    
    println!("Page {} - {} droplets", page, droplets.len());
    for droplet in droplets {
        println!("  {}", droplet.name);
    }
    
    // Check if there are more pages
    if let Some(links) = droplets_response.links {
        if links.pages.as_ref().and_then(|p| p.next.as_ref()).is_some() {
            page += 1;
        } else {
            break;
        }
    } else {
        break;
    }
}
```

## Configuration

### Using Environment Variables

You can configure the client using environment variables:

```bash
# Required
export DIGITALOCEAN_TOKEN="your-api-token"

# Optional
export DIGITALOCEAN_API_URL="https://api.digitalocean.com"  # Custom API endpoint
export DIGITALOCEAN_TIMEOUT="30"                            # Request timeout in seconds
```

### Custom HTTP Client

```rust
use std::time::Duration;

let http_client = reqwest::Client::builder()
    .timeout(Duration::from_secs(30))
    .user_agent("MyApp/1.0")
    .default_headers(headers)
    .build()?;

let client = Client::new_with_client("https://api.digitalocean.com", http_client);
```

## Complete Examples

Check out the comprehensive guides for complete, production-ready examples:

- **[Web Server Deployment](docs/droplets.md#complete-example-web-server-deployment)** - Full droplet lifecycle with nginx, firewall, and monitoring
- **[Kubernetes Cluster Setup](docs/kubernetes.md#complete-example-full-cluster-lifecycle)** - End-to-end cluster creation with node pools and configuration
- **[Multi-tier Database](docs/databases.md#complete-example-multi-tier-application)** - PostgreSQL + Redis setup with replicas and connection pooling
- **[Static Website Hosting](docs/spaces.md#complete-example-static-website-hosting)** - Spaces + CDN setup for static sites
- **[VPC Infrastructure](docs/vpc.md#complete-example)** - Private networking setup with proper resource organization

## Development

### Building from Source

```bash
git clone https://github.com/your-username/rsdo.git
cd rsdo
cargo build
```

### Running Tests

```bash
# Unit tests
cargo test

# Integration tests (requires API token)
DIGITALOCEAN_TOKEN="your-token" cargo test --features integration
```

### Code Generation

This client is auto-generated from the DigitalOcean OpenAPI specification. To regenerate:

```bash
cargo build  # The build.rs script handles regeneration
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Reporting Issues

- **API Issues**: If you find issues with the generated client, please check if it's an upstream OpenAPI spec issue
- **Documentation**: Help improve our examples and documentation
- **Features**: Suggest new features or improvements

## Minimum Supported Rust Version (MSRV)

**Current MSRV**: `1.70.0`

### MSRV Policy

This crate follows an aggressive MSRV policy to take advantage of the latest Rust language features, performance improvements, and safety enhancements:

- ✅ **MSRV can be raised at any time** for new features, safety improvements, or maintainability
- ✅ **MSRV increases will result in a semver minor release** (not patch)
- ✅ **We will always document MSRV changes** in release notes and changelog
- ✅ **No advance warning period** - we adopt new language features as soon as they're beneficial

### For Users

- If you need to support older Rust versions, **pin to a specific version range** in your `Cargo.toml`:
  ```toml
  [dependencies]
  rsdo = ">=1.0.0, <1.2.0"  # Example: avoid MSRV bumps in 1.2.0+
  ```
- Check the [`rust-version`](https://doc.rust-lang.org/cargo/reference/manifest.html#the-rust-version-field) field in our `Cargo.toml` for the current MSRV
- Our CI automatically tests against the declared MSRV to ensure compatibility

This policy allows us to provide the safest, most performant, and maintainable DigitalOcean client possible by leveraging the latest Rust ecosystem improvements.

## API Reference

Full API documentation is available at [docs.rs/rsdo](https://docs.rs/rsdo).

For DigitalOcean API documentation, see: https://docs.digitalocean.com/reference/api/

## Rate Limiting

DigitalOcean API has rate limits:
- **5,000 requests per hour** per API token
- **250 requests per minute** per API token

The client doesn't automatically handle rate limiting, but you can implement retry logic:

```rust
use tokio::time::{sleep, Duration};

async fn with_retry<T, F, Fut>(mut f: F) -> Result<T, Error<T>>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T, Error<T>>>,
{
    let mut attempts = 0;
    let max_attempts = 3;
    
    loop {
        match f().await {
            Ok(result) => return Ok(result),
            Err(Error::ErrorResponse(resp)) if resp.status().as_u16() == 429 => {
                attempts += 1;
                if attempts >= max_attempts {
                    return Err(Error::ErrorResponse(resp));
                }
                
                // Exponential backoff
                let delay = Duration::from_secs(2_u64.pow(attempts));
                sleep(delay).await;
            }
            Err(e) => return Err(e),
        }
    }
}
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [progenitor](https://github.com/oxidecomputer/progenitor) for type-safe API client generation
- Powered by [reqwest](https://github.com/seanmonstar/reqwest) for HTTP client functionality
- Uses [tokio](https://github.com/tokio-rs/tokio) for async runtime

---

**🚀 Ready to build amazing things with DigitalOcean and Rust!**

For questions, issues, or contributions, please visit our [GitHub repository](https://github.com/your-username/rsdo).