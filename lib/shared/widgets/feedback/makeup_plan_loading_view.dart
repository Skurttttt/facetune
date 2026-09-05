import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../media/color_swatch.dart';
import '../surfaces/app_card.dart';

/// The wait before a makeup plan, drawn as the plan that is coming.
///
/// A centred spinner over an empty page told the user only that something was
/// happening somewhere. This says what is being made and shows the shape it
/// will arrive in: a heading, a supporting line, and the plan's own cards with
/// their content still missing — the same geometry the destination draws, so
/// when the plan lands, bars are replaced by text and little moves.
///
/// Presentation only, and deliberately so. It renders what it is handed, reads
/// no provider, starts no work and knows nothing about which mode is waiting —
/// the caller supplies the copy, because the caller is the only thing that
/// legitimately knows whose plan this is. Both Makeup Recommendation and My
/// Makeup Kit compose it, and composing it merges nothing: each mode keeps its
/// own controller, its own repository and its own authority over the plan.
///
/// There is no progress value here for the same reason `LoadingState` refuses
/// one by default — a plan generation reports no completion, so any bar drawn
/// for it would be an animation timed to a guess.
class MakeupPlanLoadingView extends StatefulWidget {
  const MakeupPlanLoadingView({
    required this.title,
    required this.supportingText,
    super.key,
    this.footer,
  });

  /// The fewest placeholders that still read as a list rather than as one
  /// stranded card. Drawn even where the viewport is too short to hold them,
  /// because the list scrolls and a single placeholder describes nothing.
  static const int minimumSections = 3;

  /// The most placeholders worth drawing.
  ///
  /// The real plan carries up to ten categories, so a taller viewport could
  /// honestly hold more — but past about six the run stops saying "a list of
  /// plan cards is coming" and starts being noise. A ceiling, not a target: the
  /// viewport is what normally decides.
  static const int maximumSections = 6;

  /// What is being made. The first line of the page, in the slot the plan's own
  /// heading will occupy.
  final String title;

  /// One line saying what the wait is for. Kept to one line on purpose: a
  /// paragraph read while waiting is a paragraph read twice.
  final String supportingText;

  /// An optional escape the waiting screen already offered.
  ///
  /// Present so adopting this shell never removes a control a mode already had.
  /// Nothing is added here by default.
  final Widget? footer;

  @override
  State<MakeupPlanLoadingView> createState() => _MakeupPlanLoadingViewState();
}

