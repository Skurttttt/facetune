import '../entities/tutorial_v3_geometry.dart';

/// An in-memory store of validated geometry, keyed by session and step.
///
/// This is what makes revisiting a step instant: paging back to step 2 reads
/// the document already in memory instead of asking the server again. It holds
/// **coordinates only** — there is no image, no byte buffer and no file. V3
/// never produces a guideline picture, so there is nothing else to cache.
///
/// The cache is deliberately not persisted to disk. The database already holds
/// the durable copy; a second on-disk copy would be a second source of truth
/// that could outlive a schema bump.
class TutorialV3GeometryCache {
  final Map<String, TutorialV3Geometry> _entries =
      <String, TutorialV3Geometry>{};

  static String _key(String sessionId, int stepIndex) =>
      '$sessionId#$stepIndex';

  int get length => _entries.length;

  /// The cached document for a step, or `null` when there is nothing usable.
  ///
  /// A document written against another schema version is **evicted and
  /// reported as absent**, never returned. Filtering on read rather than on
  /// write is what makes a schema bump self-healing: entries put there by the
  /// previous build stop being served the moment the constant changes, without
  /// anything having to remember to clear them.
  TutorialV3Geometry? read(String sessionId, int stepIndex) {
    final key = _key(sessionId, stepIndex);
    final entry = _entries[key];
    if (entry == null) return null;
    if (!entry.isCurrentSchema) {
      _entries.remove(key);
      return null;
    }
    return entry;
  }

  bool contains(String sessionId, int stepIndex) =>
      read(sessionId, stepIndex) != null;

  /// Stores a validated document.
  ///
  /// Callers must pass geometry that has already been through
  /// `TutorialV3GeometryValidator`; this is a cache, not a second gate.
  void write(String sessionId, int stepIndex, TutorialV3Geometry geometry) {
    _entries[_key(sessionId, stepIndex)] = geometry;
  }

  void evict(String sessionId, int stepIndex) {
    _entries.remove(_key(sessionId, stepIndex));
  }

  /// Drops everything belonging to one tutorial, for when a session is
  /// replanned and its old step indices no longer mean the same thing.
  void evictSession(String sessionId) {
    _entries.removeWhere((key, _) => key.startsWith('$sessionId#'));
  }

  void clear() => _entries.clear();
}
