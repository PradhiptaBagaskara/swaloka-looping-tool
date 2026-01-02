#!/usr/bin/env dart

import 'dart:io';

/// Sets up git pre-commit hooks for the project.
/// Run with: dart run tool/setup_hooks.dart
void main() {
  final hookDir = Directory('.git/hooks');
  if (!hookDir.existsSync()) {
    stdout.writeln('❌ Not a git repository. Run "git init" first.');
    exit(1);
  }

  const hookScript = r'''
#!/bin/sh
# Auto-generated pre-commit hook

echo "🔍 Running pre-commit checks..."

# Auto-fix issues
echo "🔧 Running dart fix --apply..."
dart fix --apply
if [ $? -ne 0 ]; then
  echo "⚠️  dart fix encountered issues (continuing anyway)"
fi

# Format code
echo "📝 Formatting code..."
dart format .
if [ $? -ne 0 ]; then
  echo "❌ Formatting failed."
  exit 1
fi

# Analyze with Flutter (more comprehensive for Flutter projects)
echo "🔬 Analyzing code..."
flutter analyze
if [ $? -ne 0 ]; then
  echo "❌ Analysis issues found. Fix them before committing."
  exit 1
fi

# Stage any auto-fixed/formatted changes
git add -u

echo "✅ All checks passed!"
''';

  final preCommitHook = File('.git/hooks/pre-commit')
    ..writeAsStringSync(hookScript);

  // Make executable
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['+x', preCommitHook.path]);
  }

  stdout
    ..writeln('✅ Git hooks installed successfully!')
    ..writeln('   Pre-commit will now run:')
    ..writeln('   1. dart fix --apply')
    ..writeln('   2. dart format .')
    ..writeln('   3. flutter analyze');
}
