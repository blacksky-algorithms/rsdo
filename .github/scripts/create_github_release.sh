#!/bin/bash
set -euxo pipefail

# Function to create GitHub release
create_github_release() {
    local TAG_NAME="$1"
    local VERSION="$2"
    local TRIGGER_TYPE="$3"
    local CHANGELOG="$4"
    local USE_AUTO_NOTES="$5"
    
    # Determine release title based on trigger
    if [ "$TRIGGER_TYPE" = "schedule" ]; then
        RELEASE_TITLE="📅 Monthly Release ${TAG_NAME}"
    elif [ "$TRIGGER_TYPE" = "workflow_dispatch" ]; then
        RELEASE_TITLE="🔧 Manual Release ${TAG_NAME}"
    else
        RELEASE_TITLE="🚀 Release ${TAG_NAME}"
    fi
    
    # Check if we should use auto-generated notes or custom changelog
    if [ "$USE_AUTO_NOTES" = "true" ]; then
        echo "Creating release with auto-generated notes..."
        gh release create "${TAG_NAME}" \
            --title "${RELEASE_TITLE}" \
            --generate-notes \
            --latest
    else
        echo "Creating release with custom changelog..."
        # Save changelog to temporary file
        echo "$CHANGELOG" > /tmp/changelog.md
        
        gh release create "${TAG_NAME}" \
            --title "${RELEASE_TITLE}" \
            --notes-file /tmp/changelog.md \
            --latest
    fi
    
    echo "✅ Created GitHub release: ${TAG_NAME}"
}

# Main function
main() {
    local TAG_NAME="$1"
    local VERSION="$2"
    local TRIGGER_TYPE="$3"
    local CHANGELOG="$4"
    local USE_AUTO_NOTES="${5:-false}"
    
    create_github_release "$TAG_NAME" "$VERSION" "$TRIGGER_TYPE" "$CHANGELOG" "$USE_AUTO_NOTES"
}

main "$@"