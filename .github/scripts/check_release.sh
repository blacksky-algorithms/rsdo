#!/bin/bash
set -euxo pipefail

# Function to check if should create release
check_release() {
    local TAG_NAME="$1"
    local FORCE="$2"
    local TRIGGER_TYPE="$3"
    
    echo "Trigger type: ${TRIGGER_TYPE}"
    
    # Check if tag already exists
    local SHOULD_RELEASE
    if git tag -l | grep -q "^${TAG_NAME}$"; then
        if [ "$FORCE" = "true" ]; then
            echo "Tag ${TAG_NAME} exists but force=true, proceeding with release"
            SHOULD_RELEASE=true
        elif [ "$TRIGGER_TYPE" = "schedule" ]; then
            echo "Tag ${TAG_NAME} exists but this is a scheduled run, skipping to avoid duplicate monthly releases"
            SHOULD_RELEASE=false
        else
            echo "Tag ${TAG_NAME} already exists and force=false. Skipping release."
            SHOULD_RELEASE=false
        fi
    else
        echo "Tag ${TAG_NAME} does not exist, proceeding with release"
        SHOULD_RELEASE=true
    fi

    echo "should_release=${SHOULD_RELEASE}" >> $GITHUB_OUTPUT

    # Log the decision. This reads the local variable rather than grepping
    # $GITHUB_OUTPUT: that file accumulates the outputs of every step in the job,
    # so a "should_release=true" written by an earlier run/step made this report
    # the opposite of the decision actually taken.
    if [ "$SHOULD_RELEASE" = "true" ]; then
        echo "✅ Will create release for ${TAG_NAME}"
        if [ "$TRIGGER_TYPE" = "schedule" ]; then
            echo "📅 Scheduled monthly release"
        elif [ "$TRIGGER_TYPE" = "workflow_dispatch" ]; then
            echo "🔧 Manual release trigger"
        elif [ "$TRIGGER_TYPE" = "push" ]; then
            echo "🚀 Automatic release on push to main"
        fi
    else
        echo "⏭️ Skipping release creation"
    fi
}

# Main function
main() {
    local TAG_NAME="$1"
    local FORCE="$2"
    local TRIGGER_TYPE="$3"
    
    check_release "$TAG_NAME" "$FORCE" "$TRIGGER_TYPE"
}

main "$@"