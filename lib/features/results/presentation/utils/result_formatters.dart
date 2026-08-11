abstract final class ResultFormatters {
  static String label(String value) {
    final words = value
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}
