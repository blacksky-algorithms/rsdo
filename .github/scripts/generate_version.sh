#!/bin/bash
set -euxo pipefail

# Function to generate date-based version and tag
generate_version() {
    # Generate date-based version (YYYY.M.D) - no leading zeros
    YEAR=$(date +'%Y')
    MONTH=$(date +'%-m')  # %-m removes leading zero
    DAY=$(date +'%-d')    # %-d removes leading zero
    DATE_VERSION="${YEAR}.${MONTH}.${DAY}"
    TAG_NAME="v${DATE_VERSION}"
    
    echo "VERSION=${DATE_VERSION}" >> $GITHUB_OUTPUT
    echo "TAG_NAME=${TAG_NAME}" >> $GITHUB_OUTPUT
    echo "Generated version: ${DATE_VERSION}"
    echo "Tag name: ${TAG_NAME}"
}

# Main function
main() {
    generate_version
}

main "$@"