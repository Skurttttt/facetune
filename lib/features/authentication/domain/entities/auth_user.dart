class AuthUser {
  const AuthUser({
    required this.id,
    required this.isAnonymous,
    this.email,
    this.displayName,
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  String get friendlyName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    if (isAnonymous) {
      return 'Guest';
    }
    return email?.split('@').first ?? 'Beauty lover';
  }
}
