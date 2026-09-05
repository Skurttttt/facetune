import 'dart:async';

import 'package:facetune/features/saved_looks/data/data_sources/saved_looks_remote_data_source.dart';
import 'package:facetune/features/saved_looks/data/repositories/supabase_saved_looks_repository.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recommendation_response_fixture.dart';

/// How a page of saved looks is hydrated.
///
/// One page is twelve rows and every row needs two signed URLs, so whether
/// those twenty-four calls queue behind each other or run together is the
/// difference between a visible stall at the bottom of the list and none. These
/// tests pin the concurrency without measuring time: the fake never completes a
/// URL until the test says so, so "all of them are waiting at once" is a fact
/// about the call log, not about how fast the machine is.
void main() {
  test('every row is hydrated, in the order the query returned', () async {
    final remote = _FakeRemote(rowCount: 5)..autoComplete = true;
    final repository = SupabaseSavedLooksRepository(remote);

    final page = await repository.loadPage(offset: 0, limit: 12);

    expect(page.items, hasLength(5));
    expect(page.items.map((item) => item.id).toList(), <String>[
      'saved-0',
      'saved-1',
      'saved-2',
      'saved-3',
      'saved-4',
    ]);
    // hasMore is derived from the row count against the limit, unchanged.
    expect(page.hasMore, isFalse);
  });

  test('both signed URLs are still created for every row', () async {
    final remote = _FakeRemote(rowCount: 5)..autoComplete = true;
    final repository = SupabaseSavedLooksRepository(remote);

    final page = await repository.loadPage(offset: 0, limit: 12);

    // Two per row, no more and no fewer: the original and the generated image.
    expect(remote.signedUrlCalls, hasLength(10));
    for (final look in page.items) {
      expect(look.preview.originalImageUrl, contains('/original/'));
      expect(look.preview.generatedImageUrl, contains('/generated/'));
      expect(
        look.preview.originalImageUrl,
        isNot(look.preview.generatedImageUrl),
      );
    }
  });

  test('rows hydrate concurrently rather than one after another', () async {
    final remote = _FakeRemote(rowCount: 5);
    final repository = SupabaseSavedLooksRepository(remote);

    final pending = repository.loadPage(offset: 0, limit: 12);
    // Drain the microtask queue so every row has reached its first await.
    // Nothing has been allowed to complete yet.
    await pumpEventQueue();

    // The regression this guards: serialized hydration parks two calls at a
    // time, so this would read 2 rather than 10.
    expect(remote.inFlight, 10);
    expect(remote.maxInFlight, 10);

    remote.releaseAll();
    final page = await pending;
    expect(page.items, hasLength(5));
  });

  test(
    'a malformed row fails the page rather than returning a partial list',
    () async {
      final remote = _FakeRemote(rowCount: 4, corruptRowIndex: 2)
        ..autoComplete = true;
      final repository = SupabaseSavedLooksRepository(remote);

      await expectLater(
        repository.loadPage(offset: 0, limit: 12),
        throwsA(isA<Object>()),
      );
    },
  );

  test('a signed-URL failure fails the page', () async {
    final remote = _FakeRemote(rowCount: 3)
      ..autoComplete = true
      // Matched against the storage path, which carries the generated id.
      ..failSignedUrlFor = 'generated-1';
    final repository = SupabaseSavedLooksRepository(remote);

    await expectLater(
      repository.loadPage(offset: 0, limit: 12),
      throwsA(isA<Object>()),
    );
  });

  test('an empty page does no work at all', () async {
    final remote = _FakeRemote(rowCount: 0)..autoComplete = true;
    final repository = SupabaseSavedLooksRepository(remote);

    final page = await repository.loadPage(offset: 0, limit: 12);

    expect(page.items, isEmpty);
    expect(remote.signedUrlCalls, isEmpty);
  });

  test('a single saved look still hydrates through the same path', () async {
    final remote = _FakeRemote(rowCount: 1)..autoComplete = true;
    final repository = SupabaseSavedLooksRepository(remote);

    final look = await repository.findByGeneratedImageId('generated-0');

    expect(look, isA<SavedLook>());
    expect(look!.id, 'saved-0');
    expect(remote.signedUrlCalls, hasLength(2));
  });
}

/// A data source that answers from fixtures and holds every signed URL open
/// until the test releases it.
class _FakeRemote implements SavedLooksRemoteDataSource {
  _FakeRemote({required this.rowCount, this.corruptRowIndex});

  final int rowCount;

  /// Index of a row whose generated image is missing, to exercise the failure
  /// path that used to abort the sequential loop.
  final int? corruptRowIndex;

