/// The stable identity of one AI Look usage operation.
///
/// This is the idempotency key for the whole reserve → generate → persist →
/// commit lifecycle. Repeating the same operation id must resolve to the *same*
/// logical reservation and the same eventual commit or release — never a second
/// reservation, a second commit, or a second paid generation.
///
/// It exists as a value object rather than a bare `String` for one specific
/// reason: it constrains what may be used as a key. The shape enforced here is
/// the UUID form already used as the identity contract across this project's
/// tables and Edge Functions, which structurally prevents the tempting
/// shortcuts — a storage path, a recommendation id concatenated with a
/// timestamp, an email address, or any other user content — from being passed
/// where an opaque operation identity is required. Private paths and user
/// content must never become idempotency keys.
///
/// Generating the value is not this type's job; it validates and normalizes.
class AiLookOperationId {
  const AiLookOperationId._(this.value);

  /// The normalized identifier: a lowercase UUID.
  final String value;

  /// The identity shape used throughout this project, matching the pattern the
  /// Edge Functions already validate incoming ids against.
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Parses [input], throwing a [FormatException] when it is not a valid
  /// operation identity.
  factory AiLookOperationId.parse(String input) {
    final normalized = _normalize(input);
    if (normalized == null) {
      throw const FormatException('Invalid AI Look operation id.');
    }
    return AiLookOperationId._(normalized);
  }

  /// Parses [input], returning `null` instead of throwing when it is not a
  /// valid operation identity.
  static AiLookOperationId? tryParse(String input) {
    final normalized = _normalize(input);
    return normalized == null ? null : AiLookOperationId._(normalized);
  }

  /// Whether [input] is a valid operation identity.
  static bool isValid(String input) => _normalize(input) != null;

  /// The rejected value is never echoed back. An operation id can carry a
  /// correlation trail, and a malformed one is exactly the case where a caller
  /// may have passed something it should not have — repeating it in an error
  /// message or a log would leak the very content this type exists to keep out.
  static String? _normalize(String input) {
    final trimmed = input.trim();
    if (!_uuid.hasMatch(trimmed)) return null;
    return trimmed.toLowerCase();
  }

  @override
  bool operator ==(Object other) =>
      other is AiLookOperationId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
