# Changelog

All notable changes to Swaloka Looping Tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]














### 🎉 Major Features Added

#### Hierarchical Logging System
- **Docker-style expandable logs** - Modern logging system with parent-child relationships
- **Real-time log streaming** - See FFmpeg stdout/stderr as execution happens
- **Structured log hierarchy** - Commands → Execution details → Duration in organized tree view
- **System-level logging integration** - Console output with colors, emojis, and proper indentation
- **Configurable logging** - `LoggerConfig` for controlling console output and minimum log levels
- **Quick logging utility** - `Logger` class for easy system-level logging (`Logger.info()`, `Logger.success()`, etc.)
- **Timestamp precision** - All logs include timestamps with millisecond precision (`HH:MM:SS.mmm`)
- **Smart duration formatting** - Displays execution time in ms, seconds, or minutes based on duration

#### Enhanced FFmpeg Integration
- **Detailed command logging** - Show full FFmpeg commands before execution
- **Execution monitoring** - Real-time stdout/stderr capture as sublogs
- **Duration tracking** - Automatic calculation and display of command execution time
- **Better error handling** - Clear error messages with exit codes and troubleshooting steps

#### Project Structure Improvements
- **Clean architecture refactoring** - Separated concerns into domain, presentation, models, state, and widgets
- **Type-safe state management** - Moved all state classes out of page files into dedicated notifiers
- **Modular widgets** - Extracted reusable widgets into separate files
- **Dedicated providers file** - Centralized Riverpod providers for better organization
- **Model layer separation** - Created proper domain models for `ProjectConfig`, `ProjectFile`, `MediaInfo`

### ✨ Enhanced Features

#### User Experience
- **Smart file picker** - Opens in project directory by default for faster file selection
- **FFmpeg re-check without restart** - Verify FFmpeg installation with button click
- **Detailed troubleshooting** - Step-by-step guide when FFmpeg not found
- **Better error messages** - Clear, actionable error messages throughout the app

#### Audio Processing
- **Improved looping logic** - First loop uses original order, subsequent loops are shuffled
- **Clear documentation** - Added comments explaining audio looping behavior
- **Batch processing logs** - Detailed logging for audio extraction and merging operations

#### File Management
- **Project-specific temp directories** - Changed from system temp to `project_dir/temp/`
- **Automatic cleanup** - Temp files cleaned up after successful processing
- **Prevents disk issues** - Isolated temp files prevent system-wide storage problems
- **Better portability** - Project folders are self-contained

### 🐛 Bug Fixes

#### Critical Fixes
- **Processing deadlock** - Fixed stream handling causing app to hang during FFmpeg execution
- **Race condition in logging** - Resolved log order issues with proper async handling
- **Duration display** - Fixed "0 seconds" showing for quick operations

#### Code Quality
- **Removed code duplication** - Eliminated duplicate `_formatLogEntry` methods
- **Dead code removal** - Removed unused `MediaInfo` class and `_mergeVideoWithAudio` function
- **Linter compliance** - Fixed all linter errors and warnings
- **Type safety** - Improved type hints and nullable handling throughout codebase

### 📝 Documentation

#### README Improvements
- **SEO optimization** - Keywords, meta badges, and search-friendly headings
- **Content creator focus** - Rewrote for non-technical audience
- **Platform-agnostic** - Removed specific platform names (YouTube, Adobe, etc.)
- **Comparison table** - Clear comparison with professional video editors
- **Real use cases** - Added concrete examples (Lo-fi music, podcasts, audiobooks)
- **Comprehensive FAQ** - Detailed answers to common questions
- **Troubleshooting guide** - Step-by-step solutions for common issues
- **Better structure** - Organized sections with clear hierarchy and navigation
- **Quick start guide** - Visual, step-by-step instructions with examples
- **Internal links** - Added navigation links between sections

#### Project Documentation
- **License clarification** - Clear MIT license information
- **Contributing guide** - Instructions for bug reports and feature requests
- **Privacy section** - Explained data handling and security practices

