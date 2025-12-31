#!/bin/bash

# Automated Semantic Versioning Script
# Bumps version based on commit messages following Conventional Commits
# Usage: ./scripts/bump_version.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current version from pubspec.yaml
PUBSPEC_FILE="pubspec.yaml"
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | sed 's/+.*//')
CURRENT_BUILD=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/.*+//')

echo -e "${BLUE}📦 Current version: ${CURRENT_VERSION}+${CURRENT_BUILD}${NC}"

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Function to detect bump type from commits
detect_bump_type() {
    # Get commits since last tag
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [ -z "$LAST_TAG" ]; then
        # No tags yet, check all commits
        COMMITS=$(git log --pretty=format:"%s" HEAD)
    else
        # Get commits since last tag
        COMMITS=$(git log --pretty=format:"%s" "$LAST_TAG"..HEAD)
    fi

    # Check if only docs/test commits exist (skip version bump)
    if echo "$COMMITS" | grep -qvE "^(docs|test)(\(.+\))?:"; then
        # Has non-docs/test commits, continue with version detection
        :
    else
        # Only docs/test commits, skip version bump
        echo "skip"
        return
    fi

    # Check for breaking changes (MAJOR)
    if echo "$COMMITS" | grep -qE "^(feat|fix|refactor|perf|build|ci|chore)(\(.+\))?!:|BREAKING CHANGE:"; then
        echo "major"
        return
    fi

    # Check for features (MINOR)
    if echo "$COMMITS" | grep -qE "^feat(\(.+\))?:"; then
        echo "minor"
        return
    fi

    # Check for fixes or other changes (PATCH)
    if echo "$COMMITS" | grep -qE "^(fix|refactor|perf|build|ci|chore|style)(\(.+\))?:"; then
        echo "patch"
        return
    fi

    # Default to skip if only docs/test
    echo "skip"
}

# Determine bump type (always auto-detect)
BUMP_TYPE=$(detect_bump_type)

if [ "$BUMP_TYPE" = "skip" ]; then
    echo -e "${YELLOW}⏭️  Only docs/test changes detected - skipping version bump${NC}"
    echo -e "${BLUE}ℹ️  No version bump needed for documentation or test-only changes${NC}"
    exit 0
fi

echo -e "${YELLOW}🔍 Auto-detected bump type: ${BUMP_TYPE}${NC}"

# Bump version based on type
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        echo -e "${GREEN}⬆️  MAJOR version bump (breaking changes)${NC}"
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        echo -e "${GREEN}⬆️  MINOR version bump (new features)${NC}"
        ;;
    patch)
        PATCH=$((PATCH + 1))
        echo -e "${GREEN}⬆️  PATCH version bump (bug fixes)${NC}"
        ;;
    *)
        echo -e "${RED}❌ Invalid bump type: $BUMP_TYPE${NC}"
        echo "Usage: $0 [major|minor|patch|auto]"
        exit 1
        ;;
esac

# Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_VERSION_FULL="${NEW_VERSION}+${NEW_BUILD}"

echo -e "${BLUE}📦 New version: ${NEW_VERSION_FULL}${NC}"

# Update pubspec.yaml
echo -e "${BLUE}📝 Updating pubspec.yaml...${NC}"
sed -i.bak "s/^version: .*/version: ${NEW_VERSION_FULL}/" "$PUBSPEC_FILE"
rm "${PUBSPEC_FILE}.bak"

# Update CHANGELOG.md
echo -e "${BLUE}📝 Updating CHANGELOG.md...${NC}"
TODAY=$(date +%Y-%m-%d)

# Get commits for changelog
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
    COMMITS_LOG=$(git log --pretty=format:"- %s (%h)" HEAD)
else
    COMMITS_LOG=$(git log --pretty=format:"- %s (%h)" "$LAST_TAG"..HEAD)
fi

# Create temp file with new version entry
cat > /tmp/changelog_entry.md << EOF

## [${NEW_VERSION}] - ${TODAY}

### Changes
${COMMITS_LOG}

EOF

# Insert after "## [Unreleased]" line
if grep -q "## \[Unreleased\]" CHANGELOG.md; then
    # Insert after [Unreleased] section
    awk '/## \[Unreleased\]/{print; print ""; getline; print; while(getline && !/^## \[/){print}; system("cat /tmp/changelog_entry.md"); print; next}1' CHANGELOG.md > /tmp/changelog_new.md
    mv /tmp/changelog_new.md CHANGELOG.md
else
    # If no [Unreleased] section, insert at top
    cat /tmp/changelog_entry.md CHANGELOG.md > /tmp/changelog_new.md
    mv /tmp/changelog_new.md CHANGELOG.md
fi

rm /tmp/changelog_entry.md

# Commit changes
echo -e "${BLUE}📝 Committing version bump...${NC}"
git add "$PUBSPEC_FILE" CHANGELOG.md
git commit -m "chore: bump version to ${NEW_VERSION}"

# Create git tag
echo -e "${BLUE}🏷️  Creating git tag v${NEW_VERSION}...${NC}"
git tag -a "v${NEW_VERSION}" -m "Release version ${NEW_VERSION}"

echo -e "${GREEN}✅ Version bumped successfully!${NC}"
echo -e "${BLUE}📦 Version: ${NEW_VERSION_FULL}${NC}"
echo -e "${BLUE}🏷️  Tag: v${NEW_VERSION}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review changes: ${BLUE}git log -1${NC}"
echo -e "  2. Push commits: ${BLUE}git push origin main${NC}"
echo -e "  3. Push tag: ${BLUE}git push origin v${NEW_VERSION}${NC}"
echo -e "  4. Create GitHub release at: https://github.com/pradhiptabagaskara/swaloka-looping-tool/releases/new?tag=v${NEW_VERSION}"
