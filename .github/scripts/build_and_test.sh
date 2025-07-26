#!/bin/bash
set -euxo pipefail

# Function to build and test the project
build_and_test() {
    cargo build --locked --release
    cargo test --locked --release
}

# Main function
main() {
    build_and_test
}

main "$@"