### 🔧 Technical Improvements

#### Code Organization
- **Service layer** - Centralized business logic in service classes
- **State management** - Clean Riverpod provider structure
- **Widget composition** - Reusable, focused widget components
- **Domain models** - Strong typing with dedicated model classes

#### Logging Architecture
```
LogEntry (Mutable)
├── LogLevel enum (info, success, warning, error)
├── Hierarchical sublogs support
├── Dynamic sublog addition (addSubLog, addSubLogs)
├── Formatted timestamps with milliseconds
├── System-level integration (console, file, custom handlers)
└── Color-coded console output with emojis
```

#### Performance
- **Optimized FFmpeg workflows** - Efficient command generation and execution
- **Stream handling** - Non-blocking async stream processing
- **Smart duration display** - Milliseconds for quick ops, readable format for longer ones

### 🗑️ Removed

- **Lazy log loading** - Reverted for better real-time feedback
- **System temp directory usage** - Replaced with project-specific temp
- **Unused code** - Removed `MediaInfo` class, `_mergeVideoWithAudio`, unused parameters
- **Code duplication** - Consolidated duplicate formatting methods
- **Roadmap section** - Removed from README to focus on current features
- **GPU acceleration claim** - Marked as "Coming soon" (not yet implemented)
- **Platform-specific references** - Removed YouTube, Adobe, TikTok, etc. mentions

### 🔄 Changed

#### Breaking Changes
None - All changes are backward compatible

#### Internal Changes
- **Temp directory location** - `system_temp` → `project_dir/temp/`
- **Log entry mutability** - `LogEntry` changed from immutable to mutable for dynamic sublogs
- **FFmpeg check logic** - Now refreshable without app restart via provider invalidation
- **File picker behavior** - Now opens in project directory by default

### 🏗️ Refactoring

#### Before & After Structure

**Before:**
```
lib/features/video_merger/presentation/pages/
└── video_merger_page.dart (2000+ lines)
    ├── ProjectConfig (embedded)
    ├── ProjectFile (embedded)
    ├── MediaInfo (embedded)
    ├── ActiveProjectNotifier (embedded)
    ├── ProjectFilesNotifier (embedded)
    └── Various widgets (embedded)
```

**After:**
```
lib/features/video_merger/
├── domain/
│   ├── models/
│   │   ├── project_config.dart
│   │   ├── project_file.dart
│   │   └── media_info.dart
│   └── video_merger_service.dart
└── presentation/
    ├── pages/
    │   └── video_merger_page.dart (focused, clean)
    ├── state/
    │   ├── active_project_notifier.dart
    │   └── project_files_notifier.dart
    ├── providers/
    │   └── video_merger_providers.dart
    └── widgets/
        ├── project_setup_section.dart
        ├── video_selection_section.dart
        ├── audio_selection_section.dart
        ├── output_configuration_section.dart
        ├── preview_section.dart
        ├── merge_progress_dialog.dart
        ├── log_entry_widget.dart
        └── media_preview_player.dart
```

### 📊 Statistics

- **Lines of code reorganized:** ~2000+ lines refactored
- **New files created:** 15+ (models, state, widgets, providers)
- **Linter errors fixed:** 20+
- **Documentation improvements:** 5x more comprehensive
- **Code duplication eliminated:** 3 instances
- **Dead code removed:** 2 classes, 1 function, multiple unused parameters

---

## Future Considerations

### Potential Features (Not Scheduled)
- Custom quality/bitrate settings
- Real-time preview before export
- GPU hardware acceleration
- Audio crossfade transitions
- Multiple video backgrounds per project
- Direct platform upload integration

### Known Limitations
- GPU acceleration not yet implemented
- No real-time preview during processing
- Single background video per project
- No audio effects (EQ, compression)

---

## Development Notes

### Architecture Decisions

