# Spaces (S3-Compatible Object Storage)

DigitalOcean Spaces provides S3-compatible object storage for files, images, backups, and static assets. This guide covers Spaces management using the rsdo client, including CDN integration.

## Overview

Spaces provides:
- S3-compatible object storage API
- Built-in CDN (Content Delivery Network)
- CORS configuration for web applications
- Access control and permissions
- Lifecycle policies for automated management
- Integration with other DigitalOcean services

Key concepts:
- **Space** - Storage bucket (equivalent to S3 bucket)
- **Objects** - Files stored in Spaces
- **Access Keys** - Credentials for API access
- **CDN Endpoint** - Global edge locations for fast content delivery

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

## Spaces Access Key Management

### Create Spaces Access Key

```rust
async fn create_spaces_key(client: &Client) -> Result<(String, String), Box<dyn std::error::Error>> {
    let key_spec = SpacesKeyCreateBody {
        name: "my-app-spaces-key".to_string(),
    };
    
    let response = client.spaces_key_create(&key_spec).await?;
    let key = response.into_inner().access_key;
    
    println!("✅ Created Spaces access key: {}", key.name);
    println!("   Access Key ID: {}", key.access_key_id);
    
    // The secret is only returned on creation
    let secret = key.secret_access_key.unwrap_or_default();
    println!("   Secret Access Key: {} (save this securely!)", secret);
    
    Ok((key.access_key_id, secret))
}
```

### List Spaces Access Keys

```rust
async fn list_spaces_keys(client: &Client) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.spaces_key_list(None, None).await?;
    let keys = response.into_inner().access_keys;
    
    println!("Spaces Access Keys ({}):", keys.len());
    for key in keys {
        println!("  {} - {}", key.name, key.access_key_id);
        println!("    Created: {}", key.created_at);
    }
    
    Ok(())
}
```

### Get Spaces Key Details

```rust
async fn get_spaces_key(client: &Client, key_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let response = client.spaces_key_get(key_id).await?;
    let key = response.into_inner().access_key;
    
    println!("Spaces Key Details:");
    println!("  Name: {}", key.name);
    println!("  Access Key ID: {}", key.access_key_id);
    println!("  Created: {}", key.created_at);
    
    Ok(())
}
```

### Update Spaces Key

```rust
async fn update_spaces_key(client: &Client, key_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let update_spec = SpacesKeyUpdateBody {
        name: "updated-spaces-key".to_string(),
    };
    
    let response = client.spaces_key_update(key_id, &update_spec).await?;
    let key = response.into_inner().access_key;
    
    println!("✅ Updated Spaces key: {}", key.name);
    
    Ok(())
}
```

### Delete Spaces Key

```rust
async fn delete_spaces_key(client: &Client, key_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    client.spaces_key_delete(key_id).await?;
    println!("🗑️  Spaces key deleted: {}", key_id);
    
    Ok(())
}
```

## S3-Compatible Operations

Since Spaces is S3-compatible, you can use standard S3 clients. Here's how to set up and use S3 operations with Spaces:

### Setup S3 Client for Spaces

```rust
use aws_sdk_s3::{Client as S3Client, Config, Credentials, Region};
use aws_sdk_s3::config::Builder as ConfigBuilder;

async fn create_s3_client(
    access_key_id: &str,
    secret_access_key: &str,
    region: &str // e.g., "nyc3", "ams3", "sgp1"
) -> Result<S3Client, Box<dyn std::error::Error>> {
    let credentials = Credentials::new(
        access_key_id,
        secret_access_key,
        None, // session_token
        None, // expires_at
        "spaces"
    );
    
    let endpoint_url = format!("https://{}.digitaloceanspaces.com", region);
    
    let config = ConfigBuilder::new()
        .credentials_provider(credentials)
        .region(Region::new(region.to_string()))
        .endpoint_url(&endpoint_url)
        .build();
    
    Ok(S3Client::from_conf(config))
}
```

### Create a Space (Bucket)

```rust
async fn create_space(
    s3_client: &S3Client,
    space_name: &str
) -> Result<(), Box<dyn std::error::Error>> {
    s3_client
        .create_bucket()
        .bucket(space_name)
        .send()
        .await?;
    
    println!("✅ Created Space: {}", space_name);
    
    Ok(())
}
```

### List Spaces

```rust
async fn list_spaces(s3_client: &S3Client) -> Result<(), Box<dyn std::error::Error>> {
    let response = s3_client.list_buckets().send().await?;
    
    if let Some(buckets) = response.buckets {
        println!("Spaces ({}):", buckets.len());
        for bucket in buckets {
            if let Some(name) = bucket.name {
                println!("  {} - Created: {:?}", name, bucket.creation_date);
            }
        }
    }
    
    Ok(())
}
```

