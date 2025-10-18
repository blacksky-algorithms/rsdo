#!/bin/bash
set -euxo pipefail

# Function to commit version changes and create tag
commit_and_tag() {
    local TAG_NAME="$1"
    local VERSION="$2"
    local TRIGGER_TYPE="$3"
    
    # Create appropriate commit message based on trigger
    if [ "$TRIGGER_TYPE" = "schedule" ]; then
        COMMIT_MSG="chore: monthly release v${VERSION}"
        TAG_MSG="Monthly release ${TAG_NAME}"
    elif [ "$TRIGGER_TYPE" = "workflow_dispatch" ]; then
        COMMIT_MSG="chore: manual release v${VERSION}"
        TAG_MSG="Manual release ${TAG_NAME}"
    else
        COMMIT_MSG="chore: release v${VERSION}"
        TAG_MSG="Release ${TAG_NAME}"
    fi
    
    # Commit version changes (allow empty commit if nothing changed)
    git add Cargo.toml Cargo.lock
    git diff --cached --quiet || git commit -m "${COMMIT_MSG}"
    
    # Delete existing tag if it exists (for force mode)
    if git tag -l | grep -q "^${TAG_NAME}$"; then
        echo "Deleting existing tag ${TAG_NAME}"
        git tag -d "${TAG_NAME}"
        # Delete remote tag, ignore if it doesn't exist
        git push origin ":refs/tags/${TAG_NAME}" 2>/dev/null || echo "Remote tag ${TAG_NAME} doesn't exist or already deleted"
    fi
    
    # Create new tag
    git tag -a "${TAG_NAME}" -m "${TAG_MSG}"
    
    # Push changes and tag with error handling
    echo "Pushing commit to main branch..."
    git push origin main
    
    echo "Pushing tag ${TAG_NAME}..."
    git push origin "${TAG_NAME}"
    
    echo "✅ Successfully pushed commit and tag"
}

# Main function
main() {
    local TAG_NAME="$1"
    local VERSION="$2"
    local TRIGGER_TYPE="$3"
    
    commit_and_tag "$TAG_NAME" "$VERSION" "$TRIGGER_TYPE"
}

main "$@"