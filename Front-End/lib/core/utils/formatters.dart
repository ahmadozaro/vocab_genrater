class AppFormatters {
  static String percent(num value) => '${value.round()}%';

  static String compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  static String normalizeWhitespace(String value) {
    return value.trim().split(RegExp(r'\s+')).join(' ');
  }

  AppFormatters._();
}
