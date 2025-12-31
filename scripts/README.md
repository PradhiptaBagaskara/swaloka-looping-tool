# Automated Semantic Versioning

This directory contains scripts for automated version bumping based on [Conventional Commits](https://www.conventionalcommits.org/).

## 🚀 Quick Start

### Version Bump Script
```bash
# Make executable
chmod +x scripts/bump_version.sh

# Auto-detect version bump from commits
./scripts/bump_version.sh auto

# Manual bump
./scripts/bump_version.sh major  # Breaking changes
./scripts/bump_version.sh minor  # New features
./scripts/bump_version.sh patch  # Bug fixes
```

## 📝 Conventional Commits Format

The scripts automatically detect version bumps based on commit message patterns:

### MAJOR (Breaking Changes)
```bash
git commit -m "feat!: redesign entire UI"
git commit -m "fix!: change API interface"
git commit -m "feat: add new feature

BREAKING CHANGE: removes old authentication method"
```

### MINOR (New Features)
```bash
git commit -m "feat: add dark mode support"
git commit -m "feat(audio): add crossfade transitions"
```

### PATCH (Bug Fixes & Minor Changes)
```bash
git commit -m "fix: resolve memory leak"
git commit -m "refactor: improve logging performance"
git commit -m "perf: optimize video processing"
git commit -m "chore: update dependencies"
git commit -m "style: format code"
```

### SKIP (Documentation & Tests Only)
```bash
git commit -m "docs: update README"
git commit -m "test: add unit tests"
```

**Note:** If all commits since the last tag are only `docs:` or `test:`, the version bump will be skipped automatically.

## 🎯 Commit Message Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat:` | New feature | MINOR |
| `feat!:` | Breaking feature | MAJOR |
| `fix:` | Bug fix | PATCH |
| `fix!:` | Breaking fix | MAJOR |
| `refactor:` | Code refactoring | PATCH |
| `perf:` | Performance improvement | PATCH |
| `docs:` | Documentation only | **SKIP** |
| `style:` | Code style changes | PATCH |
| `test:` | Adding/updating tests | **SKIP** |
| `chore:` | Maintenance tasks | PATCH |
| `build:` | Build system changes | PATCH |
| `ci:` | CI configuration | PATCH |

## 🔄 What the Scripts Do

1. **Detect Version Bump**
   - Analyzes commits since last tag
   - Determines bump type (major/minor/patch)
   - Shows detected changes

2. **Update Files**
   - `pubspec.yaml` - Updates version and build number
   - `CHANGELOG.md` - Adds new version entry with commits

3. **Git Operations**
   - Creates commit: `chore: bump version to X.Y.Z`
   - Creates annotated tag: `vX.Y.Z`
   - Shows next steps for pushing

4. **Confirmation**
   - Always asks for confirmation before making changes
   - Shows preview of new version

## 📋 Example Workflow

```bash
# 1. Make your changes and commit with conventional commits
git add .
git commit -m "feat: add audio crossfade support"
git commit -m "fix: resolve processing deadlock"

# 2. Run version bump (auto-detects MINOR from 'feat:')
./scripts/bump_version.sh auto

# Output:
# 📦 Current version: 1.0.0+1
# 🔍 Auto-detected bump type: minor
# ⬆️  MINOR version bump (new features)
# 📦 New version: 1.1.0+2
# Continue with version bump? [y/N]: y
# ✅ Version bumped successfully!

# 3. Push changes and tag
git push origin main
git push origin v1.1.0

# 4. Create GitHub release
# Visit: https://github.com/pradhiptabagaskara/swaloka-looping-tool/releases/new?tag=v1.1.0
```

## 🎨 Features

### Auto-Detection
- Scans all commits since last tag
- Uses Conventional Commits specification
- Defaults to PATCH if no pattern matches

### Smart Updates
- Increments build number automatically
- Updates CHANGELOG.md with commit list
- Preserves [Unreleased] section

### Safe Operations
- Always asks for confirmation
- Shows preview before changes
- Validates version format

## 🛠️ Manual Version Bumping

If you need to bypass auto-detection:

```bash
# Force specific bump type
./scripts/bump_version.sh major  # 1.0.0 → 2.0.0
./scripts/bump_version.sh minor  # 1.0.0 → 1.1.0
./scripts/bump_version.sh patch  # 1.0.0 → 1.0.1
```

## 📖 Semantic Versioning Rules

Given a version number `MAJOR.MINOR.PATCH` (e.g., `1.2.3`):

- **MAJOR** (1.x.x): Breaking changes, incompatible API changes
- **MINOR** (x.2.x): New features, backward-compatible
- **PATCH** (x.x.3): Bug fixes, backward-compatible

Build number (`+4`) increments with every version change.

## ⚙️ Configuration

### Customize Commit Patterns

Edit the regex patterns in the scripts:

**Bash (`bump_version.sh`):**
```bash
# Line 41-44: Breaking changes
if echo "$COMMITS" | grep -qE "^(feat|fix)!:|BREAKING CHANGE:"; then

# Line 49-51: Features
if echo "$COMMITS" | grep -qE "^feat(\(.+\))?:"; then
```

**Python (`bump_version.py`):**
```python
# Line 58-64: Breaking changes
breaking_pattern = re.compile(r"^(feat|fix)(\(.+\))?!:|BREAKING CHANGE:")

# Line 67-71: Features
feat_pattern = re.compile(r"^feat(\(.+\))?:")
```

## 🐛 Troubleshooting

### "No tags found"
First time running? The script will analyze all commits.

### "Could not parse version"
Ensure `pubspec.yaml` has: `version: 1.0.0+1`

### Changes not detected
Make sure commits follow Conventional Commits format.

### Need to undo version bump
```bash
# Undo last commit and tag
git reset --hard HEAD~1
git tag -d v1.2.3
```

## 📚 Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)

## 💡 Tips

1. **Always use conventional commits** for automatic detection
2. **Run the script before pushing** to create clean releases
3. **Review CHANGELOG.md** after bumping to ensure accuracy
4. **Create GitHub releases** after pushing tags for better visibility

---

**Made with ❤️ for Swaloka Looping Tool**
