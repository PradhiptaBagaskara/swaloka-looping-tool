#!/usr/bin/env dart

// ignore_for_file: avoid_print
import 'dart:io';

/// Sets up git pre-commit hooks for the project.
/// Run with: dart run tool/setup_hooks.dart
void main() {
  final hookDir = Directory('.git/hooks');
  if (!hookDir.existsSync()) {
    print('❌ Not a git repository. Run "git init" first.');
    exit(1);
  }

  final preCommitHook = File('.git/hooks/pre-commit');
  preCommitHook.writeAsStringSync('''#!/bin/sh
# Auto-generated pre-commit hook

echo "🔍 Running pre-commit checks..."

# Format check
echo "📝 Checking formatting..."
dart format --set-exit-if-changed .
if [ \$? -ne 0 ]; then
  echo "❌ Formatting issues found. Run 'dart format .' to fix."
  exit 1
fi

# Analyze
echo "🔬 Analyzing code..."
dart analyze --fatal-infos
if [ \$? -ne 0 ]; then
  echo "❌ Analysis issues found. Fix them before committing."
  exit 1
fi

echo "✅ All checks passed!"
''');

  // Make executable
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['+x', preCommitHook.path]);
  }

  print('✅ Git hooks installed successfully!');
  print('   Pre-commit will now run: dart format & dart analyze');
}
