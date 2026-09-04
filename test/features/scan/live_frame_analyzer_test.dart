import 'dart:typed_data';

import 'package:facetune/features/scan/domain/entities/live_check.dart';
import 'package:facetune/features/scan/domain/entities/live_frame.dart';
import 'package:facetune/features/scan/domain/entities/live_validation_snapshot.dart';
import 'package:facetune/features/scan/domain/services/live_frame_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A frame of uniform brightness. Flat, so it has no detail at all.
LiveFrame _flat(
  int value, {
  int width = 64,
  int height = 64,
  int sequence = 0,
}) => LiveFrame(
  luma: Uint8List(width * height)..fillRange(0, width * height, value),
  width: width,
  height: height,
  sequence: sequence,
);

/// A frame of vertical stripes, so consecutive sampled pixels differ by
/// [contrast]. Sharpness is a horizontal-gradient measure, and the analyzer
/// samples every 4th pixel, so the stripe period is chosen to survive that.
LiveFrame _striped(
  int base,
  int contrast, {
  int width = 64,
  int height = 64,
  int sequence = 0,
}) {
  final bytes = Uint8List(width * height);
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      // Period 8 => sampled columns (stride 4) alternate base / base+contrast.
      final high = (x ~/ 4).isEven;
      bytes[y * width + x] = high ? base : (base + contrast).clamp(0, 255);
    }
  }
  return LiveFrame(
    luma: bytes,
    width: width,
    height: height,
    sequence: sequence,
  );
}