1. **Mutable LogEntry** - Chose mutable design to allow dynamic sublog addition during async operations
2. **Project-specific temp** - Prevents system-wide disk issues and improves portability
3. **Provider invalidation** - Enables FFmpeg re-check without restart while maintaining Riverpod patterns
4. **Hierarchical logging** - Docker-inspired design provides better UX for complex operations

### Performance Considerations

- Stream handling carefully designed to avoid deadlocks
- FFmpeg command execution optimized for efficiency
- Log rendering optimized with expandable tree view
- Temp file cleanup prevents storage accumulation

### Code Quality Standards

- All code passes Flutter analyzer with no warnings
- Type hints using `typing_extensions` for Python-style typing
- Comprehensive inline comments for complex logic
- Clean architecture principles followed throughout

---

**Note:** This changelog documents the major refactoring and feature additions completed in the recent development cycle. Version numbers will be assigned when the first official release is tagged.













## [3.1.3] - 2025-12-31

### Changes
- fix: add Windows support for FFmpeg path resolution and adjust command execution (9097f91)

## [3.1.2] - 2025-12-31

### Changes
- chore: update release workflow to create EXE installer with Inno Setup and adjust artifact handling (6ad704c)

## [3.1.1] - 2025-12-31

### Changes
- fix: enhance FFmpeg status handling with auto-check on startup and improved UI feedback (641b40f)

## [3.1.0] - 2025-12-31

### Changes
- feat: new UI and FFmpeg crash fix (0398414)

## [3.0.7] - 2025-12-31

### Changes
- chore: improve app bundle handling in release workflow by dynamically locating the app path (2804075)

## [3.0.6] - 2025-12-31

### Changes
- chore: update Flutter version in release workflow to use stable channel (8b39ab8)

## [3.0.5] - 2025-12-31

### Changes
- chore: refactor release workflow to streamline artifact handling and improve release creation process (136b93a)

## [3.0.4] - 2025-12-31

### Changes
- chore: add write permissions for contents in release workflow jobs (86c5635)

## [3.0.3] - 2025-12-31

### Changes
- chore: enhance auto-version workflow with SSH setup and error handling for git operations (a5799d2)

## [3.0.2] - 2025-12-31

### Changes
- chore: remove outdated text from VideoMergerPage (32364ae)
- chore: trigger release build for v3.0.2 (9e775e4)

## [3.0.1] - 2025-12-31

### Changes
- fix: remove paths-ignore from release workflow to trigger on all changes (a97ddbf)

## [3.0.0] - 2025-12-31

### Changes
- chore: trigger auto-version workflow (02755fb)
- chore: trigger auto-version workflow (893ed1c)
- fix!: simplify version bump script and update usage instructions (afe19b9)
- chore: bump version to 2.0.0 (7f00629)
- fix!: Merge pull request #2 from PradhiptaBagaskara/semver (3102ae9)
- chore: enhance macOS setup instructions and improve app signing process (740f795)
- chore: enhance macOS setup instructions and improve app signing process (32a5e12)
- feat: update dependencies and enhance README for Linux support (90fb929)
- feat: integrate package_info_plus and logger for enhanced app functionality (f7a50cd)
- feat: add automated semantic versioning system (679e8ea)
- Merge pull request #1 from PradhiptaBagaskara/cleaning (f12fb68)

## [2.0.0] - 2025-12-31

### Changes
- fix!: Merge pull request #2 from PradhiptaBagaskara/semver (3102ae9)
- chore: enhance macOS setup instructions and improve app signing process (740f795)
- chore: enhance macOS setup instructions and improve app signing process (32a5e12)
- feat: update dependencies and enhance README for Linux support (90fb929)
- feat: integrate package_info_plus and logger for enhanced app functionality (f7a50cd)
- feat: add automated semantic versioning system (679e8ea)
- Merge pull request #1 from PradhiptaBagaskara/cleaning (f12fb68)

**Note:** This changelog documents the major refactoring and feature additions completed in the recent development cycle. Version numbers will be assigned when the first official release is tagged.
