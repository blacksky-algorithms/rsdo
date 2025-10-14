#!/bin/bash
set -euxo pipefail

# Function to generate SBOM files
generate_sbom() {
    local FORMAT="$1"

    cargo cyclonedx --format "$FORMAT" --override-filename "rsdo-sbom"
}

# Function to generate both JSON and XML SBOM files
generate_all_sbom() {
    generate_sbom "json"
    generate_sbom "xml"
}

# Main function
main() {
    local FORMAT="${1:-all}"

    if [ "$FORMAT" = "all" ]; then
        generate_all_sbom
    else
        generate_sbom "$FORMAT"
    fi
}

main "$@"