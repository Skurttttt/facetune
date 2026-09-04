import 'dart:math' as math;

import '../entities/live_check.dart';
import '../entities/live_frame.dart';
import '../entities/live_validation_snapshot.dart';

/// The thresholds the analyzer compares against.
///
/// **These numbers are PROVISIONAL and have not been measured on a device.**
///
/// The Source of Truth requires cadence and acceptance thresholds to be
/// measured rather than invented, and no Android device was available to this
/// work. They are grouped here, in one named type, precisely so a calibration
/// pass can replace them without touching a line of logic — and so nobody reads
/// a scattered magic number as an established fact.
///
/// Until that pass happens on a POCO X3 GT, treat every value below as a
/// starting point chosen to be *permissive*: the local layer's job is to catch
/// obviously unusable frames cheaply, and a tight threshold that rejects a
/// usable frame is worse than a loose one that lets the server decide.
class LiveValidationThresholds {
  const LiveValidationThresholds({
    this.minimumMeanLuma = 55,
    this.warningMeanLuma = 75,
    this.maximumMeanLuma = 235,
    this.warningHighMeanLuma = 215,
    this.minimumSharpness = 6,
    this.warningSharpness = 12,
    this.maximumMotion = 18,
    this.warningMotion = 9,
    this.sampleStride = 4,
  });

  /// Below this mean brightness (0-255) the frame is unusably dark.
  final double minimumMeanLuma;

  /// Below this it is usable but dim.
  final double warningMeanLuma;

  /// Above this the face is blown out.
  final double maximumMeanLuma;

  /// Above this it is usable but hot.
  final double warningHighMeanLuma;

  /// Mean absolute horizontal gradient below which the frame reads as blurred.
  final double minimumSharpness;

  /// Below this it is usable but soft.
  final double warningSharpness;

  /// Mean absolute frame-to-frame luma change above which the camera is moving
  /// too much.
  final double maximumMotion;

  /// Above this there is noticeable movement.
  final double warningMotion;

  /// Sample every Nth pixel and every Nth row.
  ///
  /// A full-resolution pass over a 1080p luma plane is two million reads per
  /// frame for statistics that are stable under sampling. Stride 4 reads about
  /// one pixel in sixteen.
  final int sampleStride;
}

/// One frame's measurements, before they are turned into states.
///
/// Kept separate from the snapshot so a calibration pass can log or compare raw
/// values without re-deriving them.
class LiveFrameMeasurements {
  const LiveFrameMeasurements({
    required this.meanLuma,
    required this.sharpness,
    this.motion,
  });

  /// Mean brightness, 0-255.
  final double meanLuma;

  /// Mean absolute horizontal gradient — higher is sharper.
  final double sharpness;

  /// Mean absolute change from the previous frame, or null when this is the
  /// first frame of a session and there is nothing to compare against.
  final double? motion;
}

/// Evaluates a frame locally. No network, no AI, no persistence.
///
/// Every measurement is ordinary arithmetic over the luma plane:
///
///  * **lighting** — mean brightness, rejected at both ends. Too dark and skin
///    tone is unreadable; blown out and it is equally gone.
///  * **sharpness** — mean absolute horizontal gradient, a cheap stand-in for a
///    focus measure. A blurred frame has little neighbour-to-neighbour change.
///  * **steadiness** — mean absolute difference against the previous frame's
///    samples. Distinguishes a moving camera from a still one.
///
/// This class is deliberately stateless apart from the previous frame's samples,
/// which are the only thing steadiness needs. It holds no image and no history.
class LiveFrameAnalyzer {
  LiveFrameAnalyzer({this.thresholds = const LiveValidationThresholds()});

  final LiveValidationThresholds thresholds;

  /// Downsampled luma from the previous analysed frame, for the motion delta.
  ///
  /// Sample values only — far too sparse to reconstruct an image from, and
  /// discarded on [reset].
  List<int>? _previousSamples;

