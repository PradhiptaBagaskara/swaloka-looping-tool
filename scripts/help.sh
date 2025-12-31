#!/bin/bash
# Quick reference for version commands

cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║       Swaloka Looping Tool - Version Management CLI          ║
╚══════════════════════════════════════════════════════════════╝

🚀 QUICK RELEASE (Recommended)
  ./scripts/release.sh
  → Auto-detects, bumps, commits, tags, and pushes

📦 VERSION BUMP
  ./scripts/bump_version.sh auto       # Auto-detect from commits
  ./scripts/bump_version.sh major      # Breaking changes (2.0.0)
  ./scripts/bump_version.sh minor      # New features (1.1.0)
  ./scripts/bump_version.sh patch      # Bug fixes (1.0.1)

📝 COMMIT CONVENTIONS
  feat:      New feature         → MINOR bump
  feat!:     Breaking feature    → MAJOR bump
  fix:       Bug fix            → PATCH bump
  refactor:  Code refactor       → PATCH bump
  docs:      Documentation       → PATCH bump
  chore:     Maintenance         → PATCH bump

📖 DOCUMENTATION
  VERSIONING.md              # Complete guide
  scripts/README.md          # Script details
  COMMIT_CONVENTION.md       # Commit guidelines
  AUTOMATION_SETUP_SUMMARY.md # Setup summary

🔍 USEFUL GIT COMMANDS
  git log --oneline          # View commit history
  git tag                    # List all tags
  git describe --tags        # Show current tag
  git log v1.0.0..HEAD       # Commits since v1.0.0

🏷️  PUSH TAGS
  git push origin main       # Push commits
  git push origin v1.0.0     # Push specific tag
  git push --tags            # Push all tags

🌐 GITHUB
  Releases: https://github.com/pradhiptabagaskara/swaloka-looping-tool/releases
  Actions:  https://github.com/pradhiptabagaskara/swaloka-looping-tool/actions

💡 EXAMPLES
  # Quick workflow
  git commit -m "feat: add dark mode"
  ./scripts/release.sh

  # Manual workflow
  git commit -m "fix: resolve memory leak"
  ./scripts/bump_version.sh auto
  git push origin main && git push --tags

╔══════════════════════════════════════════════════════════════╗
║  Run this script anytime: ./scripts/help.sh                  ║
╚══════════════════════════════════════════════════════════════╝
EOF
