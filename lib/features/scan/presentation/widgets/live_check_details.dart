import 'package:flutter/material.dart';

import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/live_check.dart';
import '../../domain/entities/live_validation_snapshot.dart';
import '../utils/live_guidance.dart';

/// The per-check detail, collapsed behind a one-line summary.
///
/// The detail is genuinely useful when a user cannot tell why they are not
/// Ready, so it is available — but it is secondary by construction. Shown
/// permanently it would be a five-row report updating several times a second
/// beside a live preview, which is exactly what the Source of Truth rules out.
///
/// Collapsed by default, and collapsing costs nothing: this reads state that
/// has already been computed for the guidance line above it.
class LiveCheckDetails extends StatefulWidget {
  const LiveCheckDetails({
    required this.summary,
    required this.snapshot,
    super.key,
  });

  /// The one-line count, supplied by the caller so this widget never has to
  /// decide whether a measurement has happened yet.
  final String summary;

  final LiveValidationSnapshot snapshot;

  @override
  State<LiveCheckDetails> createState() => _LiveCheckDetailsState();
}

class _LiveCheckDetailsState extends State<LiveCheckDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;

    return Semantics(
      container: true,
      button: true,
      expanded: _expanded,
      label: summary,
      child: ExpansionTile(
        key: const ValueKey('live-check-details'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (value) => setState(() => _expanded = value),
        title: Text(summary, style: theme.textTheme.labelLarge),
        children: [
          for (final check in LiveValidationSnapshot.priority)
            _CheckRow(check: check, state: widget.snapshot.stateOf(check)),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.state});

  final LiveCheck check;
  final LiveCheckState state;

  @override
  Widget build(BuildContext context) {
    final tone = switch (state) {
      LiveCheckState.pass => AppTone.success,
      LiveCheckState.warning => AppTone.warning,
      LiveCheckState.fail => AppTone.danger,
      _ => AppTone.info,
    }.resolve(context);

    // Icon plus text, never colour alone: the state has to survive a
    // greyscale screen and a colour-blind reader.
    final icon = switch (state) {
      LiveCheckState.pass => Icons.check_circle_outline_rounded,
      LiveCheckState.warning => Icons.error_outline_rounded,
      LiveCheckState.fail => Icons.cancel_outlined,
      _ => Icons.radio_button_unchecked_rounded,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: MergeSemantics(
        child: Semantics(
          label: LiveGuidance.checkLabel(check, state),
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: AppIconSizes.sm, color: tone.accent),
              const SizedBox(width: AppSpacing.sm),
              // Expanded so the row wraps rather than overflowing once the
              // reader raises their text size.
              Expanded(child: Text(LiveGuidance.checkLabel(check, state))),
            ],
          ),
        ),
      ),
    );
  }
}
