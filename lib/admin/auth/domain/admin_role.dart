/// Account-level authorization tiers. Shared Contract v1.1 §53.
///
/// Mirrors `ADMIN_ROLES` in `supabase/functions/_shared/admin_contract.ts`.
/// The Web Admin never decides a role; it receives one from the server's
/// session check and refuses anything outside this vocabulary.
enum AdminRole {
  normalUser('normal_user'),
  admin('admin');

  const AdminRole(this.code);

  /// The stable wire identifier.
  final String code;

  /// Returns the role for [code], or `null` when [code] is outside the
  /// controlled vocabulary. An unrecognised role must never become [admin].
  static AdminRole? fromCode(String code) {
    for (final role in values) {
      if (role.code == code) return role;
    }
    return null;
  }
}
