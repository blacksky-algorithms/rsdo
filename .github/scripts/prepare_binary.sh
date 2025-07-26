#!/bin/bash
set -euxo pipefail

# Function to prepare binary for upload
prepare_binary() {
    local TARGET="$1"
    local ARTIFACT_NAME="$2"
    
    # Verify binary exists and is executable
    BINARY_PATH="target/${TARGET}/release/${ARTIFACT_NAME}"
    if [ ! -f "$BINARY_PATH" ]; then
        echo "❌ Binary not found at $BINARY_PATH"
        exit 1
    fi
    
    # Get binary size for logging
    BINARY_SIZE=$(stat -c%s "$BINARY_PATH" 2>/dev/null || stat -f%z "$BINARY_PATH" 2>/dev/null || echo "unknown")
    echo "📦 Binary ready: $BINARY_PATH (${BINARY_SIZE} bytes)"
}

# Main function
main() {
    local TARGET="$1"
    local ARTIFACT_NAME="$2"
    
    prepare_binary "$TARGET" "$ARTIFACT_NAME"
}

main "$@"