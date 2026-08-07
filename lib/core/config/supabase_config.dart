class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  factory SupabaseConfig.fromEnvironment() {
    return const SupabaseConfig(
      url: String.fromEnvironment('SUPABASE_URL'),
      publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    );
  }

  final String url;
  final String publishableKey;

  bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  void validate() {
    if (!isConfigured) {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must both be provided.',
      );
    }

    final uri = Uri.tryParse(url);
    final isValidProjectUrl =
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.endsWith('.supabase.co') &&
        uri.path.isEmpty;
    if (!isValidProjectUrl) {
      throw const SupabaseConfigurationException(
        'SUPABASE_URL must be an HTTPS project API URL ending in .supabase.co.',
      );
    }

    if (!publishableKey.startsWith('sb_publishable_')) {
      throw const SupabaseConfigurationException(
        'Use a Supabase publishable key for the Flutter client.',
      );
    }
  }
}

class SupabaseConfigurationException implements Exception {
  const SupabaseConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'SupabaseConfigurationException: $message';
}
