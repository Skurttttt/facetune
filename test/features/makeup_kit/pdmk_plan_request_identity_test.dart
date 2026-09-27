import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:facetune/features/makeup_kit/data/data_sources/makeup_kit_look_remote_data_source.dart';
import 'package:facetune/features/makeup_kit/data/data_sources/pdmk_pending_request_store.dart';
import 'package:facetune/features/makeup_kit/data/repositories/supabase_makeup_kit_look_repository.dart';
import 'package:facetune/features/preview/domain/errors/preview_failure.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _otherUserId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _analysisId = '33333333-3333-4333-8333-333333333333';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pdmk_store_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  FilePdmkPendingRequestStore store() =>
      FilePdmkPendingRequestStore(directory: () async => root);

  File storeFile() => File(
    '${root.path}${Platform.pathSeparator}pdmk'
    '${Platform.pathSeparator}pending_requests_v1.json',
  );

  PendingPlanRequest request({
    String userId = _userId,
    String styleCode = 'soft_glam',
    String id = 'request-1',
  }) => PendingPlanRequest(
    userId: userId,
    analysisId: _analysisId,
    styleCode: styleCode,
    planRequestId: id,
    createdAt: DateTime.utc(2026, 9, 27),
  );

  group('FilePdmkPendingRequestStore', () {
    test('a saved request survives a new store instance', () async {
      await store().savePlan(request());

      // A fresh instance reads only the file, as after process death.
      final restored = await store().pendingPlan(
        userId: _userId,
        analysisId: _analysisId,
        styleCode: 'soft_glam',
      );

      expect(restored?.planRequestId, 'request-1');
      expect(restored?.createdAt, DateTime.utc(2026, 9, 27));
    });

    test('a request is restored only for its own user and context', () async {
      await store().savePlan(request());

      final other = store();
      expect(
        await other.pendingPlan(
          userId: _otherUserId,
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        ),
        isNull,
      );
      expect(
        await other.pendingPlan(
          userId: _userId,
          analysisId: _analysisId,
          styleCode: 'natural',
        ),
        isNull,
      );
    });

    test('clearing forgets only that request', () async {
      final instance = store();
      await instance.savePlan(request());
      await instance.savePlan(request(styleCode: 'natural', id: 'request-2'));
      await instance.savePlan(request(userId: _otherUserId, id: 'request-1'));

      await instance.clearPlan(request());

      final restored = store();
      expect(
        await restored.pendingPlan(
          userId: _userId,
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        ),
        isNull,
      );
      expect(
        (await restored.pendingPlan(
          userId: _userId,
          analysisId: _analysisId,
          styleCode: 'natural',
        ))?.planRequestId,
        'request-2',
      );
      expect(
        (await restored.pendingPlan(
          userId: _otherUserId,
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        ))?.planRequestId,
        'request-1',
      );
    });

    test('writes are atomic and keep keys this version does not own', () async {
      storeFile().parent.createSync(recursive: true);
      storeFile().writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'plans': <Object?>[],
          'futureEntries': [
            {'operationId': 'kept'},
          ],
        }),
      );

      await store().savePlan(request());

      final decoded =
          jsonDecode(storeFile().readAsStringSync()) as Map<String, Object?>;
      expect(decoded['futureEntries'], [
        {'operationId': 'kept'},
      ]);
      expect((decoded['plans']! as List).length, 1);
      expect(File('${storeFile().path}.tmp').existsSync(), isFalse);
    });

    test('an unreadable file is quarantined, not fatal', () async {
      storeFile().parent.createSync(recursive: true);
      storeFile().writeAsStringSync('{not json');

      expect(
        await store().pendingPlan(
          userId: _userId,
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        ),
        isNull,
      );
      expect(File('${storeFile().path}.corrupt').existsSync(), isTrue);
    });
  });

  group('plan request lifecycle', () {
    late _ScriptedRemote remote;
    late FilePdmkPendingRequestStore requests;
    var minted = 0;

    SupabaseMakeupKitLookRepository repository({
      PdmkPendingRequestStore? pendingRequests,
    }) => SupabaseMakeupKitLookRepository(
      remote,
      pendingRequests: pendingRequests ?? requests,
      newRequestId: () => 'minted-${++minted}',
      now: () => DateTime.utc(2026, 9, 27),
      recommendationTimeout: const Duration(milliseconds: 50),
    );

    Future<PendingPlanRequest?> pending([String styleCode = 'soft_glam']) =>
        store().pendingPlan(
          userId: _userId,
          analysisId: _analysisId,
          styleCode: styleCode,
        );

    setUp(() {
      minted = 0;
      remote = _ScriptedRemote(storeFile);
      requests = store();
    });

    test('the id is saved durably before the request is sent', () async {
      remote.responses.add(_success('soft_glam'));

      await repository().generateRecommendation(
        analysisId: _analysisId,
        styleCode: 'soft_glam',
      );

      expect(remote.sentIds, ['minted-1']);
      expect(remote.fileHeldIdAtDispatch, [true]);
    });

    test('success clears the request', () async {
      remote.responses.add(_success('soft_glam'));

      await repository().generateRecommendation(
        analysisId: _analysisId,
        styleCode: 'soft_glam',
      );

      expect(await pending(), isNull);
    });

    for (final failure in <String, Object>{
      'a timeout': TimeoutException('slow'),
      'no connection': const SocketException('offline'),
      'a retryable server failure': const MakeupKitLookRemoteFailure(
        status: 503,
        code: 'kit_unavailable',
        message: 'unavailable',
        retryable: true,
      ),
      'an invalid model answer': const MakeupKitLookRemoteFailure(
        status: 502,
        code: 'invalid_ai_plan',
        message: 'invalid',
        retryable: true,
      ),
      'rate limiting': const MakeupKitLookRemoteFailure(
        status: 429,
        code: 'rate_limited',
        message: 'later',
        retryable: true,
      ),
      'an expired session': const MakeupKitLookRemoteFailure(
        status: 401,
        code: 'invalid_session',
        message: 'sign in',
        retryable: false,
      ),
    }.entries) {
      test('after ${failure.key} the same id is sent again', () async {
        remote.responses
          ..add(failure.value)
          ..add(_success('soft_glam'));

        await expectLater(
          repository().generateRecommendation(
            analysisId: _analysisId,
            styleCode: 'soft_glam',
          ),
          throwsA(isA<PreviewFailure>()),
        );
        expect((await pending())?.planRequestId, 'minted-1');

        // A new repository reads only the file, as after an app restart.
        await repository(pendingRequests: store()).generateRecommendation(
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        );

        expect(remote.sentIds, ['minted-1', 'minted-1']);
        expect(minted, 1);
      });
    }

    test('a request that hangs past the timeout keeps its id', () async {
      remote.hang = true;

      await expectLater(
        repository().generateRecommendation(
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        ),
        throwsA(
          isA<PreviewFailure>().having(
            (failure) => failure.technicalCode,
            'technicalCode',
            'GEMINI_TIMEOUT',
          ),
        ),
      );
      expect((await pending())?.planRequestId, 'minted-1');
    });

    for (final terminal in <String, Object>{
      'a request conflict': const MakeupKitLookRemoteFailure(
        status: 409,
        code: 'plan_request_conflict',
        message: 'used',
        retryable: false,
      ),
      'an invalid request': const MakeupKitLookRemoteFailure(
        status: 400,
        code: 'invalid_style',
        message: 'bad',
        retryable: false,
      ),
      'a missing analysis': const MakeupKitLookRemoteFailure(
        status: 404,
        code: 'analysis_not_found',
        message: 'gone',
        retryable: false,
      ),
    }.entries) {
      test('${terminal.key} ends the request', () async {
        remote.responses
          ..add(terminal.value)
          ..add(_success('soft_glam'));

        await expectLater(
          repository().generateRecommendation(
            analysisId: _analysisId,
            styleCode: 'soft_glam',
          ),
          throwsA(isA<PreviewFailure>()),
        );
        expect(await pending(), isNull);

        await repository().generateRecommendation(
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        );
        expect(remote.sentIds, ['minted-1', 'minted-2']);
      });
    }

    test('a request conflict is not reported as a changed kit', () async {
      remote.responses.add(
        const MakeupKitLookRemoteFailure(
          status: 409,
          code: 'plan_request_conflict',
          message: 'used',
          retryable: false,
        ),
      );

      await expectLater(
        repository().generateRecommendation(
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        ),
        throwsA(
          isA<PreviewFailure>()
              .having(
                (failure) => failure.technicalCode,
                'technicalCode',
                'PLAN_REQUEST_CONFLICT',
              )
              .having((failure) => failure.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('each look context has its own request', () async {
      remote.responses
        ..add(_success('soft_glam'))
        ..add(_success('natural'));

      await repository().generateRecommendation(
        analysisId: _analysisId,
        styleCode: 'soft_glam',
      );
      await repository().generateRecommendation(
        analysisId: _analysisId,
        styleCode: 'natural',
      );

      expect(remote.sentIds, ['minted-1', 'minted-2']);
    });

    test('a request that cannot be recorded is never sent', () async {
      await expectLater(
        repository(
          pendingRequests: _FailingStore(),
        ).generateRecommendation(analysisId: _analysisId, styleCode: 'natural'),
        throwsA(
          isA<PreviewFailure>().having(
            (failure) => failure.technicalCode,
            'technicalCode',
            'LOCAL_REQUEST_STORE_UNAVAILABLE',
          ),
        ),
      );
      expect(remote.sentIds, isEmpty);
    });

    test('without a store the legacy request is unchanged', () async {
      remote.responses.add(_success('soft_glam'));

      await SupabaseMakeupKitLookRepository(
        remote,
      ).generateRecommendation(analysisId: _analysisId, styleCode: 'soft_glam');

      expect(remote.sentIds, [null]);
    });
  });
}

Map<String, Object?> _success(String style) => {
  'recommendation': {
    'id': '22222222-2222-4222-8222-222222222222',
    'analysisId': _analysisId,
    'style': style,
    'plan': {
      'selections': [
        {
          'productId': '11111111-1111-4111-8111-111111111111',
          'category': 'lipstick',
          'colorHex': '#A45B67',
          'finish': 'matte',
          'placement': 'Across lips',
          'technique': 'Apply lightly',
          'intensity': 'soft',
        },
      ],
      'overallIntensity': 'soft',
      'summary': 'A soft look.',
    },
    'productSnapshot': [
      {
        'productId': '11111111-1111-4111-8111-111111111111',
        'category': 'lipstick',
        'colorHex': '#A45B67',
        'finish': 'matte',
      },
    ],
    'modelId': 'model',
    'promptVersion': 'kit_makeup_recommendation_v3',
    'createdAt': '2026-09-27T00:00:00Z',
  },
};

class _ScriptedRemote implements MakeupKitLookRemoteDataSource {
  _ScriptedRemote(this._storeFile);

  final File Function() _storeFile;
  final responses = <Object>[];
  final sentIds = <String?>[];
  final fileHeldIdAtDispatch = <bool>[];
  bool hang = false;

  @override
  String? get currentUserId => _userId;

  @override
  Future<Object?> generateRecommendation({
    required String analysisId,
    required String styleCode,
    String? planRequestId,
  }) async {
    sentIds.add(planRequestId);
    final file = _storeFile();
    fileHeldIdAtDispatch.add(
      planRequestId != null &&
          file.existsSync() &&
          file.readAsStringSync().contains(planRequestId),
    );
    if (hang) return Completer<Object?>().future;
    final next = responses.removeAt(0);
    if (next is Map) return next;
    throw next;
  }

  @override
  Future<Object?> generatePreview({
    required String kitRecommendationId,
    String? operationId,
  }) => throw UnimplementedError();

  @override
  Future<String> createSignedUrl(String storagePath) =>
      throw UnimplementedError();
}

class _FailingStore implements PdmkPendingRequestStore {
  @override
  Future<PendingPlanRequest?> pendingPlan({
    required String userId,
    required String analysisId,
    required String styleCode,
  }) async => null;

  @override
  Future<void> savePlan(PendingPlanRequest request) =>
      Future.error(const FileSystemException('disk full'));

  @override
  Future<void> clearPlan(PendingPlanRequest request) async {}

  @override
  Future<PendingPreviewOperation?> pendingPreview({
    required String userId,
  }) async => null;

  @override
  Future<void> savePreview(PendingPreviewOperation operation) =>
      Future.error(const FileSystemException('disk full'));

  @override
  Future<void> clearPreview(PendingPreviewOperation operation) async {}
}
