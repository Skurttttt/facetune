import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LSEP-3: live frames stay on the device, and they cost nothing.
///
/// A source-level guard in the pattern `final_preview_model_lock_test.dart`
/// established. The behavioural tests prove the state machine; these prove the
/// things a passing state machine cannot — that no line of this feature reaches
/// the network, an Edge Function, Gemini, or the disk, and that nothing here can
/// fire a shutter on its own.
///
/// The hard locks being enforced:
///
///     LIVE GEMINI CALLS   0
///     LIVE FRAME UPLOADS  0
///     AUTO CAPTURE        NEVER
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const liveFiles = <String>[
    'lib/features/scan/domain/entities/live_check.dart',
    'lib/features/scan/domain/entities/live_frame.dart',
    'lib/features/scan/domain/entities/live_validation_snapshot.dart',
    'lib/features/scan/domain/repositories/live_frame_source.dart',
    'lib/features/scan/domain/services/live_frame_analyzer.dart',
    'lib/features/scan/presentation/controllers/live_scan_controller.dart',
    'lib/features/scan/presentation/controllers/live_scan_state.dart',
  ];

  final sources = <String, String>{
    for (final path in liveFiles) path: source(path),
  };

  /// [input] with comments removed, so a comment explaining a prohibition is not
  /// mistaken for the prohibited thing.
  String executable(String input) => input
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .where((line) {
        final trimmed = line.trimLeft();
        return !trimmed.startsWith('//') && !trimmed.startsWith('///');
      })
      .join('\n');

  group('live frames never leave the device', () {
    test('nothing in the live path imports a network or backend client', () {
      for (final entry in sources.entries) {
        final code = executable(entry.value);
        for (final forbidden in <String>[
          'package:supabase',
          'package:http',
          'dart:io',
          'HttpClient',
          'functions.invoke',
          'Supabase.instance',
          'generativelanguage',
          'gemini',
          'Gemini',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '${entry.key} must not reach $forbidden',
          );
        }
      }
    });

    test('no live frame is written to disk or a path', () {
      for (final entry in sources.entries) {
        final code = executable(entry.value);
        for (final forbidden in <String>[
          'File(',
          'writeAsBytes',
          'getTemporaryDirectory',
          'path_provider',
          'upload',
          'storage',
          'createSignedUrl',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '${entry.key} must not persist a frame via $forbidden',
          );
        }
      }
    });

    test('no frame bytes are logged', () {
      for (final entry in sources.entries) {
        final code = executable(entry.value);
        for (final forbidden in <String>[
          'print(',
          'debugPrint',
          'log(',
          'base64',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '${entry.key} must not log frame data via $forbidden',
          );
        }
      }
    });

    test('the analyzer retains only samples, never a frame', () {
      final analyzer =
          sources['lib/features/scan/domain/services/'
              'live_frame_analyzer.dart']!;
      expect(
        analyzer,
        contains('void reset() => _previousSamples = null'),
        reason: 'the one retained value must be clearable',
      );
      expect(
        executable(analyzer),
        isNot(contains('LiveFrame? _')),
        reason: 'no frame may be held as state',
      );
    });
  });

  group('no auto capture', () {
    test('the live path contains no timer, countdown or shutter', () {
      for (final entry in sources.entries) {
        final code = executable(entry.value);
        for (final forbidden in <String>[
          'Timer(',
          'Timer.periodic',
          'countdown',
          'autoCapture',
          'takePicture',
          'capturePhoto',
          'shutter',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '${entry.key} must contain no $forbidden',
          );
        }
      }
    });

    test('the controller offers no capture method', () {
      final controller =
          sources['lib/features/scan/presentation/controllers/'
              'live_scan_controller.dart']!;
      // Its whole public surface: start, stop, dispose, and read-only getters.
      for (final forbidden in <String>[
        'Future<void> capture',
        'void capture',
        'takePhoto',
      ]) {
        expect(executable(controller), isNot(contains(forbidden)));
      }
    });
  });

  group('the approved scope is what shipped', () {
    test('no face detector or ML runtime was added', () {
      final pubspec = source('pubspec.yaml');
      for (final forbidden in <String>[
        'google_mlkit',
        'tflite',
        'opencv',
        'mediapipe',
        'firebase_ml',
        'face_detection',
      ]) {
        expect(
          pubspec,
          isNot(contains(forbidden)),
          reason: 'only the camera plugin was approved',
        );
      }
    });

    test('the camera plugin is declared', () {
      expect(source('pubspec.yaml'), contains('camera:'));
    });

    test('the check vocabulary claims only what can be measured locally', () {
      final checks =
          sources['lib/features/scan/domain/entities/'
              'live_check.dart']!;
      expect(checks, contains('lighting'));
      expect(checks, contains('sharpness'));
      expect(checks, contains('steadiness'));
      // The three that need a detector are deliberately absent, so no UI can
      // render a locally-derived verdict on them.
      for (final absent in <String>[
        'faceCount',
        'onePerson',
        'faceVisible',
        'headAngle',
      ]) {
        expect(
          executable(checks),
          isNot(contains(absent)),
          reason: '$absent needs a detector that was not approved',
        );
      }
    });

    test('provisional thresholds and cadence are labelled as unmeasured', () {
      expect(
        sources['lib/features/scan/domain/services/'
            'live_frame_analyzer.dart'],
        contains('PROVISIONAL'),
        reason: 'an unmeasured threshold must not read as an established one',
      );
      expect(
        sources['lib/features/scan/presentation/controllers/'
            'live_scan_controller.dart'],
        contains('PROVISIONAL'),
      );
    });
  });
}
