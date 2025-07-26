#!/bin/bash
set -euxo pipefail

# Function to update version in Cargo.toml
update_cargo_version() {
    local DATE_VERSION="$1"
    
    # Update version in Cargo.toml
    sed -i "s/^version = \".*\"/version = \"${DATE_VERSION}\"/" Cargo.toml
    
    # Verify the change
    echo "Updated Cargo.toml version:"
    grep "^version =" Cargo.toml
}

# Main function
main() {
    local DATE_VERSION="$1"
    
    update_cargo_version "$DATE_VERSION"
}

main "$@"