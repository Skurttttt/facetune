import 'dart:async';
import 'dart:io';

import 'package:facetune/features/makeup_kit/data/data_sources/makeup_kit_look_remote_data_source.dart';
import 'package:facetune/features/makeup_kit/data/data_sources/pdmk_pending_request_store.dart';
import 'package:facetune/features/makeup_kit/data/repositories/pdmk_pending_preview_resumer.dart';
import 'package:facetune/features/makeup_kit/data/repositories/supabase_makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/preview/domain/errors/preview_failure.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _analysisId = '33333333-3333-4333-8333-333333333333';
const _lookA = '22222222-2222-4222-8222-222222222222';
const _lookB = '55555555-5555-4555-8555-555555555555';

KitMakeupRecommendation _look(String id, {String? planId = 'plan-1'}) =>
    KitMakeupRecommendation(
      id: id,
      analysisId: _analysisId,
      styleCode: 'soft_glam',
      selections: const [],
      productSnapshots: const [],
      overallIntensity: 'soft',
      summary: 'A soft look.',
      modelId: 'model',
      promptVersion: 'kit_makeup_recommendation_v3',
      createdAt: DateTime.utc(2026, 9, 27),
      planId: planId,
    );

Map<String, Object?> _accepted(String look, String operationId) => {
  'preview': {
    'id': 'preview-$operationId',
    'mode': 'makeup_kit',
    'analysisId': _analysisId,
    'kitRecommendationId': look,
    'originalImagePath': 'user/analyses/$_analysisId/original/image.jpg',
    'generatedImagePath':
        'user/analyses/$_analysisId/kit-generated/$look/preview_0001.png',
    'generationNumber': 1,
    'modelId': 'gemini-3.1-flash-image',
    'promptVersion': 'kit_makeup_preview_v2',
    'createdAt': '2026-09-27T00:00:00Z',
  },
  'operation': {'id': operationId, 'state': 'accepted'},
};

Map<String, Object?> _inProgress(int retryAfterMs) => {
  'operation': {'state': 'in_progress', 'retryAfterMs': retryAfterMs},
};

MakeupKitLookRemoteFailure _busy(int retryAfterMs) =>
    MakeupKitLookRemoteFailure(
      status: 409,
      code: 'generation_in_progress',
      message: 'still preparing',
      retryable: true,
      operationState: 'in_progress',
      retryAfterMs: retryAfterMs,
    );

const _notReliable = MakeupKitLookRemoteFailure(
  status: 422,
  code: 'preview_not_reliable',
  message:
      "We couldn't create a reliable tutorial-ready version of this look. "
      'Your Makeup Kit is unchanged. Please try generating another preview.',
  retryable: true,
  operationState: 'failed',
);

