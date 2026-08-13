import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/makeup_kit_products_repository.dart';
import '../data_sources/makeup_kit_products_remote_data_source.dart';
import '../repositories/supabase_makeup_kit_products_repository.dart';
import '../repositories/unavailable_makeup_kit_products_repository.dart';

/// Bumped after a mutation elsewhere invalidates the loaded kit, mirroring
/// `savedLooksRevisionProvider`.
final makeupKitProductsRevisionProvider = StateProvider<int>((ref) => 0);

final makeupKitProductsRepositoryProvider =
    Provider<MakeupKitProductsRepository>((ref) {
      if (!ref.watch(supabaseAvailableProvider)) {
        return const UnavailableMakeupKitProductsRepository();
      }
      return SupabaseMakeupKitProductsRepository(
        SupabaseMakeupKitProductsRemoteDataSource(
          ref.watch(supabaseClientProvider),
        ),
      );
    });
