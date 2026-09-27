import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A plan request the client has committed to but not yet seen resolved.
///
/// Only a replay handle. The server's plan, recommendation, and entitlement
/// state stay authoritative; this record exists so a lost response, a killed
/// app, or a restart re-sends the same [planRequestId] instead of asking for a
/// second plan.
class PendingPlanRequest {
  const PendingPlanRequest({
    required this.userId,
    required this.analysisId,
    required this.styleCode,
    required this.planRequestId,
    required this.createdAt,
  });

  final String userId;
  final String analysisId;
  final String styleCode;
  final String planRequestId;
  final DateTime createdAt;

  bool matches({
    required String userId,
    required String analysisId,
    required String styleCode,
  }) =>
      this.userId == userId &&
      this.analysisId == analysisId &&
      this.styleCode == styleCode;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'analysisId': analysisId,
    'styleCode': styleCode,
    'planRequestId': planRequestId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static PendingPlanRequest? fromJson(Object? value) {
    if (value is! Map) return null;
    final userId = value['userId'];
    final analysisId = value['analysisId'];
    final styleCode = value['styleCode'];
    final planRequestId = value['planRequestId'];
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (userId is! String ||
        analysisId is! String ||
        styleCode is! String ||
        planRequestId is! String ||
        createdAt == null) {
      return null;
    }
    return PendingPlanRequest(
      userId: userId,
      analysisId: analysisId,
      styleCode: styleCode,
      planRequestId: planRequestId,
      createdAt: createdAt.toUtc(),
    );
  }
}

/// Durable storage for pending plan-driven My Makeup Kit requests.
///
/// A save must complete before the request it describes is sent, so that a
/// crash after dispatch always finds the identifier again.
abstract interface class PdmkPendingRequestStore {
  /// The pending plan request for exactly this user, analysis, and style.
  Future<PendingPlanRequest?> pendingPlan({
    required String userId,
    required String analysisId,
    required String styleCode,
  });

  /// Durably records [request], replacing any entry for the same context.
  Future<void> savePlan(PendingPlanRequest request);

  /// Forgets [request], and only that request.
  Future<void> clearPlan(PendingPlanRequest request);
}

/// A single versioned JSON file in the app's private support directory.
///
/// Writes go to a temporary file that is flushed to disk and then renamed over
/// the real one, so a crash leaves either the old or the new contents, never a
/// torn file. Operations run one at a time. Keys this version does not own are
/// kept on every write, so a later version's entries survive.
class FilePdmkPendingRequestStore implements PdmkPendingRequestStore {
  FilePdmkPendingRequestStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _schemaVersion = 1;
  static const _fileName = 'pending_requests_v1.json';

  final Future<Directory> Function() _directory;
  Future<void> _tail = Future<void>.value();

  @override
  Future<PendingPlanRequest?> pendingPlan({
    required String userId,
    required String analysisId,
    required String styleCode,
  }) => _serial(() async {
    final document = await _read();
    for (final entry in _plans(document)) {
      if (entry.matches(
        userId: userId,
        analysisId: analysisId,
        styleCode: styleCode,
      )) {
        return entry;
      }
    }
    return null;
  });

  @override
  Future<void> savePlan(PendingPlanRequest request) => _serial(() async {
    final document = await _read();
    final plans = _plans(document)
        .where(
          (entry) => !entry.matches(
            userId: request.userId,
            analysisId: request.analysisId,
            styleCode: request.styleCode,
          ),
        )
        .toList()
      ..add(request);
    await _write(document, plans);
  });

  @override
  Future<void> clearPlan(PendingPlanRequest request) => _serial(() async {
    final document = await _read();
    final plans = _plans(document);
    final remaining = plans
        .where(
          (entry) =>
              entry.userId != request.userId ||
              entry.planRequestId != request.planRequestId,
        )
        .toList();
    if (remaining.length == plans.length) return;
    await _write(document, remaining);
  });

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<File> _file() async {
    final root = await _directory();
    return File('${root.path}${Platform.pathSeparator}pdmk'
        '${Platform.pathSeparator}$_fileName');
  }

  Future<Map<String, Object?>> _read() async {
    final file = await _file();
    if (!await file.exists()) return <String, Object?>{};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Fall through to quarantine.
    }
    // Only external tampering can produce this, because writes are atomic.
    // Keep the evidence and start empty rather than failing every request.
    await file.rename('${file.path}.corrupt');
    return <String, Object?>{};
  }

  List<PendingPlanRequest> _plans(Map<String, Object?> document) {
    final values = document['plans'];
    if (values is! List) return <PendingPlanRequest>[];
    return values
        .map(PendingPlanRequest.fromJson)
        .whereType<PendingPlanRequest>()
        .toList();
  }

  Future<void> _write(
    Map<String, Object?> document,
    List<PendingPlanRequest> plans,
  ) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final contents = jsonEncode(<String, Object?>{
      ...document,
      'schemaVersion': _schemaVersion,
      'plans': plans.map((entry) => entry.toJson()).toList(),
    });
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }
}
