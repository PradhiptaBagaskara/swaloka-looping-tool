# Contributing to Swaloka Looping Tool

Thank you for your interest in contributing! This guide will help you get started.

## How to Contribute

### 1. Fork & Clone

```bash
# Fork the repo on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/swaloka-looping-tool.git
cd swaloka-looping-tool
```

### 2. Create a Branch

```bash
git checkout -b feat/your-feature-name
# or
git checkout -b fix/issue-description
```

### 3. Make Your Changes

- Write clean, readable code
- Follow existing code style
- Add tests if applicable

### 4. Commit Your Changes

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```bash
git commit -m "feat: add your feature description"
```

### 5. Push & Create Pull Request

```bash
git push origin feat/your-feature-name
```

Then open a Pull Request on GitHub.

---

## Development Setup

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) (stable channel)
- [FFmpeg](https://ffmpeg.org/) installed on your system

### Install Dependencies

```bash
flutter pub get
```

### Setup Git Hooks

This installs a pre-commit hook that automatically runs before each commit:

1. `dart fix --apply` - Auto-fix lint issues
2. `dart format .` - Format code
3. `flutter analyze` - Check for remaining issues

```bash
dart run tool/setup_hooks.dart
```

### Run the App

```bash
flutter run -d macos   # or windows, linux
```

### Run Tests

```bash
flutter test
```

---

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/) for clear, semantic commit messages that power our automated releases.

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor (1.0.0 → 1.1.0) |
| `fix` | Bug fix | Patch (1.0.0 → 1.0.1) |
| `docs` | Documentation only | None |
| `style` | Code formatting | Patch |
| `refactor` | Code refactoring | Patch |
| `perf` | Performance improvement | Patch |
| `test` | Adding tests | None |
| `chore` | Maintenance tasks | Patch |
| `ci` | CI/CD changes | Patch |
| `build` | Build system changes | Patch |

### Breaking Changes

Add `!` after type for breaking changes (triggers Major bump):

```bash
git commit -m "feat!: redesign project structure"
```

### Examples

```bash
# ✅ Good
git commit -m "feat: add audio crossfade transitions"
git commit -m "fix: resolve memory leak in video processing"
git commit -m "docs: update installation guide"
git commit -m "refactor(ui): extract widget into separate file"

# ❌ Bad
git commit -m "updated stuff"
git commit -m "Fixed bug"
git commit -m "WIP"
```

### Tips

1. Keep subject line short (≤ 72 characters)
2. Use imperative mood ("add" not "added")
3. No period at the end
4. Explain *what* and *why*, not *how*

---

## Code Style

- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Run `dart format .` before committing
- Run `dart analyze` to check for issues

---

## How Releases Work

This project uses [Release Please](https://github.com/googleapis/release-please) with **GitHub Flow** for automated releases:

### Workflow

```
Feature Branch → PR → Review → Merge to main → Release
```

### Step-by-Step

1. **Create a feature branch** with conventional commits
2. **Open a PR** to `main`
   - Automated checks run (linting, tests, build verification)
   - Optional: Add labels to build test artifacts
3. **Code review** and approval
4. **Merge to main**
5. **Release Please** automatically creates/updates a Release PR
6. **Maintainer merges Release PR**:
   - Version is bumped based on commit types
   - CHANGELOG is updated automatically
   - Builds run for all platforms (macOS, Windows, Linux)
   - Release is published to GitHub

**You don't need to worry about versioning** - just write good commit messages!

---

## Testing Your Changes

### Local Testing

```bash
# Run the app locally
flutter run -d macos   # or windows, linux

# Run tests
flutter test
```

### Build PR Artifacts (Optional)

Need to test production builds before merging? Add labels to your PR:

- **`build-pr: all`** - Build all platforms (macOS, Windows, Linux)
- **`build-pr: macos`** - Build macOS only
- **`build-pr: windows`** - Build Windows only
- **`build-pr: linux`** - Build Linux only

The workflow will:
1. ✅ Build production-quality artifacts
2. ✅ Sign executables (ad-hoc for macOS, self-signed for Windows)
3. ✅ Create installers (Windows .exe, Linux AppImage)
4. ✅ Upload artifacts to the PR for testing

**Files generated:**
- macOS: `Swaloka-Looping-Tool-PR{number}-macos.tar.gz`
- Windows: `Swaloka-Looping-Tool-PR{number}-windows-installer.exe`
- Linux: `Swaloka-Looping-Tool-PR{number}-linux-x64.tar.gz` + AppImage

Download artifacts from the workflow run to test on your machine!

---

## Pull Request Guidelines

### Before Submitting

- ✅ Keep PRs focused on a single change
- ✅ Write tests if applicable
- ✅ Update documentation if needed
- ✅ Follow commit message conventions
- ✅ Ensure automated checks pass

### PR Checks

Every PR automatically runs:
- **Linting** - Code style and quality checks
- **Tests** - Automated test suite
- **Build verification** - Ensures the app builds successfully

### Optional Build Testing

For complex changes, consider requesting PR builds:
1. Add a `build-pr:` label to your PR
2. Wait for builds to complete
3. Download and test the artifacts
4. Verify everything works as expected

### Review Process

- Be responsive to review feedback
- Address comments and suggestions
- Maintain a respectful, collaborative tone
- Ask questions if something is unclear

### Merge

Once approved and all checks pass, maintainers will merge your PR!

---

## Questions?

Feel free to open an issue if you have questions or need help!

---

Thank you for contributing! 🎉
