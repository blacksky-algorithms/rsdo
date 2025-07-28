#!/bin/bash
set -euxo pipefail

# Function to generate date-based version and tag
generate_version() {
    # Generate date-based version (0.1.YYYYMMDD)
    YEAR=$(date +'%Y')
    MONTH=$(date +'%m')   # %m keeps leading zero (01-12)
    DAY=$(date +'%d')     # %d keeps leading zero (01-31)
    DATE_PATCH="${YEAR}${MONTH}${DAY}"
    DATE_VERSION="0.1.${DATE_PATCH}"
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