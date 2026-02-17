/// Utility functions for formatting timestamps
class TimestampFormatter {
  /// Format date as YYYY_MM_DD_HH_SS_ms
  ///
  /// Example output: 2026_02_17_14_30_123
  static String format() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '${year}_${month}_${day}_${hour}_${minute}_$ms';
  }
}
