abstract final class AuthValidators {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your email address.';
    }
    final validEmail = RegExp(
      r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
      caseSensitive: false,
    ).hasMatch(email);
    return validEmail ? null : 'Enter a valid email address.';
  }

  static String? displayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Enter your name.';
    }
    if (name.length > 80) {
      return 'Name must be 80 characters or fewer.';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Enter your password.';
    }
    if (password.length < 8) {
      return 'Use at least 8 characters.';
    }
    if (!RegExp('[A-Za-z]').hasMatch(password) ||
        !RegExp('[0-9]').hasMatch(password)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? confirmedPassword(String? value, String password) {
    final validation = AuthValidators.password(value);
    if (validation != null) {
      return validation;
    }
    return value == password ? null : 'Passwords do not match.';
  }
}
