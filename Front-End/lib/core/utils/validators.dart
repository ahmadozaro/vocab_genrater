class AppValidators {
  static bool isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }

  static bool isStrongEnoughPassword(String value) {
    return value.length >= 8;
  }

  static String? requiredText(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  AppValidators._();
}
