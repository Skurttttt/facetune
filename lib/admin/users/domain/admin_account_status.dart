/// Privacy-minimal account state derived by the server from Supabase Auth.
///
/// This is support context only. It is not an entitlement status and must
/// never be used to authorize subscription behavior.
enum AdminAccountStatus {
  active('active', 'Active'),
  unconfirmed('unconfirmed', 'Unconfirmed'),
  banned('banned', 'Banned'),
  anonymous('anonymous', 'Anonymous guest');

  const AdminAccountStatus(this.code, this.label);

  final String code;
  final String label;

  static AdminAccountStatus? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}
