#!/bin/bash
set -euxo pipefail

# Function to update Cargo.lock
update_cargo_lock() {
    cargo check --locked || cargo update
}

# Main function
main() {
    update_cargo_lock
}

main "$@"