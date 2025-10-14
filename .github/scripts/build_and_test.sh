#!/bin/bash
set -euxo pipefail

# Function to build and test the project
build_and_test() {
    echo "Building the crate..."
    cargo build --locked --release

    echo "Running doctests..."
    cargo test --doc --locked --release

    echo "Running tests..."
    cargo test --locked --release
}

# Main function
main() {
    build_and_test
}

main "$@"