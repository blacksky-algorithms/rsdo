#!/bin/bash
set -euxo pipefail

# Function to run pre-publish quality checks
pre_publish_checks() {
    echo "Checking code formatting..."
    cargo fmt --check

    echo "All pre-publish checks passed!"
}

# Main function
main() {
    pre_publish_checks
}

main "$@"
