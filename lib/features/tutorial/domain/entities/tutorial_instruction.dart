import 'tutorial_guide_type.dart';

/// One numbered instruction in a tutorial step.
///
/// Each item is tied to a [guideType], which is what connects the sentence to
/// something the user can actually see in the guideline image. That link is the
/// point of the type: an instruction that references no guide is either
/// describing a marking that was never drawn, or is generic makeup advice that
/// does not belong in a reconstruction guide.
///
/// The numbering is a list position, nothing more. It is rendered by Flutter
/// beside the text and is deliberately *not* placed on the face — doing that
/// would require per-step coordinates, which would mean face geometry, which
/// V4 does not have and must not acquire for decoration.
class TutorialInstructionStep {
  const TutorialInstructionStep({
    required this.sequence,
    required this.guideType,
    required this.shortTitle,
    required this.instruction,
  });

  /// 1-based position in the step's instruction list.
  final int sequence;

  /// The marking in the guideline image this instruction refers to.
  final TutorialGuideType guideType;

  /// A two- or three-word heading, e.g. "Start" or "Blend outward".
  final String shortTitle;

  /// The instruction itself: one short, action-oriented sentence.
  final String instruction;
}

/// The ordered instruction list for one tutorial step.
///
/// Constructed through [TutorialInstructionSequence.from], which enforces the
/// two invariants that make the numbering trustworthy:
///
///  * sequences are exactly `1..n`, contiguous and ascending — a list that
///    renders "① ② ④" is a bug the user can see, and it is far cheaper to
///    reject it here than to notice it on a device;
///  * at most [maximumSteps] items — the guidance is 2–4 concise instructions,
///    and a step that needs eight is describing the whole look rather than one
///    category.
///
/// [empty] is a legitimate state, not a failure: it is what a step honestly
/// looks like when no instruction copy has been authored for it. Nothing here
/// invents wording to fill the gap.
class TutorialInstructionSequence {
  const TutorialInstructionSequence._(this.steps);

  /// The upper bound on instructions in one step.
  static const int maximumSteps = 4;

  /// The lower bound of the *guidance*, not of this type.
  ///
  /// A single-instruction step is representable and sometimes correct — some
  /// categories really are one action. This constant exists so authoring and
  /// QA can check against the target without the contract silently rejecting a
  /// truthful one-line step.
  static const int recommendedMinimumSteps = 2;

  /// A step with no authored instructions.
  static const TutorialInstructionSequence empty =
      TutorialInstructionSequence._(<TutorialInstructionStep>[]);

  final List<TutorialInstructionStep> steps;

  /// Builds a validated sequence from [steps].
  ///
  /// Throws [ArgumentError] when the sequence numbers are not exactly `1..n`
  /// in ascending order, or when there are more than [maximumSteps] items. An
  /// empty list is accepted and yields [empty].
  factory TutorialInstructionSequence.from(
    List<TutorialInstructionStep> steps,
  ) {
    if (steps.isEmpty) return empty;
    if (steps.length > maximumSteps) {
      throw ArgumentError.value(
        steps.length,
        'steps',
        'A tutorial step may show at most $maximumSteps instructions.',
      );
    }
    for (var index = 0; index < steps.length; index += 1) {
      final expected = index + 1;
      if (steps[index].sequence != expected) {
        throw ArgumentError.value(
          steps[index].sequence,
          'steps[$index].sequence',
          'Instruction sequences must be contiguous and ascending from 1; '
              'expected $expected.',
        );
      }
    }
    return TutorialInstructionSequence._(
      List<TutorialInstructionStep>.unmodifiable(steps),
    );
  }

  bool get isEmpty => steps.isEmpty;

  bool get isNotEmpty => steps.isNotEmpty;

  int get length => steps.length;

  /// Whether the list falls inside the 2–4 authoring target.
  ///
  /// Reported rather than enforced, so QA can see which steps sit outside the
  /// guidance without a truthful one-instruction step being unrepresentable.
  bool get matchesAuthoringGuidance =>
      steps.length >= recommendedMinimumSteps && steps.length <= maximumSteps;

  /// The guide types actually referenced, in vocabulary order.
  ///
  /// This is what a guide key should list: showing all four symbols on a step
  /// that only uses two teaches the user to look for markings that are not
  /// there.
  List<TutorialGuideType> get referencedGuideTypes {
    final referenced = steps.map((step) => step.guideType).toSet();
    return List<TutorialGuideType>.unmodifiable(
      TutorialGuideType.orderedVocabulary.where(referenced.contains),
    );
  }
}
