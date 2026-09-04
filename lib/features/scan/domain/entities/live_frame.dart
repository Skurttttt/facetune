import 'dart:typed_data';

/// One camera frame, reduced to the only thing the local validator reads.
///
/// Deliberately just the luma (Y) plane. Lighting, focus and motion are all
/// brightness properties, so colour planes would be carried and copied for
/// nothing. Keeping the domain type this narrow also means the validator never
/// holds anything resembling a photograph.
///
/// **Privacy.** A [LiveFrame] is transient: analysed, then dropped. It is never
/// written to disk, never uploaded, never sent to an Edge Function, and never
/// logged — not its bytes, not a hash of them, not a thumbnail. Nothing in this
/// feature may give a frame a longer life than the function call it arrives in.
/// The only image that may enter the secure pipeline is the still the user
/// deliberately captures.
class LiveFrame {
  const LiveFrame({
    required this.luma,
    required this.width,
    required this.height,
    required this.sequence,
    this.bytesPerRow,
  });

  /// The Y plane, one byte per pixel, row-major.
  final Uint8List luma;

  final int width;
  final int height;

  /// Row stride in bytes, when the platform pads rows.
  ///
  /// Android camera buffers are frequently padded, and reading them as if they
  /// were tightly packed silently shears the image — which would corrupt every
  /// measurement taken from it.
  ///
  /// May be null, zero, or smaller than [width]: not every platform reports it,
  /// and `camera_android_camerax` reports `0` for some format/device
  /// combinations. [stride] normalises all three cases.
  final int? bytesPerRow;

  /// A monotonic counter from the frame source.
  ///
  /// Lets a consumer recognise an out-of-order or replayed frame without
  /// depending on wall-clock time.
  final int sequence;

  /// Row stride, normalised.
  ///
  /// A reported stride below [width] cannot be a row stride, so it is treated
  /// as absent rather than believed. LSEP-4A: taking an unreported `0` at face
  /// value made `stride >= width` false on every frame, every frame was
  /// therefore judged unmeasurable, and the three live checks sat at "not
  /// checked yet" for the entire session. The buffer was fine; the arithmetic
  /// describing it was not.
  int get stride {
    final reported = bytesPerRow;
    if (reported == null || reported < width) return width;
    return reported;
  }

  /// How many complete rows the buffer actually contains.
  ///
  /// Clamped rather than assumed. A buffer shorter than `stride * height` is
  /// still perfectly measurable over the rows it does hold, and sampling those
  /// gives a truthful reading — where rejecting the frame outright gives none.
  int get usableRows {
    if (width <= 0 || height <= 0) return 0;
    final rows = luma.length ~/ stride;
    return rows < height ? rows : height;
  }

  /// Whether this frame carries enough data to measure at all.
  bool get isMeasurable => width > 0 && height > 0 && usableRows > 0;
}
