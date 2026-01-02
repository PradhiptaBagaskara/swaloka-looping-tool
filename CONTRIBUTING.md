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

This project uses [Release Please](https://github.com/googleapis/release-please) for automated releases:

1. You submit a PR with conventional commits
2. Maintainer merges your PR to `main`
3. Release Please automatically creates/updates a Release PR
4. When maintainer merges the Release PR:
   - Version is bumped automatically
   - CHANGELOG is updated
   - Builds run (macOS, Windows, Linux)
   - Release is published

**You don't need to worry about versioning** - just write good commit messages!

---

## Pull Request Guidelines

- Keep PRs focused on a single change
- Update documentation if needed
- Ensure all tests pass
- Follow the commit message convention
- Be responsive to review feedback

---

## Questions?

Feel free to open an issue if you have questions or need help!

---

Thank you for contributing! 🎉
