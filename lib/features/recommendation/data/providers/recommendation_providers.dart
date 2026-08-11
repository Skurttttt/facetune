import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/makeup_recommendation_repository.dart';
import '../../domain/usecases/generate_makeup_recommendation.dart';
import '../data_sources/recommendation_remote_data_source.dart';
import '../repositories/supabase_makeup_recommendation_repository.dart';
import '../repositories/unavailable_makeup_recommendation_repository.dart';

final makeupRecommendationRepositoryProvider =
    Provider<MakeupRecommendationRepository>((ref) {
      if (!ref.watch(supabaseAvailableProvider)) {
        return const UnavailableMakeupRecommendationRepository();
      }
      return SupabaseMakeupRecommendationRepository(
        SupabaseRecommendationRemoteDataSource(
          ref.watch(supabaseClientProvider),
        ),
      );
    });

final generateMakeupRecommendationProvider = Provider(
  (ref) => GenerateMakeupRecommendation(
    ref.watch(makeupRecommendationRepositoryProvider),
  ),
);
