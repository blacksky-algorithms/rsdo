#!/bin/bash
set -euxo pipefail

# Function to generate SBOM files
generate_sbom() {
    local VERSION="$1"
    local FORMAT="$2"
    
    cargo cyclonedx --format "$FORMAT" --override-filename "rsdo-sbom-${VERSION}"
}

# Function to generate both JSON and XML SBOM files
generate_all_sbom() {
    local VERSION="$1"
    
    generate_sbom "$VERSION" "json"
    generate_sbom "$VERSION" "xml"
}

# Main function
main() {
    local VERSION="$1"
    local FORMAT="${2:-all}"
    
    if [ "$FORMAT" = "all" ]; then
        generate_all_sbom "$VERSION"
    else
        generate_sbom "$VERSION" "$FORMAT"
    fi
}

main "$@"