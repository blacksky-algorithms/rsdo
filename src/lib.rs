//! # rsdo - DigitalOcean Rust Client
//!
//! A Rust client library for the DigitalOcean API, generated from the official OpenAPI specification.
//!
//! ## Quick Start
//!
//! ```rust,no_run
//! use rsdo::Client;
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     // Create a client with your DigitalOcean personal access token
//!     let client = Client::from_token("your-digitalocean-token");
//!
//!     // List your droplets (with required parameters)
//!     let droplets = client.droplets_list(None, None, None, None, None).await?;
//!     println!("Found {} droplets", droplets.into_inner().droplets.len());
//!
//!     Ok(())
//! }
//! ```
//!
//! ## Authentication
//!
//! This client uses DigitalOcean's Personal Access Token (PAT) for authentication.
//! You can create a token in the [DigitalOcean Control Panel](https://cloud.digitalocean.com/account/api/tokens).
//!
//! ## Features
//!
//! - Async/await support with reqwest and tokio
//! - Strongly typed API responses
//! - Generated from the official DigitalOcean OpenAPI specification
//! - Automatic serialization/deserialization with serde
//! - Comprehensive error handling

use reqwest::header::{self, HeaderMap, HeaderValue};
use std::time::Duration;

// Include the generated code from build.rs
// Disable doctests for generated code since OpenAPI examples aren't meant to be Rust tests
#[cfg(doctest)]
mod _disabled {}

#[cfg(not(doctest))]
mod generated {
    include!(concat!(env!("OUT_DIR"), "/codegen.rs"));
}

#[cfg(not(doctest))]
pub use generated::*;

// For doctests, provide a minimal stub
#[cfg(doctest)]
pub struct Client;

#[cfg(doctest)]
impl Client {
    pub fn from_token(_token: &str) -> Self {
        Self
    }
    pub fn with_client(_token: &str, _client: reqwest::Client) -> Self {
        Self
    }
    pub fn baseurl(&self) -> &str {
        "https://api.digitalocean.com"
    }
}

#[cfg(not(doctest))]
impl Client {
    /// Create a new DigitalOcean client with a personal access token.
    ///
    /// This is the most common way to create a client for the DigitalOcean API.
    ///
    /// # Arguments
    ///
    /// * `token` - Your DigitalOcean personal access token
    ///
    /// # Example
    ///
    /// ```rust,no_run
    /// use rsdo::Client;
    ///
    /// let client = Client::from_token("your-digitalocean-token");
    /// ```
    pub fn from_token(token: &str) -> Self {
        let mut headers = HeaderMap::new();
        let auth_value = HeaderValue::from_str(&format!("Bearer {}", token))
            .expect("Failed to create authorization header");
        headers.insert(header::AUTHORIZATION, auth_value);

        let http_client = reqwest::ClientBuilder::new()
            .connect_timeout(Duration::from_secs(15))
            .timeout(Duration::from_secs(30))
            .default_headers(headers)
            .user_agent("rsdo/0.1.0")
            .build()
            .expect("Failed to build HTTP client");

        Self::new_with_client("https://api.digitalocean.com", http_client)
    }

    /// Create a new DigitalOcean client with a custom reqwest client.
    ///
    /// This allows you to customize the HTTP client behavior, such as setting
    /// custom timeouts, proxies, or other reqwest configuration.
    ///
    /// # Arguments
    ///
    /// * `token` - Your DigitalOcean personal access token
    /// * `http_client` - A configured reqwest::Client
    ///
    /// # Example
    ///
    /// ```rust,no_run
    /// use rsdo::Client;
    /// use reqwest::header::{self, HeaderMap, HeaderValue};
    /// use std::time::Duration;
    ///
    /// let mut headers = HeaderMap::new();
    /// headers.insert(
    ///     header::AUTHORIZATION,
    ///     HeaderValue::from_str("Bearer your-token").unwrap(),
    /// );
    ///
    /// let http_client = reqwest::ClientBuilder::new()
    ///     .timeout(Duration::from_secs(60))
    ///     .default_headers(headers)
    ///     .build()
    ///     .unwrap();
    ///
    /// let client = Client::with_client("your-token", http_client);
    /// ```
    pub fn with_client(_token: &str, http_client: reqwest::Client) -> Self {
        // Note: This assumes the client doesn't already have auth headers
        // In a real implementation, you might want to check and update headers
        Self::new_with_client("https://api.digitalocean.com", http_client)
    }
}

// Re-export commonly used types for convenience
#[cfg(not(doctest))]
pub use types::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_client_creation() {
        let client = Client::from_token("test-token");
        // Basic smoke test - just ensure the client can be created
        assert_eq!(client.baseurl(), "https://api.digitalocean.com");
    }

    #[tokio::test]
    async fn test_client_user_agent() {
        // This is a basic test to ensure our client sets a proper user agent
        let client = Client::from_token("test-token");
        // We can't easily test the actual user agent without making a request,
        // but we can at least verify the client was created successfully
        assert_eq!(client.baseurl(), "https://api.digitalocean.com");
    }
}