### Upload File to Space

```rust
use aws_sdk_s3::primitives::ByteStream;
use std::path::Path;

async fn upload_file(
    s3_client: &S3Client,
    space_name: &str,
    local_path: &str,
    object_key: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let body = ByteStream::from_path(Path::new(local_path)).await?;
    
    s3_client
        .put_object()
        .bucket(space_name)
        .key(object_key)
        .body(body)
        .content_type(mime_guess::from_path(local_path)
            .first_or_octet_stream()
            .to_string())
        .send()
        .await?;
    
    println!("✅ Uploaded {} to {}/{}", local_path, space_name, object_key);
    
    Ok(())
}
```

### Upload with Public Access

```rust
async fn upload_public_file(
    s3_client: &S3Client,
    space_name: &str,
    local_path: &str,
    object_key: &str
) -> Result<String, Box<dyn std::error::Error>> {
    let body = ByteStream::from_path(Path::new(local_path)).await?;
    
    s3_client
        .put_object()
        .bucket(space_name)
        .key(object_key)
        .body(body)
        .acl("public-read".into()) // Make publicly accessible
        .content_type(mime_guess::from_path(local_path)
            .first_or_octet_stream()
            .to_string())
        .send()
        .await?;
    
    // Generate public URL
    let region = "nyc3"; // Use your region
    let public_url = format!("https://{}.{}.digitaloceanspaces.com/{}", 
        space_name, region, object_key);
    
    println!("✅ Uploaded public file: {}", public_url);
    
    Ok(public_url)
}
```

### List Objects in Space

```rust
async fn list_objects(
    s3_client: &S3Client,
    space_name: &str,
    prefix: Option<&str>
) -> Result<(), Box<dyn std::error::Error>> {
    let mut request = s3_client.list_objects_v2().bucket(space_name);
    
    if let Some(prefix) = prefix {
        request = request.prefix(prefix);
    }
    
    let response = request.send().await?;
    
    if let Some(objects) = response.contents {
        println!("Objects in {} ({}):", space_name, objects.len());
        for object in objects {
            if let (Some(key), Some(size)) = (object.key, object.size) {
                println!("  {} - {} bytes", key, size);
                if let Some(modified) = object.last_modified {
                    println!("    Modified: {}", modified);
                }
            }
        }
    }
    
    Ok(())
}
```

### Download File from Space

```rust
async fn download_file(
    s3_client: &S3Client,
    space_name: &str,
    object_key: &str,
    local_path: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let response = s3_client
        .get_object()
        .bucket(space_name)
        .key(object_key)
        .send()
        .await?;
    
    let data = response.body.collect().await?;
    std::fs::write(local_path, data.into_bytes())?;
    
    println!("✅ Downloaded {}/{} to {}", space_name, object_key, local_path);
    
    Ok(())
}
```

### Delete Object

```rust
async fn delete_object(
    s3_client: &S3Client,
    space_name: &str,
    object_key: &str
) -> Result<(), Box<dyn std::error::Error>> {
    s3_client
        .delete_object()
        .bucket(space_name)
        .key(object_key)
        .send()
        .await?;
    
    println!("🗑️  Deleted object: {}/{}", space_name, object_key);
    
    Ok(())
}
```

### Generate Presigned URLs

```rust
use aws_sdk_s3::presigning::PresigningConfig;
use std::time::Duration;

async fn generate_presigned_url(
    s3_client: &S3Client,
    space_name: &str,
    object_key: &str,
    expires_in: Duration
) -> Result<String, Box<dyn std::error::Error>> {
    let presigning_config = PresigningConfig::expires_in(expires_in)?;
    
    let presigned_request = s3_client
        .get_object()
        .bucket(space_name)
        .key(object_key)
        .presigned(presigning_config)
        .await?;
    
    let url = presigned_request.uri().to_string();
    println!("🔗 Presigned URL (expires in {:?}): {}", expires_in, url);
    
    Ok(url)
}
```

### Upload Presigned URL

```rust
async fn generate_upload_presigned_url(
    s3_client: &S3Client,
    space_name: &str,
    object_key: &str,
    content_type: &str,
    expires_in: Duration
) -> Result<String, Box<dyn std::error::Error>> {
    let presigning_config = PresigningConfig::expires_in(expires_in)?;
    
    let presigned_request = s3_client
        .put_object()
        .bucket(space_name)
        .key(object_key)
        .content_type(content_type)
        .presigned(presigning_config)
        .await?;
    
    let url = presigned_request.uri().to_string();
    println!("🔗 Upload presigned URL: {}", url);
    
    Ok(url)
}
```