  /// When true, signed URLs resolve immediately instead of parking.
  bool autoComplete = false;

  /// Saved-look id whose signed URL should fail.
  String? failSignedUrlFor;

  final List<String> signedUrlCalls = <String>[];
  final List<Completer<String>> _parked = <Completer<String>>[];
  int inFlight = 0;
  int maxInFlight = 0;

  void releaseAll() {
    for (var index = 0; index < _parked.length; index++) {
      _parked[index].complete(signedUrlCalls[index]);
    }
    _parked.clear();
  }

  List<Map<String, Object?>> get _savedRows => <Map<String, Object?>>[
    for (var index = 0; index < rowCount; index++)
      <String, Object?>{
        'id': 'saved-$index',
        'generated_image_id': 'generated-$index',
        'is_favorite': index.isEven,
        'created_at': '2026-09-0${index + 1}T10:00:00Z',
      },
  ];

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<List<Map<String, Object?>>> selectSavedLooks({
    required int offset,
    required int limit,
  }) async => _savedRows;

  @override
  Future<Map<String, Object?>?> findSavedLook(String generatedImageId) async =>
      _savedRows.firstWhere(
        (row) => row['generated_image_id'] == generatedImageId,
      );

  @override
  Future<List<Map<String, Object?>>> selectGeneratedImages(
    List<String> ids,
  ) async => <Map<String, Object?>>[
    for (final id in ids)
      if (id != 'generated-${corruptRowIndex ?? -1}')
        <String, Object?>{
          'id': id,
          'analysis_id': 'analysis-$id',
          'recommendation_id': 'recommendation-$id',
          'storage_path': 'user/analyses/a/generated/$id.png',
          'generation_number': 1,
          'model_name': 'gemini-3.1-flash-image',
          'prompt_version': 'makeup_preview_v2',
          'created_at': '2026-09-05T10:00:00Z',
        },
  ];

  @override
  Future<List<Map<String, Object?>>> selectRecommendations(
    List<String> ids,
  ) async {
    final plan =
        (validRecommendationResponse['recommendation']! as Map)['plan'];
    return <Map<String, Object?>>[
      for (final id in ids)
        <String, Object?>{
          'id': id,
          'analysis_id': 'analysis-${id.replaceFirst('recommendation-', '')}',
          'makeup_style': 'soft_glam',
          'recommendation_json': plan,
          'model_name': 'gemini-3.6-flash',
          'prompt_version': 'makeup_recommendation_v1',
          'created_at': '2026-09-05T10:00:00Z',
        },
    ];
  }

  @override
  Future<List<Map<String, Object?>>> selectAnalyses(List<String> ids) async =>
      <Map<String, Object?>>[
        for (final id in ids)
          <String, Object?>{
            'id': id,
            'original_image_path':
                'user/analyses/$id/original/${id.hashCode.abs()}.jpg',
            'raw_ai_metadata': <String, Object?>{
              'validation': <String, Object?>{
                'faceCount': 1,
                'lightingAcceptable': true,
                'sharpnessAcceptable': true,
                'faceVisible': true,
                'framingAcceptable': true,
              },
            },
            'face_shape': 'oval',
            'skin_tone': 'medium',
            'undertone': 'warm',
            'eye_shape': 'almond',
            'lip_shape': 'full',
            'hair_color': 'dark_brown',
            'eye_color': 'brown',
            'confidence_json': <String, Object?>{
              'faceShape': 0.91,
              'skinTone': 0.88,
              'undertone': 0.82,
              'eyeShape': 0.90,
              'lipShape': 0.87,
              'hairColor': 0.94,
              'eyeColor': 0.89,
            },
            'model_name': 'gemini-3.6-flash',
            'prompt_version': 'face_analysis_v1',
            'created_at': '2026-08-11T00:00:00Z',
          },
      ];

  @override
  Future<String> createSignedUrl(String storagePath) {
    signedUrlCalls.add('signed:$storagePath');
    if (failSignedUrlFor != null && storagePath.contains(failSignedUrlFor!)) {
      return Future<String>.error(StateError('signing failed'));
    }
    if (autoComplete) return Future<String>.value('signed:$storagePath');
    inFlight += 1;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    final completer = Completer<String>();
    _parked.add(completer);
    return completer.future;
  }

  @override
  Future<void> deleteSavedLook(String savedLookId) async {}

  @override
  Future<Map<String, Object?>> insertSavedLook({
    required String userId,
    required String generatedImageId,
    required bool favorite,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> updateFavorite({
    required String savedLookId,
    required bool favorite,
  }) => throw UnimplementedError();
}