void main() {
  late Directory root;
  late _Clock clock;
  late _PreviewRemote remote;
  var minted = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pdmk_preview_test');
    clock = _Clock();
    minted = 0;
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  FilePdmkPendingRequestStore store() =>
      FilePdmkPendingRequestStore(directory: () async => root);

  SupabaseMakeupKitLookRepository repository({
    PdmkPendingRequestStore? pendingRequests,
    Duration patience = const Duration(minutes: 8),
  }) => SupabaseMakeupKitLookRepository(
    remote,
    pendingRequests: pendingRequests ?? store(),
    newRequestId: () => 'op-${++minted}',
    now: clock.now,
    delay: clock.sleep,
    previewPatience: patience,
    previewTimeout: const Duration(milliseconds: 50),
  );

  Future<PendingPreviewOperation?> pending([String userId = _userId]) =>
      store().pendingPreview(userId: userId);

  setUp(() => remote = _PreviewRemote(store));

  group('store', () {
    test('a pending preview survives a new instance, one per user', () async {
      final first = store();
      final a = PendingPreviewOperation(
        userId: _userId,
        analysisId: _analysisId,
        kitRecommendationId: _lookA,
        planId: 'plan-1',
        operationId: 'op-a',
        createdAt: DateTime.utc(2026, 9, 27),
      );
      await first.savePlan(
        PendingPlanRequest(
          userId: _userId,
          analysisId: _analysisId,
          styleCode: 'soft_glam',
          planRequestId: 'plan-request',
          createdAt: DateTime.utc(2026, 9, 27),
        ),
      );
      await first.savePreview(a);

      expect((await pending())?.operationId, 'op-a');
      expect(await pending('someone-else'), isNull);
      expect(
        (await store().pendingPlan(
          userId: _userId,
          analysisId: _analysisId,
          styleCode: 'soft_glam',
        ))?.planRequestId,
        'plan-request',
        reason: 'plan entries survive preview writes',
      );

      await first.clearPreview(a);
      expect(await pending(), isNull);
    });
  });

  group('plan-driven preview', () {
    test('a legacy look sends no operation and stores nothing', () async {
      remote.replies.add(_accepted(_lookA, 'server-minted'));

      await repository().generatePreview(
        recommendation: _look(_lookA, planId: null),
      );

      expect(remote.calls.single.operationId, isNull);
      expect(await pending(), isNull);
    });

    test('the operation is saved before it is sent, and cleared on '
        'acceptance', () async {
      remote.replies
        ..add(_inProgress(0))
        ..add(_accepted(_lookA, 'op-1'));

      final preview = await repository().generatePreview(
        recommendation: _look(_lookA),
      );

      expect(preview.id, 'preview-op-1');
      expect(remote.calls.map((c) => c.operationId), ['op-1', 'op-1']);
      expect(remote.storeHeldOperationAtDispatch, [true, true]);
      expect(clock.sleeps, [Duration.zero]);
      expect(await pending(), isNull);
    });

    test('a busy reply waits the server pause and replays the same '
        'operation', () async {
      remote.replies
        ..add(_busy(5000))
        ..add(_accepted(_lookA, 'op-1'));

      await repository().generatePreview(recommendation: _look(_lookA));

      expect(remote.calls.map((c) => c.operationId), ['op-1', 'op-1']);
      expect(clock.sleeps, [const Duration(seconds: 5)]);
    });

    for (final interruption in <String, Object>{
      'a timeout': TimeoutException('slow'),
      'no connection': const SocketException('offline'),
      'a retryable server error': const MakeupKitLookRemoteFailure(
        status: 503,
        code: 'kit_unavailable',
        message: 'later',
        retryable: true,
      ),
    }.entries) {
      test('after ${interruption.key} the same operation continues after a '
          'restart', () async {
        remote.replies
          ..add(interruption.value)
          ..add(_accepted(_lookA, 'op-1'));

        await expectLater(
          repository().generatePreview(recommendation: _look(_lookA)),
          throwsA(isA<PreviewFailure>()),
        );
        expect((await pending())?.operationId, 'op-1');

        // A new repository and store read only the file, as after a restart.
        await repository(
          pendingRequests: store(),
        ).generatePreview(recommendation: _look(_lookA));

        expect(remote.calls.map((c) => c.operationId), ['op-1', 'op-1']);
        expect(
          minted,
          1,
          reason: 'no second operation, so no second reservation',
        );
      });
    }

    test(
      'a failed operation is forgotten and the next request is new',
      () async {
        remote.replies
          ..add(_notReliable)
          ..add(_accepted(_lookA, 'op-2'));

        await expectLater(
          repository().generatePreview(recommendation: _look(_lookA)),
          throwsA(
            isA<PreviewFailure>()
                .having((f) => f.message, 'message', contains('unchanged'))
                .having((f) => f.retryable, 'retryable', isTrue),
          ),
        );
        expect(await pending(), isNull);

        await repository().generatePreview(recommendation: _look(_lookA));
        expect(remote.calls.map((c) => c.operationId), ['op-1', 'op-2']);
      },
    );

    test('an earlier look is finished before a new one starts', () async {
      await store().savePreview(
        PendingPreviewOperation(
          userId: _userId,
          analysisId: _analysisId,
          kitRecommendationId: _lookA,
          planId: 'plan-1',
          operationId: 'op-earlier',
          createdAt: DateTime.utc(2026, 9, 27),
        ),
      );
      remote.replies
        ..add(_accepted(_lookA, 'op-earlier'))
        ..add(_accepted(_lookB, 'op-1'));

      final preview = await repository().generatePreview(
        recommendation: _look(_lookB),
      );

      expect(preview.kitRecommendationId, _lookB);
      expect(remote.calls.map((c) => '${c.look}/${c.operationId}'), [
        '$_lookA/op-earlier',
        '$_lookB/op-1',
      ]);
      expect(await pending(), isNull);
    });

    test(
      'a new look waits while an earlier one is still being prepared',
      () async {
        await store().savePreview(
          PendingPreviewOperation(
            userId: _userId,
            analysisId: _analysisId,
            kitRecommendationId: _lookA,
            planId: 'plan-1',
            operationId: 'op-earlier',
            createdAt: DateTime.utc(2026, 9, 27),
          ),
        );
        remote.replies.addAll([_inProgress(30000), _inProgress(30000)]);

        await expectLater(
          repository(
            patience: const Duration(seconds: 45),
          ).generatePreview(recommendation: _look(_lookB)),
          throwsA(
            isA<PreviewFailure>().having(
              (f) => f.technicalCode,
              'technicalCode',
              'PREVIOUS_PREVIEW_IN_PROGRESS',
            ),
          ),
        );
        expect(remote.calls.every((c) => c.look == _lookA), isTrue);
        expect((await pending())?.operationId, 'op-earlier');
      },
    );

    test('running out of patience keeps the operation', () async {
      remote.replies.addAll([_inProgress(30000), _inProgress(30000)]);

      await expectLater(
        repository(
          patience: const Duration(seconds: 45),
        ).generatePreview(recommendation: _look(_lookA)),
        throwsA(
          isA<PreviewFailure>().having(
            (f) => f.technicalCode,
            'technicalCode',
            'PREVIEW_IN_PROGRESS',
          ),
        ),
      );
      expect((await pending())?.operationId, 'op-1');
    });

    test("another user's pending operation is never used", () async {
      await store().savePreview(
        PendingPreviewOperation(
          userId: 'someone-else',
          analysisId: _analysisId,
          kitRecommendationId: _lookA,
          planId: 'plan-1',
          operationId: 'their-op',
          createdAt: DateTime.utc(2026, 9, 27),
        ),
      );
      remote.replies.add(_accepted(_lookA, 'op-1'));

      await repository().generatePreview(recommendation: _look(_lookA));

      expect(remote.calls.map((c) => c.operationId), ['op-1']);
      expect((await pending('someone-else'))?.operationId, 'their-op');
    });

    test('an operation that cannot be recorded is never sent', () async {
      await expectLater(
        repository(
          pendingRequests: _UnwritableStore(),
        ).generatePreview(recommendation: _look(_lookA)),
        throwsA(
          isA<PreviewFailure>().having(
            (f) => f.technicalCode,
            'technicalCode',
            'LOCAL_REQUEST_STORE_UNAVAILABLE',
          ),
        ),
      );
      expect(remote.calls, isEmpty);
    });

    test('an expired operation is not reported as a changed kit', () async {
      remote.replies.add(
        const MakeupKitLookRemoteFailure(
          status: 409,
          code: 'operation_expired',
          message: 'This preview request expired.',
          retryable: true,
          operationState: 'failed',
        ),
      );

      await expectLater(
        repository().generatePreview(recommendation: _look(_lookA)),
        throwsA(
          isA<PreviewFailure>().having(
            (f) => f.technicalCode,
            'technicalCode',
            'OPERATION_EXPIRED',
          ),
        ),
      );
      expect(await pending(), isNull);
    });
  });

  group('resumer', () {
    PendingPreviewOperation interrupted() => PendingPreviewOperation(
      userId: _userId,
      analysisId: _analysisId,
      kitRecommendationId: _lookA,
      planId: 'plan-1',
      operationId: 'op-interrupted',
      createdAt: DateTime.utc(2026, 9, 27),
    );

    test('continues the interrupted operation to its answer', () async {
      await store().savePreview(interrupted());
      remote.replies.add(_accepted(_lookA, 'op-interrupted'));

      final resumer = PdmkPendingPreviewResumer(remote: remote, store: store());
      await Future.wait([resumer.resume(), resumer.resume()]);

      expect(remote.calls.map((c) => c.operationId), ['op-interrupted']);
      expect(await pending(), isNull);
    });

    test('does nothing when signed out', () async {
      await store().savePreview(interrupted());
      remote.signedIn = false;

      await PdmkPendingPreviewResumer(remote: remote, store: store()).resume();

      expect(remote.calls, isEmpty);
      expect((await pending())?.operationId, 'op-interrupted');
    });

    test('keeps the operation when the answer is not authoritative', () async {
      await store().savePreview(interrupted());
      remote.replies.add(const SocketException('offline'));

      await PdmkPendingPreviewResumer(remote: remote, store: store()).resume();

      expect((await pending())?.operationId, 'op-interrupted');
    });
  });
}