## CORS Configuration

### Set CORS Rules

```rust
use aws_sdk_s3::types::{CorsConfiguration, CorsRule};

async fn configure_cors(
    s3_client: &S3Client,
    space_name: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let cors_rule = CorsRule::builder()
        .allowed_origins("https://myapp.com")
        .allowed_origins("https://www.myapp.com")
        .allowed_methods("GET")
        .allowed_methods("PUT")
        .allowed_methods("POST")
        .allowed_methods("DELETE")
        .allowed_headers("*")
        .max_age_seconds(3600)
        .build();
    
    let cors_config = CorsConfiguration::builder()
        .cors_rules(cors_rule)
        .build();
    
    s3_client
        .put_bucket_cors()
        .bucket(space_name)
        .cors_configuration(cors_config)
        .send()
        .await?;
    
    println!("✅ CORS configuration updated for {}", space_name);
    
    Ok(())
}
```

### Get CORS Configuration

```rust
async fn get_cors_config(
    s3_client: &S3Client,
    space_name: &str
) -> Result<(), Box<dyn std::error::Error>> {
    let response = s3_client
        .get_bucket_cors()
        .bucket(space_name)
        .send()
        .await?;
    
    if let Some(cors_rules) = response.cors_configuration?.cors_rules {
        println!("CORS Rules for {}:", space_name);
        for (i, rule) in cors_rules.iter().enumerate() {
            println!("  Rule {}:", i + 1);
            println!("    Allowed Origins: {:?}", rule.allowed_origins);
            println!("    Allowed Methods: {:?}", rule.allowed_methods);
            println!("    Allowed Headers: {:?}", rule.allowed_headers);
            if let Some(max_age) = rule.max_age_seconds {
                println!("    Max Age: {} seconds", max_age);
            }
        }
    }
    
    Ok(())
}
```

## CDN Integration

Spaces automatically includes CDN endpoints for fast global content delivery:

### Get CDN URLs

```rust
fn get_cdn_url(space_name: &str, region: &str, object_key: &str) -> String {
    format!("https://{}.{}.cdn.digitaloceanspaces.com/{}", 
        space_name, region, object_key)
}

fn get_direct_url(space_name: &str, region: &str, object_key: &str) -> String {
    format!("https://{}.{}.digitaloceanspaces.com/{}", 
        space_name, region, object_key)
}

// Usage example
fn demo_urls() {
    let space_name = "my-assets";
    let region = "nyc3";
    let object_key = "images/logo.png";
    
    let direct_url = get_direct_url(space_name, region, object_key);
    let cdn_url = get_cdn_url(space_name, region, object_key);
    
    println!("Direct URL: {}", direct_url);
    println!("CDN URL: {}", cdn_url);
    println!("💡 Use CDN URL for better performance and caching");
}
```

## Complete Example: Static Website Hosting