void main() {
  group('measurement', () {
    test('mean luma reflects a flat frame', () {
      final measurements = LiveFrameAnalyzer().measure(_flat(120));
      expect(measurements, isNotNull);
      expect(measurements!.meanLuma, closeTo(120, 0.01));
    });

    test('a flat frame has no sharpness', () {
      final measurements = LiveFrameAnalyzer().measure(_flat(120));
      expect(measurements!.sharpness, 0);
    });

    test('a striped frame has sharpness proportional to contrast', () {
      final soft = LiveFrameAnalyzer().measure(_striped(120, 5))!;
      final crisp = LiveFrameAnalyzer().measure(_striped(120, 60))!;
      expect(crisp.sharpness, greaterThan(soft.sharpness));
    });

    test('the first frame of a session reports no motion', () {
      final measurements = LiveFrameAnalyzer().measure(_flat(120));
      expect(measurements!.motion, isNull);
    });

    test('an identical second frame reports zero motion', () {
      final analyzer = LiveFrameAnalyzer()..measure(_flat(120));
      final second = analyzer.measure(_flat(120, sequence: 1));
      expect(second!.motion, 0);
    });

    test('a changed second frame reports the mean absolute delta', () {
      final analyzer = LiveFrameAnalyzer()..measure(_flat(100));
      final second = analyzer.measure(_flat(130, sequence: 1));
      expect(second!.motion, closeTo(30, 0.01));
    });

    test('reset forgets the previous frame so motion is unknown again', () {
      final analyzer = LiveFrameAnalyzer()..measure(_flat(100));
      analyzer.reset();
      final next = analyzer.measure(_flat(130, sequence: 1));
      expect(
        next!.motion,
        isNull,
        reason: 'motion must not be measured across a session gap',
      );
    });

    test('a truncated buffer is unmeasurable rather than throwing', () {
      final frame = LiveFrame(
        luma: Uint8List(10),
        width: 64,
        height: 64,
        sequence: 0,
      );
      expect(frame.isMeasurable, isFalse);
      expect(LiveFrameAnalyzer().measure(frame), isNull);
      expect(
        LiveFrameAnalyzer().analyze(frame).states.values,
        everyElement(LiveCheckState.unknown),
      );
    });

    test('a padded row stride is honoured', () {
      // 64 visible columns in an 80-byte row. Read as tightly packed, the image
      // would shear and every measurement would be wrong.
      const width = 64;
      const stride = 80;
      const height = 8;
      final bytes = Uint8List(stride * height);
      for (var y = 0; y < height; y += 1) {
        for (var x = 0; x < stride; x += 1) {
          bytes[y * stride + x] = x < width ? 100 : 255;
        }
      }
      final frame = LiveFrame(
        luma: bytes,
        width: width,
        height: height,
        bytesPerRow: stride,
        sequence: 0,
      );
      final measurements = LiveFrameAnalyzer().measure(frame);
      expect(
        measurements!.meanLuma,
        closeTo(100, 0.01),
        reason: 'padding bytes must not be sampled',
      );
    });
  });

  group('threshold mapping', () {
    const thresholds = LiveValidationThresholds();

    test('a dark frame fails lighting', () {
      final snapshot = LiveFrameAnalyzer().analyze(_striped(5, 40));
      expect(snapshot.stateOf(LiveCheck.lighting), LiveCheckState.fail);
    });

    test('a dim frame warns on lighting', () {
      // A striped frame's mean sits halfway up the contrast, so the base is
      // offset to land the *mean* between the fail and warn thresholds.
      const contrast = 40;
      final targetMean =
          (thresholds.minimumMeanLuma + thresholds.warningMeanLuma) / 2;
      final base = (targetMean - contrast / 2).round();
      final snapshot = LiveFrameAnalyzer().analyze(_striped(base, contrast));
      expect(snapshot.stateOf(LiveCheck.lighting), LiveCheckState.warning);
    });

    test('a well-lit frame passes lighting', () {
      final snapshot = LiveFrameAnalyzer().analyze(_striped(120, 40));
      expect(snapshot.stateOf(LiveCheck.lighting), LiveCheckState.pass);
    });

    test('a blown-out frame fails lighting', () {
      final snapshot = LiveFrameAnalyzer().analyze(_flat(250));
      expect(snapshot.stateOf(LiveCheck.lighting), LiveCheckState.fail);
    });

    test('a flat frame fails sharpness', () {
      final snapshot = LiveFrameAnalyzer().analyze(_flat(120));
      expect(snapshot.stateOf(LiveCheck.sharpness), LiveCheckState.fail);
    });

    test('a detailed frame passes sharpness', () {
      final snapshot = LiveFrameAnalyzer().analyze(_striped(120, 60));
      expect(snapshot.stateOf(LiveCheck.sharpness), LiveCheckState.pass);
    });

    test('steadiness is unknown on the first frame and passes when still', () {
      final analyzer = LiveFrameAnalyzer();
      final first = analyzer.analyze(_striped(120, 60));
      expect(first.stateOf(LiveCheck.steadiness), LiveCheckState.unknown);

      final second = analyzer.analyze(_striped(120, 60, sequence: 1));
      expect(second.stateOf(LiveCheck.steadiness), LiveCheckState.pass);
    });

    test('a large frame-to-frame change fails steadiness', () {
      final analyzer = LiveFrameAnalyzer()..analyze(_striped(80, 60));
      final moved = analyzer.analyze(_striped(180, 60, sequence: 1));
      expect(moved.stateOf(LiveCheck.steadiness), LiveCheckState.fail);
    });
  });

  group('snapshot semantics', () {
    test('a first frame is never ready, because motion is unmeasured', () {
      final snapshot = LiveFrameAnalyzer().analyze(_striped(120, 60));
      expect(snapshot.stateOf(LiveCheck.lighting), LiveCheckState.pass);
      expect(snapshot.stateOf(LiveCheck.sharpness), LiveCheckState.pass);
      expect(snapshot.isReady, isFalse, reason: 'unknown is not readiness');
      expect(snapshot.eligibility, LiveCaptureEligibility.allowedWithWarning);
    });

    test('a good second frame is ready and eligible', () {
      final analyzer = LiveFrameAnalyzer()..analyze(_striped(120, 60));
      final snapshot = analyzer.analyze(_striped(120, 60, sequence: 1));
      expect(snapshot.isReady, isTrue);
      expect(snapshot.primaryIssue, isNull);
      expect(snapshot.eligibility, LiveCaptureEligibility.ready);
      expect(snapshot.passingCount, snapshot.checkCount);
    });

    test('a failure blocks capture', () {
      final analyzer = LiveFrameAnalyzer()..analyze(_flat(2));
      final snapshot = analyzer.analyze(_flat(2, sequence: 1));
      expect(snapshot.hasFailure, isTrue);
      expect(snapshot.eligibility, LiveCaptureEligibility.blocked);
    });

    test('lighting outranks the other issues for guidance', () {
      // Dark and flat: lighting and sharpness both fail, and the user is told
      // about lighting, because it is the one they can act on.
      final analyzer = LiveFrameAnalyzer()..analyze(_flat(10));
      final snapshot = analyzer.analyze(_flat(10, sequence: 1));
      expect(snapshot.stateOf(LiveCheck.lighting), LiveCheckState.fail);
      expect(snapshot.stateOf(LiveCheck.sharpness), LiveCheckState.fail);
      expect(snapshot.primaryIssue, LiveCheck.lighting);
    });

    test('a failure outranks a warning even from a lower-priority check', () {
      // Lighting only warns; sharpness fails. Lighting sits higher in the
      // priority order, but guidance must name the unusable thing, not the
      // improvable one.
      const snapshot = LiveValidationSnapshot({
        LiveCheck.lighting: LiveCheckState.warning,
        LiveCheck.sharpness: LiveCheckState.fail,
        LiveCheck.steadiness: LiveCheckState.pass,
      });
      expect(snapshot.primaryIssue, LiveCheck.sharpness);
      expect(snapshot.eligibility, LiveCaptureEligibility.blocked);
    });

    test('among warnings alone, priority order decides', () {
      const snapshot = LiveValidationSnapshot({
        LiveCheck.lighting: LiveCheckState.warning,
        LiveCheck.sharpness: LiveCheckState.warning,
        LiveCheck.steadiness: LiveCheckState.warning,
      });
      expect(snapshot.primaryIssue, LiveCheck.lighting);
      expect(snapshot.eligibility, LiveCaptureEligibility.allowedWithWarning);
    });

    test('an unmeasured snapshot is not ready and names no issue', () {
      final snapshot = LiveValidationSnapshot.unknown();
      expect(snapshot.isReady, isFalse);
      expect(snapshot.primaryIssue, isNull);
      expect(snapshot.passingCount, 0);
    });
  });
}
