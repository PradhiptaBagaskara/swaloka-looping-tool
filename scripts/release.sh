#!/bin/bash

# Quick Release Script
# Usage: ./scripts/release.sh

set -e

echo "🚀 Swaloka Looping Tool - Quick Release"
echo ""

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo "⚠️  You have uncommitted changes:"
    git status -s
    echo ""
    read -p "Commit changes first? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enter commit message (use conventional commit format):"
        read -r COMMIT_MSG
        git add .
        git commit -m "$COMMIT_MSG"
        echo "✅ Changes committed"
        echo ""
    else
        echo "❌ Please commit or stash your changes first"
        exit 1
    fi
fi

# Run version bump
echo "🔍 Detecting version bump..."
./scripts/bump_version.sh auto

# Ask if user wants to push
echo ""
read -p "Push to GitHub and trigger release? [y/N]: " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "ℹ️  Changes committed and tagged locally"
    echo "   Run 'git push origin main && git push --tags' to publish"
    exit 0
fi

# Get the latest tag
LATEST_TAG=$(git describe --tags --abbrev=0)

# Push to GitHub
echo "📤 Pushing to GitHub..."
git push origin main
git push origin "$LATEST_TAG"

echo ""
echo "✅ Release published!"
echo "🔗 https://github.com/pradhiptabagaskara/swaloka-looping-tool/releases/tag/$LATEST_TAG"
echo ""
echo "📝 Next steps:"
echo "   1. GitHub Actions will build macOS and Windows apps"
echo "   2. Check the release page in ~10 minutes for downloads"
