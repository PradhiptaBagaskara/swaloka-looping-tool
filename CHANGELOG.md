# Changelog

All notable changes to Swaloka Looping Tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [5.2.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/swaloka_looping_tool-v5.1.0...swaloka_looping_tool-v5.2.0) (2026-01-13)


### Features

* **video-tools:** enhance video re-encoding with aspect ratio options ([#37](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/37)) ([49d462e](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/49d462e0e6c3c012b1a06e8531c068099c79e161))

## [5.1.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/swaloka_looping_tool-v5.0.0...swaloka_looping_tool-v5.1.0) (2026-01-06)


### Features

* improve video processing performance and UX ([f10eaf2](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/f10eaf24c95d8e875c558902f6a93d7bb3da5538))

## [5.0.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/swaloka_looping_tool-v4.1.0...swaloka_looping_tool-v5.0.0) (2026-01-06)


### ⚠ BREAKING CHANGES

* **core:** enhance project structure and add new features ([#33](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/33))

### Features

* **core:** enhance project structure and add new features ([#33](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/33)) ([d7b8d5f](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/d7b8d5fb101039fe2cc03410d34f4fdfe59caf64))

## [4.1.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/swaloka_looping_tool-v4.0.0...swaloka_looping_tool-v4.1.0) (2026-01-05)


### Features

* **video-merger:** add duration handling to video metadata and processing state ([#30](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/30)) ([35b42c3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/35b42c37207ee86e97af41f5d0d8b1a93e13de9f))

## [4.0.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/swaloka_looping_tool-v3.10.0...swaloka_looping_tool-v4.0.0) (2026-01-02)


### ⚠ BREAKING CHANGES

* simplify version bump script and update usage instructions
* Merge pull request #2 from PradhiptaBagaskara/semver

### Features

* add automated semantic versioning system ([679e8ea](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/679e8eab4f29778bc05159bd4b8c0f63f8ce49de))
* Add device_info_plus dependency to Podfile.lock for macOS support ([90c8bde](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/90c8bdeb4969551e3c129e1e4f1bcc40fcfd90ea))
* add Linux support for app build and enhance hardware encoder detection ([ca9c739](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ca9c739815366fb6112d2627adefa1c52c978669))
* add step to download VC++ Redistributable in release workflow for Windows build ([ba2f3ed](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ba2f3ed20ed653308b39967abf0adc752eb623df))
* add VC++ Redistributable installation support in Windows installer ([16aa15b](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/16aa15b6a5beb860f000ba43723301e7db9e4bb5))
* Add video audio merger script and integrate FFmpeg checks in the app for enhanced video processing capabilities ([73110a6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/73110a637b2bcae17ead1169a0993b231f042da7))
* Add video_player_win dependency and integrate it into the project for enhanced video playback on Windows ([36b4ce8](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/36b4ce8315cfcb9a1e1944b72e25118a027a7d58))
* Enhance GPU detection and encoder selection for video merging on Windows ([ffff199](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ffff199ce2f8e070363f14a77d4933952e2839c6))
* enhance installation process, CI workflows, and macOs fixes ([#22](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/22)) ([7fd2746](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/7fd2746163e3a4091ec7e5459244af3b387bf4f6))
* enhance video merging performance by pre-warming OS file cache and improving temp directory creation logic for cross-platform compatibility ([4ac39bc](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/4ac39bcb5bf36c3270eed0835cba1c08534d3337))
* Implement encoder-specific preset mapping for video merging to enhance compatibility across different encoders ([e3ad06b](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/e3ad06bf1634c1ce37227c296a9eb266bd6eb87f))
* implement FFmpeg service for handling video processing and update related dependencies ([8a5bdf6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8a5bdf666183d6fe178f3a444ec843f7a04b5cb4))
* Integrate device_info_plus for hardware detection and enhance video merging capabilities on Windows ([7ae17b0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/7ae17b0e028e8717b4a00ea1d064b94265d9b292))
* integrate MediaKit for enhanced video playback and remove legacy video player dependencies ([e00113c](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/e00113ce133087b7a7614a4303accb82f0d4f053))
* integrate package_info_plus and logger for enhanced app functionality ([f7a50cd](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/f7a50cdf10e943328bc6b27917d0c2cd63e54d3d))
* new UI and FFmpeg crash fix ([0398414](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/039841482b1318215d94aed7c2f62c232cc4af09))
* update dependencies and enhance README for Linux support ([90fb929](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/90fb92960d15afdc18159aeb1e60989843e0bf62))
* **video-merger:** add intro video support with audio handling options ([#18](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/18)) ([03bf7a3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/03bf7a39c62dd1537fcb2d6bea07157ba3ec3bfa))
* Windows installer and delete test ([8ce3b63](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8ce3b63fee986919e31761cda81c64ca4ca85cd6))


### Bug Fixes

* add AppImage creation to Linux release workflow and install additional dependencies ([76a8062](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/76a8062dbdd0c603c3dfdc2b34d8ea1a92838a85))
* add Windows support for FFmpeg path resolution and adjust command execution ([9097f91](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/9097f91fd8f133e2c90648aa58048a81e6642525))
* dialog confirmation ([8afa02b](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8afa02b59c95f656de3158aa1a19da62d642c701))
* enhance FFmpeg status handling with auto-check on startup and improved UI feedback ([641b40f](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/641b40f310d43984f0c05bc1d9d7571f6d4e3dee))
* linux build and ci improvement ([#3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/3)) ([8d98653](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8d986531a0b334e8950f9a37b8eb23eb31322e88))
* macos intaller ([3102ae9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/3102ae968f5b6327a588183aa8cd4272b5cb077f))
* Merge pull request [#2](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/2) from PradhiptaBagaskara/semver ([3102ae9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/3102ae968f5b6327a588183aa8cd4272b5cb077f))
* normalize file paths across video merger components for platform compatibility ([0884adf](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/0884adfc4a8ae10c782a87e849b31c55b895b034))
* release-pls token ([#6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/6)) ([ad7fb65](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ad7fb652d92e3ed44066451dec50c5a42e74fa78))
* remove paths-ignore from release workflow to trigger on all changes ([a97ddbf](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/a97ddbf7ddd5e59270862a98225f208f97329bcb))
* render default layout for new project ([1b73489](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/1b734891ab806e6c1396294ac08b09da8b9a9990))
* simplify version bump script and update usage instructions ([afe19b9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/afe19b92cb47c194265a96a12e238061b7d4b2b7))
* update CI workflows and .gitignore for better platform support ([#5](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/5)) ([dacdfb9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/dacdfb9db785029c426562d252de19bd5a83038c))
* update FFmpeg command execution on Windows to use runInShell with proper argument quoting for improved compatibility ([02f01c1](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/02f01c1699a4e79d04bf197651c763d73c95cf59))
* Update macOS build zip command to include all .app files and correct ProductVersion in Runner.rc to use VERSION_AS_STRING ([da2a873](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/da2a873a3a1f0d16c0c8e28deb2338009cf7edcb))
* update VC++ Redistributable installation logic in Windows installer script to handle optional bundling ([75e9513](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/75e9513725f867438c95ccd20344ba99d520a79f))
* windows path ([67ee581](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/67ee581e30f19f1326e11202dda30a5852967aee))

## [3.10.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/swaloka_looping_tool-v3.10.0...swaloka_looping_tool-v3.10.0) (2026-01-02)
* add develop branch

### ⚠ BREAKING CHANGES

* simplify version bump script and update usage instructions
* Merge pull request #2 from PradhiptaBagaskara/semver

### Features

* add automated semantic versioning system ([679e8ea](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/679e8eab4f29778bc05159bd4b8c0f63f8ce49de))
* Add device_info_plus dependency to Podfile.lock for macOS support ([90c8bde](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/90c8bdeb4969551e3c129e1e4f1bcc40fcfd90ea))
* add Linux support for app build and enhance hardware encoder detection ([ca9c739](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ca9c739815366fb6112d2627adefa1c52c978669))
* add step to download VC++ Redistributable in release workflow for Windows build ([ba2f3ed](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ba2f3ed20ed653308b39967abf0adc752eb623df))
* add VC++ Redistributable installation support in Windows installer ([16aa15b](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/16aa15b6a5beb860f000ba43723301e7db9e4bb5))
* Add video audio merger script and integrate FFmpeg checks in the app for enhanced video processing capabilities ([73110a6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/73110a637b2bcae17ead1169a0993b231f042da7))
* Add video_player_win dependency and integrate it into the project for enhanced video playback on Windows ([36b4ce8](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/36b4ce8315cfcb9a1e1944b72e25118a027a7d58))
* Enhance GPU detection and encoder selection for video merging on Windows ([ffff199](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ffff199ce2f8e070363f14a77d4933952e2839c6))
* enhance installation process, CI workflows, and macOs fixes ([#22](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/22)) ([7fd2746](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/7fd2746163e3a4091ec7e5459244af3b387bf4f6))
* enhance video merging performance by pre-warming OS file cache and improving temp directory creation logic for cross-platform compatibility ([4ac39bc](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/4ac39bcb5bf36c3270eed0835cba1c08534d3337))
* Implement encoder-specific preset mapping for video merging to enhance compatibility across different encoders ([e3ad06b](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/e3ad06bf1634c1ce37227c296a9eb266bd6eb87f))
* implement FFmpeg service for handling video processing and update related dependencies ([8a5bdf6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8a5bdf666183d6fe178f3a444ec843f7a04b5cb4))
* Integrate device_info_plus for hardware detection and enhance video merging capabilities on Windows ([7ae17b0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/7ae17b0e028e8717b4a00ea1d064b94265d9b292))
* integrate MediaKit for enhanced video playback and remove legacy video player dependencies ([e00113c](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/e00113ce133087b7a7614a4303accb82f0d4f053))
* integrate package_info_plus and logger for enhanced app functionality ([f7a50cd](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/f7a50cdf10e943328bc6b27917d0c2cd63e54d3d))
* new UI and FFmpeg crash fix ([0398414](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/039841482b1318215d94aed7c2f62c232cc4af09))
* update dependencies and enhance README for Linux support ([90fb929](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/90fb92960d15afdc18159aeb1e60989843e0bf62))
* **video-merger:** add intro video support with audio handling options ([#18](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/18)) ([03bf7a3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/03bf7a39c62dd1537fcb2d6bea07157ba3ec3bfa))
* Windows installer and delete test ([8ce3b63](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8ce3b63fee986919e31761cda81c64ca4ca85cd6))


### Bug Fixes

* add AppImage creation to Linux release workflow and install additional dependencies ([76a8062](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/76a8062dbdd0c603c3dfdc2b34d8ea1a92838a85))
* add Windows support for FFmpeg path resolution and adjust command execution ([9097f91](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/9097f91fd8f133e2c90648aa58048a81e6642525))
* dialog confirmation ([8afa02b](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8afa02b59c95f656de3158aa1a19da62d642c701))
* enhance FFmpeg status handling with auto-check on startup and improved UI feedback ([641b40f](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/641b40f310d43984f0c05bc1d9d7571f6d4e3dee))
* linux build and ci improvement ([#3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/3)) ([8d98653](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8d986531a0b334e8950f9a37b8eb23eb31322e88))
* macos intaller ([3102ae9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/3102ae968f5b6327a588183aa8cd4272b5cb077f))
* Merge pull request [#2](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/2) from PradhiptaBagaskara/semver ([3102ae9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/3102ae968f5b6327a588183aa8cd4272b5cb077f))
* normalize file paths across video merger components for platform compatibility ([0884adf](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/0884adfc4a8ae10c782a87e849b31c55b895b034))
* release-pls token ([#6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/6)) ([ad7fb65](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ad7fb652d92e3ed44066451dec50c5a42e74fa78))
* remove paths-ignore from release workflow to trigger on all changes ([a97ddbf](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/a97ddbf7ddd5e59270862a98225f208f97329bcb))
* render default layout for new project ([1b73489](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/1b734891ab806e6c1396294ac08b09da8b9a9990))
* simplify version bump script and update usage instructions ([afe19b9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/afe19b92cb47c194265a96a12e238061b7d4b2b7))
* update CI workflows and .gitignore for better platform support ([#5](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/5)) ([dacdfb9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/dacdfb9db785029c426562d252de19bd5a83038c))
* update FFmpeg command execution on Windows to use runInShell with proper argument quoting for improved compatibility ([02f01c1](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/02f01c1699a4e79d04bf197651c763d73c95cf59))
* Update macOS build zip command to include all .app files and correct ProductVersion in Runner.rc to use VERSION_AS_STRING ([da2a873](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/da2a873a3a1f0d16c0c8e28deb2338009cf7edcb))
* update release process and workflow documentation ([32b732d](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/32b732de2f7d33910a55549b3a1acbcc2089a8af))
* update VC++ Redistributable installation logic in Windows installer script to handle optional bundling ([75e9513](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/75e9513725f867438c95ccd20344ba99d520a79f))
* windows path ([67ee581](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/67ee581e30f19f1326e11202dda30a5852967aee))

## [3.10.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/v3.9.0...v3.10.0) (2026-01-02)


### Features

* enhance installation process, CI workflows, and macOs fixes ([#22](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/22)) ([7fd2746](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/7fd2746163e3a4091ec7e5459244af3b387bf4f6))

## [3.9.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/v3.8.0...v3.9.0) (2026-01-02)


### Features

* Windows installer and delete test ([8ce3b63](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8ce3b63fee986919e31761cda81c64ca4ca85cd6))

## [3.8.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/v3.7.2...v3.8.0) (2026-01-02)


### Features

* **video-merger:** add intro video support with audio handling options ([#18](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/18)) ([03bf7a3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/03bf7a39c62dd1537fcb2d6bea07157ba3ec3bfa))

## [3.7.2](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/v3.7.1...v3.7.2) (2026-01-02)


### Bug Fixes

* linux build and ci improvement ([#3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/3)) ([8d98653](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8d986531a0b334e8950f9a37b8eb23eb31322e88))
* release-pls token ([#6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/6)) ([ad7fb65](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ad7fb652d92e3ed44066451dec50c5a42e74fa78))
* update CI workflows and .gitignore for better platform support ([#5](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/5)) ([dacdfb9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/dacdfb9db785029c426562d252de19bd5a83038c))

## [3.7.1](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/v3.7.0...v3.7.1) (2026-01-02)


### Bug Fixes

* add AppImage creation to Linux release workflow and install additional dependencies ([76a8062](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/76a8062dbdd0c603c3dfdc2b34d8ea1a92838a85))
* linux build and ci improvement ([#3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/3)) ([8d98653](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8d986531a0b334e8950f9a37b8eb23eb31322e88))
* release-pls token ([#6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/6)) ([ad7fb65](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ad7fb652d92e3ed44066451dec50c5a42e74fa78))
* update CI workflows and .gitignore for better platform support ([#5](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/5)) ([dacdfb9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/dacdfb9db785029c426562d252de19bd5a83038c))

## [3.7.0](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/compare/v3.6.0...v3.7.0) (2026-01-02)


### Features

* integrate MediaKit for enhanced video playback and remove legacy video player dependencies ([e00113c](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/e00113ce133087b7a7614a4303accb82f0d4f053))


### Bug Fixes

* add AppImage creation to Linux release workflow and install additional dependencies ([76a8062](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/76a8062dbdd0c603c3dfdc2b34d8ea1a92838a85))
* linux build and ci improvement ([#3](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/3)) ([8d98653](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/8d986531a0b334e8950f9a37b8eb23eb31322e88))
* release-pls token ([#6](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/6)) ([ad7fb65](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/ad7fb652d92e3ed44066451dec50c5a42e74fa78))
* update CI workflows and .gitignore for better platform support ([#5](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/issues/5)) ([dacdfb9](https://github.com/PradhiptaBagaskara/swaloka-looping-tool/commit/dacdfb9db785029c426562d252de19bd5a83038c))

## [Unreleased]



### 🎨 Improvements

#### Enhanced Video Playback
- **Switched to MediaKit player** - Replaced `video_player_win` with `media_kit`
  - Full Linux support via libmpv
  - Hardware-accelerated playback on Windows, macOS, and Linux
  - Better codec support and performance
  - Unified API across all desktop platforms
























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

























## [3.7.1] - 2026-01-02

### Changes
- fix: add AppImage creation to Linux release workflow and install additional dependencies (76a8062)

## [3.7.0] - 2026-01-02

### Changes
- refactor: improve FFmpeg command execution and enhance video merger service with absolute paths (537d5c1)
- feat: integrate MediaKit for enhanced video playback and remove legacy video player dependencies (e00113c)

## [3.6.0] - 2026-01-01

### Changes
- feat: add Linux support for app build and enhance hardware encoder detection (ca9c739)

## [3.5.3] - 2026-01-01

### Changes
- chore: simplify error handling and update donation options in VideoEditorPage (ec076a7)

## [3.5.2] - 2026-01-01

### Changes
- fix: windows path (67ee581)

## [3.5.1] - 2026-01-01

### Changes
- fix: update FFmpeg command execution on Windows to use runInShell with proper argument quoting for improved compatibility (02f01c1)

## [3.5.0] - 2026-01-01

### Changes
- chore: improve FFmpeg command execution on Windows and add file path validation for video merger service (d070bbb)
- feat: enhance video merging performance by pre-warming OS file cache and improving temp directory creation logic for cross-platform compatibility (4ac39bc)

## [3.4.1] - 2026-01-01

### Changes
- fix: normalize file paths across video merger components for platform compatibility (0884adf)

## [3.4.0] - 2026-01-01

### Changes
- feat: implement FFmpeg service for handling video processing and update related dependencies (8a5bdf6)

## [3.3.0] - 2026-01-01

### Changes
- feat: add step to download VC++ Redistributable in release workflow for Windows build (ba2f3ed)

## [3.2.1] - 2026-01-01

### Changes
- fix: update VC++ Redistributable installation logic in Windows installer script to handle optional bundling (75e9513)

## [3.2.0] - 2026-01-01

### Changes
- feat: add VC++ Redistributable installation support in Windows installer (16aa15b)

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