class _MakeupPlanLoadingViewState extends State<MakeupPlanLoadingView>
    with SingleTickerProviderStateMixin {
  /// One controller for every placeholder on the page.
  ///
  /// Shared rather than one per card, which also makes the cards pulse together
  /// instead of drifting apart into three competing rhythms.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.shimmer,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The gap between placeholder cards.
  ///
  /// One step tighter than the real plan's card gap. Three cards spaced like
  /// content read as three isolated objects; closed up, the run reads as one
  /// feed still filling in — which is what it is.
  static const double _sectionGap = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineSmall;
    final supportingStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.muted(context),
    );
    // The run is measured against the space it is actually given rather than
    // fixed at a number that happened to look right on one phone. A tall phone
    // was leaving most of its lower half empty; a short one must not overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        final sectionCount = _fittingSectionCount(
          context,
          constraints,
          titleStyle: titleStyle,
          supportingStyle: supportingStyle,
        );
        return ListView(
          // The frame around this view already sets the gutter and the lead-in.
          padding: EdgeInsets.zero,
          children: [
            // Announced once, as one region, with a label that does not change
            // while the placeholders pulse. Kept outside the animated subtree
            // below so a frame of shimmer cannot rebuild it.
            Semantics(
              container: true,
              liveRegion: true,
              label: '${widget.title}. ${widget.supportingText}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: titleStyle),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(widget.supportingText, style: supportingStyle),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Silent. Placeholder geometry is not content, and a screen reader
            // walked through empty cards learns nothing the announcement above
            // did not already say.
            ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // The same slow two-tone pulse the rest of the app's
                  // skeletons use, from the same two surface roles.
                  final color = Color.lerp(
                    theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.surfaceContainerLow,
                    _controller.value,
                  )!;
                  return Column(
                    children: <Widget>[
                      for (var i = 0; i < sectionCount; i++) ...[
                        _PlanSectionSkeleton(color: color),
                        if (i != sectionCount - 1)
                          const SizedBox(height: _sectionGap),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (widget.footer != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Center(child: widget.footer),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }

  /// How many placeholder cards the space actually given can hold.
  ///
  /// Derived, not chosen. The header is measured rather than estimated, because
  /// it is the one part of this screen whose height moves: the supporting line
  /// wraps differently at every width and every text scale, and a guess that is
  /// one line out shows four cards where five fit. A placeholder card, by
  /// contrast, contains no text at all, so [_PlanSectionSkeleton.height] is a
  /// constant at every text scale — which is what makes this arithmetic honest.
  ///
  /// Clamped at both ends. Below [MakeupPlanLoadingView.minimumSections] the run
  /// stops reading as a list; above [MakeupPlanLoadingView.maximumSections] it
  /// stops informing. Between them the viewport decides, so a tall phone fills
  /// and a short one does not overflow — no device is named or detected.
  int _fittingSectionCount(
    BuildContext context,
    BoxConstraints constraints, {
    required TextStyle? titleStyle,
    required TextStyle? supportingStyle,
  }) {
    // An unbounded height means nothing can be fitted to it. The floor is the
    // honest answer rather than a number invented for an unknown viewport.
    if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) {
      return MakeupPlanLoadingView.minimumSections;
    }
    final scaler = MediaQuery.textScalerOf(context);
    final width = constraints.maxWidth;
    final header =
        _textHeight(widget.title, titleStyle, width, scaler) +
        AppSpacing.xxs +
        _textHeight(widget.supportingText, supportingStyle, width, scaler) +
        AppSpacing.lg;
    // The footer is real content that occupies the viewport, so it is reserved
    // rather than overrun — a mode carrying an escape control must not push it
    // below the fold. Both modes run this same arithmetic over their own
    // content; neither is given a count the other decided.
    final footer = widget.footer == null
        ? 0.0
        : scaler.scale(kMinInteractiveDimension) + AppSpacing.sm;
    // The trailing gap is subtracted too, so a run that exactly fills the
    // viewport does not scroll by the width of its own breathing room.
    final available = constraints.maxHeight - header - footer - AppSpacing.lg;
    // n cards carry n-1 gaps between them.
    final fits =
        (available + _sectionGap) / (_PlanSectionSkeleton.height + _sectionGap);
    return fits.floor().clamp(
      MakeupPlanLoadingView.minimumSections,
      MakeupPlanLoadingView.maximumSections,
    );
  }

  /// The laid-out height of one header line at this width and text scale.
  static double _textHeight(
    String text,
    TextStyle? style,
    double width,
    TextScaler scaler,
  ) => (TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout(maxWidth: width)).height;
}

/// One plan card with nothing in it yet.
///
/// Its geometry is taken from the real card rather than approximated: the same
/// tightened card inset, the same swatch diameter, the same two stacked lines
/// beside it, the same quiet line beneath, and the same minimum-height row the
/// card's disclosure control occupies.
///
/// Bars only. No shade name, no product, no brand, no percentage — a
/// placeholder that reads as data would be a claim about a plan that does not
/// exist yet.
class _PlanSectionSkeleton extends StatelessWidget {
  const _PlanSectionSkeleton({required this.color});

  final Color color;

  /// The accessible floor the real card's disclosure row is held to, and so the
  /// height that row reserves here.
  static const double _disclosureRowHeight = 44;

  /// The two stacked bars beside the swatch, which are taller together than the
  /// swatch itself and therefore set the first row's height.
  static const double _identityRowHeight =
      _titleBarHeight + AppSpacing.xxs + _shadeBarHeight;

  static const double _titleBarHeight = 16;
  static const double _shadeBarHeight = 14;
  static const double _finishBarHeight = 12;

  /// This card's laid-out height, summed from the parts below rather than
  /// measured or guessed.
  ///
  /// A constant is correct here — and only here — because the card holds no
  /// text: every element is a fixed-height bar, a fixed-diameter swatch or a
  /// fixed inset, so nothing in it grows with text scale. That is what lets
  /// [_MakeupPlanLoadingViewState._fittingSectionCount] do exact arithmetic
  /// instead of estimating. It is derived from the same tokens the build method
  /// below uses, so the two cannot drift apart.
  static const double height =
      AppSpacing.xs +
      _identityRowHeight +
      AppSpacing.xxs +
      _finishBarHeight +
      _disclosureRowHeight +
      AppSpacing.xxs;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.xxs,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The swatch's own placeholder colour, at the swatch's own size —
            // the shade is the one thing on the card that is pure data, and it
            // already has a defined empty state.
            const AppColorSwatch(color: null),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category, then shade name: the card's two strongest lines,
                  // at their heights and in their order.
                  _Bar(color: color, widthFactor: .42, height: _titleBarHeight),
                  const SizedBox(height: AppSpacing.xxs),
                  _Bar(color: color, widthFactor: .62, height: _shadeBarHeight),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // Holds the column the intensity label will occupy, so the text
            // beside it keeps its real width while loading.
            _Bar(color: color, width: 44, height: 11),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        _Bar(color: color, widthFactor: .28, height: _finishBarHeight),
        SizedBox(
          height: _disclosureRowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _Bar(color: color, widthFactor: .46, height: 11),
          ),
        ),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.color,
    required this.height,
    this.widthFactor,
    this.width,
  });

  final Color color;
  final double height;
  final double? widthFactor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
    final factor = widthFactor;
    return factor == null
        ? bar
        : FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: factor,
            child: bar,
          );
  }
}
