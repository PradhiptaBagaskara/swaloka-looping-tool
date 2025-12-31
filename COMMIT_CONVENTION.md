# Git Commit Message Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/) specification for clear and semantic commit messages.

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Types

### Primary Types (Trigger Version Bumps)

- **feat**: A new feature (→ MINOR version bump)
  ```bash
  git commit -m "feat: add audio crossfade transitions"
  git commit -m "feat(ui): add dark mode toggle"
  ```

- **fix**: A bug fix (→ PATCH version bump)
  ```bash
  git commit -m "fix: resolve memory leak in video processing"
  git commit -m "fix(audio): correct looping order"
  ```

- **feat!** or **fix!**: Breaking changes (→ MAJOR version bump)
  ```bash
  git commit -m "feat!: redesign project structure"
  git commit -m "fix!: change API interface"
  ```

### Supporting Types (PATCH version bump)

- **docs**: Documentation changes only
  ```bash
  git commit -m "docs: update README with installation steps"
  ```

- **style**: Code style changes (formatting, missing semicolons, etc.)
  ```bash
  git commit -m "style: format code with dartfmt"
  ```

- **refactor**: Code refactoring without changing functionality
  ```bash
  git commit -m "refactor: extract widget into separate file"
  ```

- **perf**: Performance improvements
  ```bash
  git commit -m "perf: optimize FFmpeg command generation"
  ```

- **test**: Adding or updating tests
  ```bash
  git commit -m "test: add unit tests for LogEntry"
  ```

- **chore**: Maintenance tasks, dependency updates
  ```bash
  git commit -m "chore: update dependencies"
  git commit -m "chore: bump version to 1.2.0"
  ```

- **build**: Build system or external dependency changes
  ```bash
  git commit -m "build: update Flutter SDK to 3.24"
  ```

- **ci**: CI/CD configuration changes
  ```bash
  git commit -m "ci: add automated release workflow"
  ```

## Scopes (Optional)

Scopes provide additional context about what part of the codebase changed:

```bash
git commit -m "feat(audio): add shuffle mode"
git commit -m "fix(ui): resolve layout issue on small screens"
git commit -m "refactor(logging): improve log hierarchy"
git commit -m "docs(readme): add troubleshooting section"
```

Common scopes for this project:
- `audio` - Audio processing features
- `video` - Video processing features
- `ui` - User interface changes
- `logging` - Logging system
- `ffmpeg` - FFmpeg integration
- `project` - Project management features

## Breaking Changes

Breaking changes MUST be indicated by `!` after type/scope or in footer:

### Method 1: Exclamation mark
```bash
git commit -m "feat!: remove legacy audio processor"
git commit -m "refactor(api)!: change service interface"
```

### Method 2: Footer
```bash
git commit -m "feat: redesign logging system

BREAKING CHANGE: LogEntry constructor signature changed"
```

## Examples

### New Feature
```bash
git commit -m "feat: add real-time preview during processing"
```

### Bug Fix
```bash
git commit -m "fix: resolve FFmpeg command deadlock

Previously the stream handling caused the app to hang.
This fix properly handles async streams."
```

### Breaking Change
```bash
git commit -m "feat!: change temp directory to project-specific location

BREAKING CHANGE: Temp files now stored in project/temp instead of system temp.
Existing projects need to clean up old system temp files manually."
```

### Documentation
```bash
git commit -m "docs: add semantic versioning guide"
```

### Refactoring
```bash
git commit -m "refactor(state): extract notifiers into separate files"
```

### Multiple Changes
If you have multiple unrelated changes, make separate commits:

```bash
# Separate commits
git add lib/features/audio/
git commit -m "feat(audio): add crossfade support"

git add docs/
git commit -m "docs: update audio processing guide"
```

## Version Bump Rules

Our automated versioning script (`scripts/bump_version.sh`) uses these rules:

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat!:`, `BREAKING CHANGE:` | MAJOR (1.0.0 → 2.0.0) | Breaking API changes |
| `feat:` | MINOR (1.0.0 → 1.1.0) | New features |
| `fix:`, `refactor:`, `perf:`, `chore:`, `build:`, `ci:`, `style:` | PATCH (1.0.0 → 1.0.1) | Bug fixes, improvements |
| `docs:`, `test:` only | **SKIP** (no bump) | Documentation or tests only |

**Note:** If all commits since the last tag are only `docs:` or `test:`, the version bump will be **skipped automatically**.

## Tips

1. **Keep the subject line short** (≤ 72 characters)
2. **Use imperative mood** ("add" not "added" or "adds")
3. **Capitalize the first letter**
4. **No period at the end of subject line**
5. **Separate subject from body with blank line**
6. **Use body to explain what and why, not how**

## Good vs Bad Examples

### ✅ Good
```bash
git commit -m "feat: add audio loop count setting"
git commit -m "fix: resolve processing deadlock in FFmpeg streams"
git commit -m "docs: improve README installation section"
git commit -m "refactor: extract ProjectConfig into separate file"
```

### ❌ Bad
```bash
git commit -m "updated stuff"
git commit -m "Fixed bug"
git commit -m "audio feature"
git commit -m "WIP"
```

## Automated Tools

This project includes automation scripts that rely on conventional commits:

- **`scripts/bump_version.sh`** - Auto-detects version bump from commits
- **`.github/workflows/release.yml`** - Creates releases from tags
- **`CHANGELOG.md`** - Auto-updated with commit messages

Following this convention ensures the automation works correctly!

## Resources

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [How to Write a Git Commit Message](https://chris.beams.io/posts/git-commit/)

---

**Remember**: Good commit messages help you and others understand the project history!
