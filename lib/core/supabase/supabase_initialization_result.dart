enum SupabaseInitializationStatus {
  ready,
  missingConfiguration,
  invalidConfiguration,
  initializationFailed,
}

class SupabaseInitializationResult {
  const SupabaseInitializationResult._({
    required this.status,
    required this.urlConfigured,
    required this.publishableKeyConfigured,
  });

  const SupabaseInitializationResult.ready()
    : this._(
        status: SupabaseInitializationStatus.ready,
        urlConfigured: true,
        publishableKeyConfigured: true,
      );

  const SupabaseInitializationResult.missing({
    required bool urlConfigured,
    required bool publishableKeyConfigured,
  }) : this._(
         status: SupabaseInitializationStatus.missingConfiguration,
         urlConfigured: urlConfigured,
         publishableKeyConfigured: publishableKeyConfigured,
       );

  const SupabaseInitializationResult.invalid()
    : this._(
        status: SupabaseInitializationStatus.invalidConfiguration,
        urlConfigured: true,
        publishableKeyConfigured: true,
      );

  const SupabaseInitializationResult.failed()
    : this._(
        status: SupabaseInitializationStatus.initializationFailed,
        urlConfigured: true,
        publishableKeyConfigured: true,
      );

  final SupabaseInitializationStatus status;
  final bool urlConfigured;
  final bool publishableKeyConfigured;

  bool get isReady => status == SupabaseInitializationStatus.ready;

  String get userMessage => switch (status) {
    SupabaseInitializationStatus.ready => '',
    SupabaseInitializationStatus.missingConfiguration =>
      'Authentication is unavailable because this build is missing its Supabase runtime configuration.',
    SupabaseInitializationStatus.invalidConfiguration =>
      'Authentication is unavailable because this build has invalid Supabase configuration.',
    SupabaseInitializationStatus.initializationFailed =>
      'Authentication could not start. Check your connection and try again.',
  };
}
