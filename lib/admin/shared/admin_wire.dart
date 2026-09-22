import 'admin_read_failure.dart';

/// Strict decoding of the camelCase JSON the admin RPCs return.
///
/// Every accessor fails closed: a missing key, a wrong type, a negative count
/// where only a count makes sense, or a code outside the controlled
/// vocabulary throws [AdminReadFailure] rather than defaulting. A nullable
/// accessor still requires the key to be present — the server always writes
/// every field, so an absent key is a shape mismatch, not a null.
const adminContractVersion = 'subscription_admin_contract_v1.1';

/// The fixed page size every admin listing RPC declares.
const adminPageSize = 25;

Never malformed() => throw const AdminReadFailure(
  AdminReadFailureType.unavailable,
  retryable: true,
);

Map<String, Object?> object(Object? payload) {
  if (payload is! Map) return malformed();
  return payload.map((key, value) => MapEntry(key.toString(), value));
}

/// The common envelope of a listing response: `ok`, contract version, fixed
/// page size, and the fixed `createdAt desc` sort.
Map<String, Object?> listEnvelope(Object? payload) {
  final value = object(payload);
  final sort = object(value['sort']);
  if (value['ok'] != true ||
      value['contractVersion'] != adminContractVersion ||
      value['items'] is! List ||
      value['pageSize'] != adminPageSize ||
      sort['field'] != 'createdAt' ||
      sort['direction'] != 'desc') {
    return malformed();
  }
  return value;
}

String string(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is String && field.isNotEmpty ? field : malformed();
}

String? nullableString(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) return malformed();
  final field = value[key];
  return field == null
      ? null
      : field is String
      ? field
      : malformed();
}

int nonNegativeInt(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is int && field >= 0 ? field : malformed();
}

/// A signed integer, for the audited adjustment total which may be negative.
int signedInt(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is int ? field : malformed();
}

bool boolean(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is bool ? field : malformed();
}

bool? nullableBool(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) return malformed();
  final field = value[key];
  return field == null
      ? null
      : field is bool
      ? field
      : malformed();
}

DateTime date(Map<String, Object?> value, String key) {
  final field = value[key];
  final parsed = field is String ? DateTime.tryParse(field) : null;
  return parsed == null ? malformed() : parsed.toUtc();
}

DateTime? nullableDate(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) return malformed();
  final field = value[key];
  if (field == null) return null;
  return date(value, key);
}

T vocabulary<T>(
  Map<String, Object?> value,
  String key,
  T? Function(String) decode,
) {
  final field = value[key];
  final parsed = field is String ? decode(field) : null;
  return parsed ?? malformed();
}

T? nullableVocabulary<T>(
  Map<String, Object?> value,
  String key,
  T? Function(String) decode,
) {
  if (!value.containsKey(key)) return malformed();
  final field = value[key];
  if (field == null) return null;
  return field is String ? decode(field) ?? malformed() : malformed();
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// [value] lower-cased and trimmed if it is a UUID, else `null`. Identifier
/// filters are sent to the server only in this exact form.
String? normalizeUuid(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty || !_uuid.hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

/// Whether [value], trimmed, is non-empty and not a UUID — an identifier the
/// server would refuse, reported before any request is made.
bool isMalformedUuidInput(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isNotEmpty && normalizeUuid(trimmed) == null;
}
