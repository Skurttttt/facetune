/// The output resolution a tutorial guideline image is rendered at.
///
/// The initial V4 quality baseline is locked to [oneK] for every generated
/// step. Resolutions are not mixed within a tutorial: comparing quality across
/// steps rendered at different resolutions would make the baseline
/// meaningless. Higher resolutions exist in this enum so the type can express
/// a future approved change, not so one can be picked opportunistically.
enum TutorialOutputResolution {
  half('0.5K'),
  oneK('1K'),
  twoK('2K'),
  fourK('4K');

  const TutorialOutputResolution(this.code);

  final String code;

  static TutorialOutputResolution? fromCode(String code) {
    for (final resolution in values) {
      if (resolution.code == code) return resolution;
    }
    return null;
  }
}

/// The server-resolved AI configuration a tutorial session was generated
/// under.
///
/// This is a **read-only report**, not a request. The client never selects a
/// model, a prompt version, or a resolution — those are owned server-side, and
/// letting the client choose would allow it to request an arbitrary Gemini
/// model or an expensive resolution. Every field here is populated from what
/// the server says it used, and exists so the app can display provenance,
/// invalidate caches when a version changes, and record what produced a
/// historical tutorial.
///
/// That is also why the model id fields are required with no default: shipping
/// a default model id in Flutter would embed an unverified model in the client
/// and quietly disagree with the server the moment either changed.
class TutorialAiConfiguration {
  const TutorialAiConfiguration({
    required this.manifestModelId,
    required this.manifestPromptVersion,
    required this.manifestSchemaVersion,
    required this.guidelineModelId,
    required this.guidelinePromptVersion,
    this.outputResolution = defaultOutputResolution,
  });

  /// The locked initial V4 baseline resolution for every generated tutorial
  /// step.
  ///
  /// Centralised here rather than repeated per category, so the baseline can
  /// only ever be changed in one place — and only with evidence and explicit
  /// approval.
  static const TutorialOutputResolution defaultOutputResolution =
      TutorialOutputResolution.oneK;

  /// The multimodal model that compared the original selfie against the
  /// canonical final preview to decide category presence.
  final String manifestModelId;
  final String manifestPromptVersion;
  final String manifestSchemaVersion;

  /// The image model that rendered the guideline overlays.
  ///
  /// A different responsibility from the manifest analyzer: this model renders
  /// the guideline for one already-approved category and never decides which
  /// categories are included.
  final String guidelineModelId;
  final String guidelinePromptVersion;

  final TutorialOutputResolution outputResolution;
}
