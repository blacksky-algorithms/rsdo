#!/bin/bash
set -euxo pipefail

# Function to install cargo-deadlinks if not cached
install_cargo_deadlinks() {
    if ! command -v cargo-deadlinks &> /dev/null; then
        cargo install cargo-deadlinks
    fi
}

# Function to check for broken links in documentation
check_deadlinks() {
    cargo deadlinks --check-http
}

# Main function
main() {
    install_cargo_deadlinks
    check_deadlinks
}

main "$@"