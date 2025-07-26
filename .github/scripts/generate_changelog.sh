#!/bin/bash
set -euxo pipefail

# Function to generate changelog content using script
generate_changelog() {
    local VERSION="$1"
    local TAG_NAME="$2"
    local TRIGGER_TYPE="$3"
    local REPOSITORY="$4"
    
    # Make changelog script executable
    chmod +x .github/scripts/changelog.sh
    
    # Generate changelog content using script
    CHANGELOG=$(.github/scripts/changelog.sh \
        "$VERSION" \
        "$TAG_NAME" \
        "$TRIGGER_TYPE" \
        "$REPOSITORY")
    
    # Output for GitHub Actions (handle multiline)
    echo "CHANGELOG<<EOF" >> $GITHUB_OUTPUT
    echo "$CHANGELOG" >> $GITHUB_OUTPUT
    echo "EOF" >> $GITHUB_OUTPUT
    
    echo "Generated changelog for $TAG_NAME"
}

# Main function
main() {
    local VERSION="$1"
    local TAG_NAME="$2"
    local TRIGGER_TYPE="$3"
    local REPOSITORY="$4"
    
    generate_changelog "$VERSION" "$TAG_NAME" "$TRIGGER_TYPE" "$REPOSITORY"
}

main "$@"