```rust
use rsdo::{Client, Error};
use rsdo::types::*;
use aws_sdk_s3::{Client as S3Client, Config, Credentials, Region};
use aws_sdk_s3::config::Builder as ConfigBuilder;
use aws_sdk_s3::primitives::ByteStream;
use aws_sdk_s3::types::{CorsConfiguration, CorsRule};
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION};
use std::path::Path;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Setup DigitalOcean API client
    let mut headers = HeaderMap::new();
    headers.insert(
        AUTHORIZATION,
        HeaderValue::from_str(&format!("Bearer {}", 
            std::env::var("DIGITALOCEAN_TOKEN")?))?,
    );
    
    let http_client = reqwest::Client::builder()
        .default_headers(headers)
        .build()?;
    
    let do_client = Client::new_with_client("https://api.digitalocean.com", http_client);
    
    println!("🚀 Setting up static website hosting with Spaces...");
    
    // 1. Create Spaces access key
    println!("🔑 Creating Spaces access key...");
    let key_spec = SpacesKeyCreateBody {
        name: "static-website-key".to_string(),
    };
    
    let response = do_client.spaces_key_create(&key_spec).await?;
    let key = response.into_inner().access_key;
    let access_key_id = key.access_key_id.clone();
    let secret_key = key.secret_access_key.unwrap_or_default();
    
    println!("✅ Created access key: {}", key.name);
    
    // 2. Setup S3 client for Spaces
    let region = "nyc3";
    let credentials = Credentials::new(
        &access_key_id,
        &secret_key,
        None,
        None,
        "spaces"
    );
    
    let endpoint_url = format!("https://{}.digitaloceanspaces.com", region);
    
    let config = ConfigBuilder::new()
        .credentials_provider(credentials)
        .region(Region::new(region.to_string()))
        .endpoint_url(&endpoint_url)
        .build();
    
    let s3_client = S3Client::from_conf(config);
    
    // 3. Create Space for website
    let space_name = "my-static-website";
    println!("📦 Creating Space: {}", space_name);
    
    s3_client
        .create_bucket()
        .bucket(space_name)
        .send()
        .await?;
    
    println!("✅ Space created successfully");
    
    // 4. Create sample website files
    println!("📝 Creating sample website files...");
    
    // Create index.html
    let index_html = r#"<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My Static Website</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>🌟 Welcome to My Static Website</h1>
            <p>Hosted on DigitalOcean Spaces with CDN</p>
        </header>
        
        <main>
            <section>
                <h2>About This Site</h2>
                <p>This is a static website hosted on DigitalOcean Spaces, 
                   demonstrating S3-compatible object storage with CDN delivery.</p>
                
                <img src="images/sample.jpg" alt="Sample Image" class="sample-image">
            </section>
            
            <section>
                <h2>Features</h2>
                <ul>
                    <li>✅ Fast global CDN delivery</li>
                    <li>✅ S3-compatible API</li>
                    <li>✅ Custom domain support</li>
                    <li>✅ CORS configuration</li>
                </ul>
            </section>
        </main>
        
        <footer>
            <p>Powered by DigitalOcean Spaces & RSDO Client</p>
        </footer>
    </div>
    
    <script src="script.js"></script>
</body>
</html>"#;
    
    // Create styles.css
    let styles_css = r#"* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    color: #333;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
}

.container {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem;
    background: rgba(255, 255, 255, 0.95);
    border-radius: 10px;
    margin-top: 2rem;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
}

header {
    text-align: center;
    margin-bottom: 2rem;
    padding-bottom: 1rem;
    border-bottom: 2px solid #eee;
}

h1 {
    color: #4a5568;
    margin-bottom: 0.5rem;
}

h2 {
    color: #2d3748;
    margin-bottom: 1rem;
}

.sample-image {
    max-width: 100%;
    height: auto;
    border-radius: 8px;
    margin: 1rem 0;
}

ul {
    padding-left: 1.5rem;
}

li {
    margin-bottom: 0.5rem;
}

footer {
    text-align: center;
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #eee;
    color: #666;
}"#;
    
    // Create script.js
    let script_js = r#"console.log('🚀 Static website loaded from DigitalOcean Spaces!');

// Add some interactive functionality
document.addEventListener('DOMContentLoaded', function() {
    const header = document.querySelector('header');
    
    header.addEventListener('click', function() {
        const colors = ['#667eea', '#764ba2', '#f093fb', '#f5576c', '#4facfe', '#00f2fe'];
        const randomColor = colors[Math.floor(Math.random() * colors.length)];
        document.body.style.background = `linear-gradient(135deg, ${randomColor} 0%, #764ba2 100%)`;
    });
    
    console.log('✨ Click the header to change colors!');
});"#;
    
    // Upload files
    println!("📤 Uploading website files...");
    
    // Upload index.html
    s3_client
        .put_object()
        .bucket(space_name)
        .key("index.html")
        .body(ByteStream::from_static(index_html.as_bytes()))
        .content_type("text/html")
        .acl("public-read".into())
        .send()
        .await?;
    
    // Upload styles.css
    s3_client
        .put_object()
        .bucket(space_name)
        .key("styles.css")
        .body(ByteStream::from_static(styles_css.as_bytes()))
        .content_type("text/css")
        .acl("public-read".into())
        .send()
        .await?;
    
    // Upload script.js
    s3_client
        .put_object()
        .bucket(space_name)
        .key("script.js")
        .body(ByteStream::from_static(script_js.as_bytes()))
        .content_type("application/javascript")
        .acl("public-read".into())
        .send()
        .await?;
    
    // Create and upload a sample image (placeholder)
    let sample_image = r#"<svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#667eea"/>
        <text x="50%" y="50%" font-family="Arial" font-size="24" fill="white" 
              text-anchor="middle" dy=".3em">Sample Image</text>
    </svg>"#;
    
    // Create images directory and upload
    s3_client
        .put_object()
        .bucket(space_name)
        .key("images/sample.jpg")
        .body(ByteStream::from_static(sample_image.as_bytes()))
        .content_type("image/svg+xml")
        .acl("public-read".into())
        .send()
        .await?;
    
    println!("✅ All files uploaded successfully");
    
    // 5. Configure CORS for web access
    println!("🔧 Configuring CORS...");
    
    let cors_rule = CorsRule::builder()
        .allowed_origins("*") // Allow all origins for demo
        .allowed_methods("GET")
        .allowed_methods("HEAD")
        .allowed_headers("*")
        .max_age_seconds(3600)
        .build();
    
    let cors_config = CorsConfiguration::builder()
        .cors_rules(cors_rule)
        .build();
    
    s3_client
        .put_bucket_cors()
        .bucket(space_name)
        .cors_configuration(cors_config)
        .send()
        .await?;
    
    println!("✅ CORS configured");
    
    // 6. List uploaded objects
    println!("📋 Listing uploaded files...");
    let response = s3_client
        .list_objects_v2()
        .bucket(space_name)
        .send()
        .await?;
    
    if let Some(objects) = response.contents {
        for object in objects {
            if let Some(key) = object.key {
                println!("   📄 {}", key);
            }
        }
    }
    
    // 7. Display access URLs
    println!("\n🎉 Static website setup completed!");
    
    let direct_url = format!("https://{}.{}.digitaloceanspaces.com/index.html", 
        space_name, region);
    let cdn_url = format!("https://{}.{}.cdn.digitaloceanspaces.com/index.html", 
        space_name, region);
    
    println!("\n🔗 Access URLs:");
    println!("   Direct: {}", direct_url);
    println!("   CDN (Recommended): {}", cdn_url);
    
    println!("\n📋 Next steps:");
    println!("   1. Visit the CDN URL to see your website");
    println!("   2. Configure a custom domain if needed");
    println!("   3. Set up automated deployment pipeline");
    println!("   4. Add SSL certificate for custom domain");
    
    println!("\n💡 Tips:");
    println!("   - Use CDN URLs for better performance");
    println!("   - Set appropriate cache headers for static assets");
    println!("   - Use subfolders to organize content");
    println!("   - Consider lifecycle policies for old content");
    
    Ok(())
}
```

## Best Practices

### 1. Security and Access Control

```rust
// Use specific CORS origins instead of "*"
let cors_rule = CorsRule::builder()
    .allowed_origins("https://yourdomain.com")
    .allowed_origins("https://www.yourdomain.com")
    .allowed_methods("GET")
    .allowed_headers("*")
    .build();

