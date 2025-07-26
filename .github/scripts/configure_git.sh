#!/bin/bash
set -euxo pipefail

# Function to configure git with GitHub Actions bot credentials
configure_git() {
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
}

# Main function
main() {
    configure_git
}

main "$@"