  /// Forgets the previous frame.
  ///
  /// Called whenever a session starts or stops, so motion is never measured
  /// across a gap — the first frame after a pause would otherwise read as a
  /// huge movement.
  void reset() => _previousSamples = null;

  /// Measures [frame] and maps the result to a snapshot.
  ///
  /// Returns an all-`unknown` snapshot for an unmeasurable frame rather than
  /// throwing: a malformed buffer is a source problem, and the correct user
  /// experience is "no reading yet", not a crash mid-preview.
  LiveValidationSnapshot analyze(LiveFrame frame) {
    final measurements = measure(frame);
    if (measurements == null) return LiveValidationSnapshot.unknown();
    return snapshotOf(measurements);
  }

  /// The raw numbers for [frame], or null when it cannot be measured.
  LiveFrameMeasurements? measure(LiveFrame frame) {
    if (!frame.isMeasurable) return null;

    final stride = frame.stride;
    final step = math.max(1, thresholds.sampleStride);
    final samples = <int>[];
    var lumaTotal = 0;
    var gradientTotal = 0;
    var gradientCount = 0;

    // Only the rows the buffer actually holds. A short buffer is measured over
    // what it has rather than discarded, so a live reading never silently
    // degrades into "not checked yet".
    final rows = frame.usableRows;
    for (var y = 0; y < rows; y += step) {
      final rowStart = y * stride;
      var previousValue = -1;
      for (var x = 0; x < frame.width; x += step) {
        final value = frame.luma[rowStart + x];
        samples.add(value);
        lumaTotal += value;
        if (previousValue >= 0) {
          gradientTotal += (value - previousValue).abs();
          gradientCount += 1;
        }
        previousValue = value;
      }
    }

    if (samples.isEmpty) return null;

    final meanLuma = lumaTotal / samples.length;
    final sharpness = gradientCount == 0 ? 0.0 : gradientTotal / gradientCount;

    double? motion;
    final previous = _previousSamples;
    if (previous != null && previous.length == samples.length) {
      var delta = 0;
      for (var i = 0; i < samples.length; i += 1) {
        delta += (samples[i] - previous[i]).abs();
      }
      motion = delta / samples.length;
    }
    _previousSamples = samples;

    return LiveFrameMeasurements(
      meanLuma: meanLuma,
      sharpness: sharpness,
      motion: motion,
    );
  }

  /// Maps measurements to per-check states.
  LiveValidationSnapshot snapshotOf(LiveFrameMeasurements measurements) =>
      LiveValidationSnapshot({
        LiveCheck.lighting: _lighting(measurements.meanLuma),
        LiveCheck.sharpness: _sharpness(measurements.sharpness),
        LiveCheck.steadiness: _steadiness(measurements.motion),
      });

  LiveCheckState _lighting(double meanLuma) {
    if (meanLuma < thresholds.minimumMeanLuma) return LiveCheckState.fail;
    if (meanLuma > thresholds.maximumMeanLuma) return LiveCheckState.fail;
    if (meanLuma < thresholds.warningMeanLuma) return LiveCheckState.warning;
    if (meanLuma > thresholds.warningHighMeanLuma) {
      return LiveCheckState.warning;
    }
    return LiveCheckState.pass;
  }

  LiveCheckState _sharpness(double sharpness) {
    if (sharpness < thresholds.minimumSharpness) return LiveCheckState.fail;
    if (sharpness < thresholds.warningSharpness) return LiveCheckState.warning;
    return LiveCheckState.pass;
  }

  LiveCheckState _steadiness(double? motion) {
    // The first frame of a session has nothing to compare against. Unknown is
    // the honest answer; guessing "steady" would show a Ready state one frame
    // before anything about motion was actually known.
    if (motion == null) return LiveCheckState.unknown;
    if (motion > thresholds.maximumMotion) return LiveCheckState.fail;
    if (motion > thresholds.warningMotion) return LiveCheckState.warning;
    return LiveCheckState.pass;
  }
}
