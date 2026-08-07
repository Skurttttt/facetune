import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SupabaseRemoteDataSource {
  const SupabaseRemoteDataSource(this.client);

  @protected
  final SupabaseClient client;
}
