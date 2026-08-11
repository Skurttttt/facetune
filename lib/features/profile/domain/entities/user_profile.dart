class UserProfile {
  const UserProfile({
    required this.id,
    required this.authUserId,
    required this.createdAt,
    required this.updatedAt,
    this.displayName,
    this.avatarPath,
    this.avatarUrl,
  });

  final String id;
  final String authUserId;
  final String? displayName;
  final String? avatarPath;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
}
