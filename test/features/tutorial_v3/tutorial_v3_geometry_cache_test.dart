import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_geometry_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

void main() {
  late TutorialV3GeometryCache cache;

  setUp(() => cache = TutorialV3GeometryCache());

  test('a written document is read back', () {
    final geometry = testGeometry();
    cache.write('session-1', 1, geometry);

    expect(cache.read('session-1', 1), same(geometry));
    expect(cache.contains('session-1', 1), isTrue);
  });

  test('entries are scoped to their own session and step', () {
    cache.write('session-1', 1, testGeometry());

    expect(cache.read('session-1', 2), isNull);
    expect(cache.read('session-2', 1), isNull);
  });

  test('a document from another schema version is never served', () {
    // The invalidation that matters: after a schema bump the constant changes,
    // and everything the previous build cached stops being readable without
    // anything having to remember to clear it.
    cache.write(
      'session-1',
      1,
      testGeometry(schemaVersion: tutorialV3GeometrySchemaVersion + 1),
    );

    expect(cache.read('session-1', 1), isNull);
    expect(cache.contains('session-1', 1), isFalse);
  });

  test('a stale entry is evicted on the read that rejects it', () {
    cache.write(
      'session-1',
      1,
      testGeometry(schemaVersion: tutorialV3GeometrySchemaVersion - 1),
    );
    expect(cache.length, 1);

    cache.read('session-1', 1);

    expect(cache.length, 0, reason: 'a rejected entry must not linger');
  });

  test('a later write replaces an earlier one', () {
    final replacement = testGeometry(category: TutorialV3Category.blush);
    cache.write(
      'session-1',
      1,
      testGeometry(category: TutorialV3Category.blush),
    );
    cache.write('session-1', 1, replacement);

    expect(cache.read('session-1', 1), same(replacement));
    expect(cache.length, 1);
  });

  test('evicting one step leaves its neighbours alone', () {
    cache.write('session-1', 1, testGeometry());
    cache.write('session-1', 2, testGeometry());

    cache.evict('session-1', 1);

    expect(cache.read('session-1', 1), isNull);
    expect(cache.read('session-1', 2), isNotNull);
  });

  test('evicting a session leaves other sessions alone', () {
    // A replan changes what step 2 teaches, so that tutorial's entries have to
    // go — but only that tutorial's.
    cache.write('session-1', 1, testGeometry());
    cache.write('session-1', 2, testGeometry());
    cache.write('session-2', 1, testGeometry());

    cache.evictSession('session-1');

    expect(cache.read('session-1', 1), isNull);
    expect(cache.read('session-1', 2), isNull);
    expect(cache.read('session-2', 1), isNotNull);
  });

  test('a session id that is a prefix of another is not evicted with it', () {
    cache.write('session-1', 1, testGeometry());
    cache.write('session-10', 1, testGeometry());

    cache.evictSession('session-1');

    expect(cache.read('session-1', 1), isNull);
    expect(
      cache.read('session-10', 1),
      isNotNull,
      reason: 'session-10 is a different tutorial',
    );
  });

  test('clear empties everything', () {
    cache.write('session-1', 1, testGeometry());
    cache.write('session-2', 1, testGeometry());

    cache.clear();

    expect(cache.length, 0);
  });

  test('it stores geometry only, never image bytes or paths', () {
    // V3 caches coordinates. There is no guideline picture to cache, and a
    // second on-disk copy would be a source of truth that outlives a schema
    // bump.
    cache.write('session-1', 1, testGeometry());
    final entry = cache.read('session-1', 1)!;

    expect(entry, isA<TutorialV3Geometry>());
    expect(entry.primitives, isNotEmpty);
  });
}
