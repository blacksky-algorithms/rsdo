#!/bin/bash
# .github/scripts/changelog.sh
# Generate changelog content for date-based releases

set -euo pipefail

# Parse arguments
TAG_VERSION="$1"
TAG_NAME="$2"
TRIGGER_TYPE="$3"
REPOSITORY="$4"

# Determine release type and icon
case "$TRIGGER_TYPE" in
  "schedule")
    RELEASE_TYPE="Scheduled Monthly Release"
    RELEASE_ICON="📅"
    ;;
  "workflow_dispatch")
    RELEASE_TYPE="Manual Release"
    RELEASE_ICON="🔧"
    ;;
  "push")
    RELEASE_TYPE="Automatic Release"
    RELEASE_ICON="🚀"
    ;;
  *)
    RELEASE_TYPE="Release"
    RELEASE_ICON="🎉"
    ;;
esac

# Function to generate auto changelog
generate_auto_changelog() {
  local current_date=$(date +'%Y-%-m-%-d %H:%M:%S UTC')  # Remove leading zeros
  local short_commit=$(git rev-parse --short HEAD)
  local previous_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo 'main')
  
  cat << EOF
## ${RELEASE_ICON} ${RELEASE_TYPE} ${TAG_NAME}

This is an automated ${RELEASE_TYPE,,} based on the date ${TAG_VERSION}.

### What's Changed
- Latest changes from the main branch as of $(date +'%Y-%-m-%-d')
- Generated automatically from commit ${short_commit}

### Release Details
- **Type**: ${RELEASE_TYPE}
- **Date**: ${current_date}
- **Trigger**: ${TRIGGER_TYPE}
- **Commit**: ${short_commit}

### Links
- **Full Changelog**: https://github.com/${REPOSITORY}/compare/${previous_tag}...${TAG_NAME}
- **Commits**: https://github.com/${REPOSITORY}/commits/${TAG_NAME}
EOF
}

# Function to extract changelog from CHANGELOG.md
extract_existing_changelog() {
  if [ ! -f CHANGELOG.md ]; then
    return 1
  fi
  
  # Try different changelog formats
  local changelog=""
  
  # Format 1: ## [VERSION]
  changelog=$(sed -n "/## \[${TAG_VERSION}\]/,/## \[/p" CHANGELOG.md | sed '$d' 2>/dev/null || echo "")
  
  # Format 2: ## VERSION
  if [ -z "$changelog" ]; then
    changelog=$(sed -n "/## ${TAG_VERSION}/,/## /p" CHANGELOG.md | sed '$d' 2>/dev/null || echo "")
  fi
  
  # Format 3: ## [TAG_NAME]
  if [ -z "$changelog" ]; then
    changelog=$(sed -n "/## \[${TAG_NAME}\]/,/## \[/p" CHANGELOG.md | sed '$d' 2>/dev/null || echo "")
  fi
  
  if [ -n "$changelog" ]; then
    echo "$changelog"
    return 0
  else
    return 1
  fi
}

# Function to enhance existing changelog with release details
enhance_changelog() {
  local existing_changelog="$1"
  local current_date=$(date +'%Y-%-m-%-d %H:%M:%S UTC')  # Remove leading zeros
  local short_commit=$(git rev-parse --short HEAD)
  
  cat << EOF
${existing_changelog}

---

### Release Details
- **Type**: ${RELEASE_TYPE}
- **Date**: ${current_date}
- **Trigger**: ${TRIGGER_TYPE}
- **Commit**: ${short_commit}
EOF
}

# Main logic
main() {
  echo "Generating changelog for ${TAG_NAME} (${TRIGGER_TYPE})" >&2
  
  # Try to extract existing changelog first
  if existing_changelog=$(extract_existing_changelog); then
    echo "Found existing changelog entry, enhancing it..." >&2
    enhance_changelog "$existing_changelog"
  else
    echo "No existing changelog found, generating automatic changelog..." >&2
    generate_auto_changelog
  fi
}

# Run main function and output result
main