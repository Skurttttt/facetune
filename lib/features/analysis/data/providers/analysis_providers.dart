import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/face_analysis_repository.dart';
import '../../domain/usecases/analyze_face.dart';
import '../data_sources/analysis_remote_data_source.dart';
import '../repositories/supabase_face_analysis_repository.dart';
import '../repositories/unavailable_face_analysis_repository.dart';

final faceAnalysisRepositoryProvider = Provider<FaceAnalysisRepository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableFaceAnalysisRepository();
  }
  final dataSource = SupabaseAnalysisRemoteDataSource(
    ref.watch(supabaseClientProvider),
  );
  return SupabaseFaceAnalysisRepository(dataSource);
});

final analyzeFaceProvider = Provider<AnalyzeFace>(
  (ref) => AnalyzeFace(ref.watch(faceAnalysisRepositoryProvider)),
);
