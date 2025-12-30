import 'dart:io';

/// Service for detecting system hardware capabilities
class SystemInfoService {
  /// Get the number of CPU cores available
  static int get cpuCores {
    try {
      // On all platforms (Linux, macOS, Windows), use platform.numberOfProcessors
      return Platform.numberOfProcessors;
    } catch (e) {
      // Fallback to a safe default
      return 4;
    }
  }

  /// Get recommended concurrency limit based on CPU cores
  ///
  /// Recommendation formula:
  /// - For light workloads: 50% of CPU cores
  /// - For balanced workloads: 75% of CPU cores
  /// - For heavy workloads: 100% of CPU cores (or cores - 1)
  static int getRecommendedConcurrency({ConcurrentWorkload workload = ConcurrentWorkload.balanced}) {
    final cores = cpuCores;

    switch (workload) {
      case ConcurrentWorkload.light:
        // Use 50% of cores, minimum 2
        return (cores * 0.5).ceil().clamp(2, cores);
      case ConcurrentWorkload.balanced:
        // Use 75% of cores, minimum 2
        return (cores * 0.75).ceil().clamp(2, cores);
      case ConcurrentWorkload.heavy:
        // Use all cores, or cores - 1 to leave room for system
        return (cores > 1) ? cores - 1 : cores;
    }
  }

  /// Get CPU count information as a string
  static String getCpuInfo() {
    final cores = cpuCores;
    final recommended = getRecommendedConcurrency();
    return '$cores CPU cores detected (recommended: $recommended parallel tasks)';
  }

  /// Get maximum safe concurrency (leaves some CPU for system)
  static int get maxSafeConcurrency {
    return cpuCores > 1 ? cpuCores - 1 : cpuCores;
  }
}

/// Workload intensity for concurrency recommendations
enum ConcurrentWorkload {
  /// Light workload - use 50% of CPU cores
  light,

  /// Balanced workload - use 75% of CPU cores (recommended for most cases)
  balanced,

  /// Heavy workload - use all available CPU cores
  heavy,
}
