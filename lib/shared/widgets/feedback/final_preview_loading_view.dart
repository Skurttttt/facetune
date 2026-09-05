import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import 'app_progress.dart';

/// The wait before a canonical final preview, drawn as the result that is
/// coming.
///
/// One state, honestly presented. The generation runs inside a single server
/// request, so the app knows only that it started and that it has not finished
/// — there is no preparing step, no saving step and no percentage it could
/// truthfully show. This screen therefore says one thing, once, and spends its
/// space on the shape of the result instead of on invented milestones.
///
/// The hero is the point. It is drawn at the canonical preview's own aspect
/// ratio and corner radius, so the placeholder occupies the exact frame the
/// finished look will occupy and the screen reads as the result arriving rather
/// than as a detour.
///
/// Presentation only. It renders what it is handed, reads no provider, starts
/// no work, and knows nothing about which mode is waiting — the caller supplies
/// the copy and the metadata, because the caller is the only thing that
/// legitimately knows whose preview this is. Both Makeup Recommendation and My
/// Makeup Kit compose it, and composing it merges nothing.
class FinalPreviewLoadingView extends StatefulWidget {
  const FinalPreviewLoadingView({
    required this.supportingText,
    super.key,
    this.styleName,
    this.intensityLabel,
    this.footer,
  });

  /// The one status this screen can truthfully show, and the only one it shows.
  static const String activeStatus = 'Creating your makeup preview';

  /// Neutral, and deliberately silent about duration. The app has no estimate,
  /// so it promises none.
  static const String reassurance =
      'Your personalized look is being generated. This may take a moment.';

  /// The canonical preview's frame, matched so the placeholder and the finished
  /// image occupy the same space.
  static const double heroAspectRatio = 3 / 4;

  /// What the wait is for, in this mode's own words. The one line that differs
  /// between the two modes, because the work genuinely differs.
  final String supportingText;

  /// The chosen style's display name, when the journey already knows it.
  ///
  /// Already-loaded state or nothing: null omits it from the title and from the
  /// metadata line rather than fetching it, defaulting it, or printing a
  /// placeholder word for it.
  final String? styleName;

  /// The plan's overall intensity, already formatted for reading.
  ///
  /// Same rule as [styleName] — absent means absent, never "Unknown".
  final String? intensityLabel;

  /// An optional escape the waiting screen already offered.
  ///
  /// Present so adopting this shell never removes a control a mode already had.
  /// Nothing is added here by default.
  final Widget? footer;

  /// The title: the style's own look when it is known, the plain statement of
  /// what is being made when it is not.
  String get title => styleName == null
      ? 'Creating your look'
      : 'Creating your $styleName look';

  @override
  State<FinalPreviewLoadingView> createState() =>
      _FinalPreviewLoadingViewState();
}

class _FinalPreviewLoadingViewState extends State<FinalPreviewLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// The column below the hero, measured at text scale 1.
  ///
  /// Title, supporting line, metadata, status and reassurance — the parts that
  /// grow with the user's text size. Scaled by the live [TextScaler] so the
  /// hero gives room back as the type gets larger, instead of pushing the
  /// status off the screen.
  static const double _textAllowance = 143;

  /// The fixed gaps in that column, which do not scale with text.
  static const double _gapAllowance =
      AppSpacing.xxs +
      AppSpacing.lg +
      AppSpacing.lg +
      AppSpacing.sm +
      AppSpacing.xs;

  /// The smallest hero worth drawing. Below this it stops reading as the frame
  /// the result will fill; the page scrolls instead.
  static const double _minimumHeroHeight = 160;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppColors.muted(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = _heroHeight(context, constraints);
        // Scrolls only when it must. On a phone at normal text the column fits
        // exactly, because the hero is sized from what is left over; at large
        // text the hero stops at its floor and this takes over rather than
        // clipping the status the user is waiting to read.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Announced once, as one region. The label is the title and the
                // one true status together, and it does not change while the
                // hero pulses — so a screen reader is told what is happening
                // once rather than on every frame.
                Semantics(
                  container: true,
                  liveRegion: true,
                  label:
                      '${widget.title}. ${widget.supportingText} '
                      '${FinalPreviewLoadingView.activeStatus}.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.supportingText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _HeroPlaceholder(animation: _controller, height: heroHeight),
                const SizedBox(height: AppSpacing.lg),
                if (_metadata.isNotEmpty) ...[
                  _MetadataLine(entries: _metadata, color: muted),
                  const SizedBox(height: AppSpacing.sm),
                ],
                // The single truthful status. One line, no stage list, no
                // percentage, and nothing that advances on a timer.
                Row(
                  children: [
                    const AppProgress(size: AppProgressSize.small),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        FinalPreviewLoadingView.activeStatus,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  FinalPreviewLoadingView.reassurance,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (widget.footer != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: widget.footer),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// The style and intensity the journey already knows, in reading order.
  ///
  /// Whatever is absent is simply not there. No placeholder word stands in for
  /// a value the app does not have.
  List<String> get _metadata => <String>[
    if (widget.styleName != null) widget.styleName!,
    if (widget.intensityLabel != null) '${widget.intensityLabel} intensity',
  ];

  /// How tall the hero can be here.
  ///
  /// The natural size is the canonical frame at full width; the ceiling is
  /// whatever the column below it does not need. Taking the smaller of the two
  /// is what lets one phone show the full frame and a shorter one show a
  /// smaller frame, with neither scrolling and neither stretching the shape.
  double _heroHeight(BuildContext context, BoxConstraints constraints) {
    final natural =
        constraints.maxWidth / FinalPreviewLoadingView.heroAspectRatio;
    if (!constraints.hasBoundedHeight) return natural;
    final scaler = MediaQuery.textScalerOf(context);
    final reserved = _gapAllowance + scaler.scale(_textAllowance);
    final remaining = constraints.maxHeight - reserved;
    if (remaining >= natural) return natural;
    return remaining < _minimumHeroHeight ? _minimumHeroHeight : remaining;
  }
}

/// The frame the finished preview will fill, still empty.
///
/// Same aspect ratio and same corner radius as the canonical result hero, so
/// nothing moves or resizes when the image replaces it. It pulses on the app's
/// existing skeleton rhythm and carries no spinner of its own — the status line
/// below already says the work is running, and a spinner centred in the frame
/// would make the placeholder read as a broken image rather than a coming one.
class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder({required this.animation, required this.height});

  final Animation<double> animation;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        height: height,
        // The frame's own proportion decides its width, so a hero shortened to
        // fit stays the shape of the picture rather than becoming a letterbox.
        width: height * FinalPreviewLoadingView.heroAspectRatio,
        // Silent, and never announced as an image. A placeholder described as
        // a generated preview would tell a screen reader the result had
        // arrived while the app was still waiting for it.
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  scheme.surfaceContainerHighest,
                  scheme.surfaceContainerLow,
                  animation.value,
                ),
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Style and intensity, as the quiet line under the frame.
class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.entries, required this.color});

  final List<String> entries;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    entries.join(' · '),
    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
  );
}
