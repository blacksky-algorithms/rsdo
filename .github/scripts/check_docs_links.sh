#!/bin/bash
set -euxo pipefail

# Function to install cargo-deadlinks if not cached
install_cargo_deadlinks() {
    if ! command -v cargo-deadlinks &> /dev/null; then
        cargo install cargo-deadlinks
    fi
}

# Function to check for broken intra-doc links
#
# NOTE: --check-http is deliberately NOT used. The generated client carries the
# whole DigitalOcean API description, so --check-http fired thousands of live
# requests at external hosts: the Documentation job took ~30 minutes and failed
# on every PR as soon as any one of those third-party URLs rate-limited, moved,
# or went down. Broken *external* links upstream are not this crate's bug.
# Intra-doc links are still fully checked.
check_deadlinks() {
    cargo deadlinks
}

# Main function
main() {
    install_cargo_deadlinks
    check_deadlinks
}

main "$@"