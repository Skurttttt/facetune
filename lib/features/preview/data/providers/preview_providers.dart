import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/makeup_preview_repository.dart';
import '../../domain/usecases/generate_makeup_preview.dart';
import '../data_sources/preview_remote_data_source.dart';
import '../repositories/supabase_makeup_preview_repository.dart';
import '../repositories/unavailable_makeup_preview_repository.dart';

final makeupPreviewRepositoryProvider = Provider<MakeupPreviewRepository>((
  ref,
) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableMakeupPreviewRepository();
  }
  return SupabaseMakeupPreviewRepository(
    SupabasePreviewRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});

final generateMakeupPreviewProvider = Provider(
  (ref) => GenerateMakeupPreview(ref.watch(makeupPreviewRepositoryProvider)),
);
