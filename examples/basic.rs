use rsdo::{Client, ClientInfo};

fn main() {
    println!("Creating DigitalOcean client...");

    // Create a reqwest client
    let http_client = reqwest::Client::new();

    // Create the DigitalOcean client
    let client = Client::new_with_client("https://api.digitalocean.com/v2", http_client);

    println!("Client created successfully!");
    println!("Base URL: {}", client.baseurl());

    // The client is ready to use - in a real application you would add authentication
    // and make actual API calls here
}