class _Clock {
  DateTime _now = DateTime.utc(2026, 9, 27, 12);
  final sleeps = <Duration>[];

  DateTime now() => _now;

  Future<void> sleep(Duration duration) async {
    sleeps.add(duration);
    _now = _now.add(duration);
  }
}

class _Call {
  const _Call(this.look, this.operationId);
  final String look;
  final String? operationId;
}

class _PreviewRemote implements MakeupKitLookRemoteDataSource {
  _PreviewRemote(this._store);

  final FilePdmkPendingRequestStore Function() _store;
  final replies = <Object>[];
  final calls = <_Call>[];
  final storeHeldOperationAtDispatch = <bool>[];
  bool signedIn = true;

  @override
  String? get currentUserId => signedIn ? _userId : null;

  @override
  Future<Object?> generatePreview({
    required String kitRecommendationId,
    String? operationId,
  }) async {
    calls.add(_Call(kitRecommendationId, operationId));
    if (operationId != null) {
      final held = await _store().pendingPreview(userId: _userId);
      storeHeldOperationAtDispatch.add(held?.operationId == operationId);
    }
    final next = replies.removeAt(0);
    if (next is Map) return next;
    throw next;
  }

  @override
  Future<String> createSignedUrl(String storagePath) async =>
      'https://signed.example/$storagePath';

  @override
  Future<Object?> generateRecommendation({
    required String analysisId,
    required String styleCode,
    String? planRequestId,
  }) => throw UnimplementedError();
}

class _UnwritableStore implements PdmkPendingRequestStore {
  @override
  Future<PendingPreviewOperation?> pendingPreview({
    required String userId,
  }) async => null;

  @override
  Future<void> savePreview(PendingPreviewOperation operation) =>
      Future.error(const FileSystemException('disk full'));

  @override
  Future<void> clearPreview(PendingPreviewOperation operation) async {}

  @override
  Future<PendingPlanRequest?> pendingPlan({
    required String userId,
    required String analysisId,
    required String styleCode,
  }) async => null;

  @override
  Future<void> savePlan(PendingPlanRequest request) async {}

  @override
  Future<void> clearPlan(PendingPlanRequest request) async {}
}