// Create separate access keys for different applications
let key_spec = SpacesKeyCreateBody {
    name: format!("{}-{}-key", app_name, environment),
};
```

### 2. Performance Optimization

```rust
// Always use CDN URLs for public content
fn get_optimized_url(space_name: &str, region: &str, object_key: &str) -> String {
    // Use CDN endpoint for better performance
    format!("https://{}.{}.cdn.digitaloceanspaces.com/{}", 
        space_name, region, object_key)
}

// Set appropriate Content-Type headers
s3_client
    .put_object()
    .bucket(space_name)
    .key(object_key)
    .body(body)
    .content_type(content_type) // Important for proper handling
    .cache_control("public, max-age=86400") // Set cache headers
    .send()
    .await?;
```

### 3. Cost Management

```rust
// Use lifecycle policies to automatically delete old files
// (Configure through DigitalOcean control panel or direct S3 API)

// Organize files efficiently
let organized_key = format!("{}/{}/{}", 
    date.format("%Y/%m"), 
    category,
    filename
);
```

### 4. Error Handling

```rust
async fn robust_upload(
    s3_client: &S3Client,
    space_name: &str,
    local_path: &str,
    object_key: &str
) -> Result<(), Box<dyn std::error::Error>> {
    // Check file exists
    if !Path::new(local_path).exists() {
        return Err(format!("File not found: {}", local_path).into());
    }
    
    // Retry logic for uploads
    let mut attempts = 0;
    let max_attempts = 3;
    
    while attempts < max_attempts {
        match upload_file(s3_client, space_name, local_path, object_key).await {
            Ok(_) => return Ok(()),
            Err(e) => {
                attempts += 1;
                if attempts >= max_attempts {
                    return Err(e);
                }
                println!("Upload attempt {} failed, retrying...", attempts);
                tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
            }
        }
    }
    
    Ok(())
}
```

This comprehensive guide covers all aspects of Spaces management with the rsdo client, from basic object operations to complex static website hosting scenarios with CDN integration.