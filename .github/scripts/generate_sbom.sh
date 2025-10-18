#!/bin/bash
set -euo pipefail

# Function to check if cargo-cyclonedx is installed
check_cyclonedx() {
    if ! command -v cargo-cyclonedx &> /dev/null; then
        echo "❌ Error: cargo-cyclonedx is not installed"
        echo "Please install it with: cargo install cargo-cyclonedx"
        return 1
    fi
    echo "✅ cargo-cyclonedx found"
    return 0
}

# Function to verify Cargo.toml exists
check_cargo_toml() {
    if [ ! -f "Cargo.toml" ]; then
        echo "❌ Error: Cargo.toml not found in current directory"
        pwd
        return 1
    fi
    echo "✅ Cargo.toml found"
    return 0
}

# Function to generate SBOM files
generate_sbom() {
    local FORMAT="$1"

    echo "📦 Generating SBOM in $FORMAT format..."

    if cargo cyclonedx --format "$FORMAT" --override-filename "rsdo-sbom"; then
        local FILENAME="rsdo-sbom.$FORMAT"
        if [ -f "$FILENAME" ]; then
            echo "✅ Successfully generated $FILENAME ($(stat -f%z "$FILENAME" 2>/dev/null || stat -c%s "$FILENAME" 2>/dev/null) bytes)"
            return 0
        else
            echo "❌ Error: $FILENAME was not created"
            return 1
        fi
    else
        echo "❌ Error: cargo cyclonedx failed for format: $FORMAT"
        return 1
    fi
}

# Function to generate both JSON and XML SBOM files
generate_all_sbom() {
    local SUCCESS=0

    if generate_sbom "json"; then
        echo "✅ JSON SBOM generated successfully"
    else
        echo "⚠️  JSON SBOM generation failed"
        SUCCESS=1
    fi

    if generate_sbom "xml"; then
        echo "✅ XML SBOM generated successfully"
    else
        echo "⚠️  XML SBOM generation failed"
        SUCCESS=1
    fi

    return $SUCCESS
}

# Main function
main() {
    local FORMAT="${1:-all}"

    echo "🔍 SBOM Generation Script"
    echo "========================"

    # Pre-flight checks
    check_cyclonedx || exit 1
    check_cargo_toml || exit 1

    echo ""
    echo "Starting SBOM generation..."
    echo ""

    if [ "$FORMAT" = "all" ]; then
        generate_all_sbom
    else
        generate_sbom "$FORMAT"
    fi

    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo "✅ SBOM generation completed successfully"
    else
        echo ""
        echo "❌ SBOM generation failed with exit code: $EXIT_CODE"
    fi

    return $EXIT_CODE
}

main "$@"