import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class MakeupKitProductsRemoteDataSource {
  String? get currentUserId;

  Future<List<Map<String, Object?>>> selectAll();

  Future<List<Map<String, Object?>>> selectByCategory(String categoryCode);

  Future<Map<String, Object?>> insert(Map<String, Object?> values);

  Future<Map<String, Object?>> update(
    String productId,
    Map<String, Object?> values,
  );

  Future<void> delete(String productId);
}

class SupabaseMakeupKitProductsRemoteDataSource extends SupabaseRemoteDataSource
    implements MakeupKitProductsRemoteDataSource {
  const SupabaseMakeupKitProductsRemoteDataSource(super.client);

  static const _table = 'makeup_kit_products';

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<List<Map<String, Object?>>> selectAll() async => _rows(
    await client.from(_table).select('*').order('created_at', ascending: false),
  );

  @override
  Future<List<Map<String, Object?>>> selectByCategory(
    String categoryCode,
  ) async => _rows(
    await client
        .from(_table)
        .select('*')
        .eq('category', categoryCode)
        .order('created_at', ascending: false),
  );

  @override
  Future<Map<String, Object?>> insert(Map<String, Object?> values) async =>
      _row(await client.from(_table).insert(values).select('*').single());

  @override
  Future<Map<String, Object?>> update(
    String productId,
    Map<String, Object?> values,
  ) async => _row(
    await client
        .from(_table)
        .update(values)
        .eq('id', productId)
        .select('*')
        .single(),
  );

  @override
  Future<void> delete(String productId) async {
    await client.from(_table).delete().eq('id', productId);
  }

  static List<Map<String, Object?>> _rows(List<dynamic> rows) =>
      rows.map((row) => _row(row as Map)).toList();

  static Map<String, Object?> _row(Map row) =>
      row.map((key, value) => MapEntry(key.toString(), value));
}
