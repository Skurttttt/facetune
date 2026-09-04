/// The presentation FaceTune's two result modes share.
///
/// Standard Mode and My Makeup Kit answer the same question — here is your look
/// — from two different authorities: an AI recommendation, and a validated
/// snapshot of products the user actually owns. Before this, they also answered
/// it with two different screens, and the kit result read as a different
/// product rather than a different source.
///
/// Everything in this file is deliberately dumb. These widgets take strings and
/// child widgets and lay them out; not one of them reads a provider, decides
/// what data means, or knows which mode it is rendering. That is the whole
/// design: the shell converges so the two modes look like one product, and the
/// authorities stay exactly where they were so the kit's owned-product rules
/// cannot leak into Standard, or Standard's recommendations into the kit.
library;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

/// A compact provenance marker above the look's name.
///
/// My Makeup Kit uses this because where its products came from is a fact about
/// the result. Standard does not: it is the default experience, and labelling
/// the default only adds a line to read.
///
/// Deliberately small — a label, not a heading. It replaced a full-width tinted
/// notice card that said the same thing in a paragraph and outweighed the look
/// it was describing.
class ResultModeBadge extends StatelessWidget {
  const ResultModeBadge({required this.label, required this.icon, super.key});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = AppColors.muted(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSizes.sm, color: foreground),
          const SizedBox(width: AppSpacing.xxs + 2),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The look's name, and the facts that qualify it.
///
/// One optional line above for provenance, the style as the title, and a single
/// muted line of metadata. [metadata] is passed already composed because what
/// qualifies a look differs by mode — Standard has an undertone to report and
/// the kit has a product count — and deciding that here would make this widget
/// know which mode it is.
class ResultHeader extends StatelessWidget {
  const ResultHeader({
    required this.styleName,
    required this.metadata,
    super.key,
    this.badge,
  });

  final String styleName;
  final String metadata;

  /// Provenance, when the mode has any worth stating.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null) ...[badge!, const SizedBox(height: AppSpacing.xs)],
        Text(
          styleName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          metadata,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
      ],
    );
  }
}

/// The three sections a result is read in, and the control that switches them.
///
/// The [makeup] child stays mounted whichever section is showing. That is not a
/// performance choice — it is the AI-cost lock. Both modes ensure their accepted
/// manifest from that subtree's `initState`, so unmounting it on a tab switch
/// would let a user pay for analysis again by tapping "Profile" and back.
/// Offstage keeps the subtree alive and stops it painting, which is exactly the
/// behaviour Standard has been shipping.
class ResultSections extends StatefulWidget {
  const ResultSections({
    required this.overview,
    required this.makeup,
    required this.profile,
    super.key,
  });

  final Widget overview;
  final Widget makeup;
  final Widget profile;

  @override
  State<ResultSections> createState() => _ResultSectionsState();
}

enum _ResultSection { overview, makeup, profile }

class _ResultSectionsState extends State<ResultSections> {
  _ResultSection _section = _ResultSection.overview;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('result-progressive-details'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<_ResultSection>(
          key: const ValueKey('result-section-tabs'),
          showSelectedIcon: false,
          segments: [
            for (final section in _ResultSection.values)
              ButtonSegment<_ResultSection>(
                value: section,
                label: Semantics(
                  container: true,
                  excludeSemantics: true,
                  selected: _section == section,
                  label: '${_sectionLabel(section)} tab',
                  child: Text(_sectionLabel(section)),
                ),
              ),
          ],
          selected: <_ResultSection>{_section},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            setState(() => _section = selection.single);
          },
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_section == _ResultSection.overview) widget.overview,
      Offstage(
        offstage: _section != _ResultSection.makeup,
        child: widget.makeup,
      ),
      if (_section == _ResultSection.profile) widget.profile,
    ],
  );

  static String _sectionLabel(_ResultSection section) => switch (section) {
    _ResultSection.overview => 'Overview',
    _ResultSection.makeup => 'Makeup',
    _ResultSection.profile => 'Profile',
  };
}

/// The reserved strip at the bottom of a result.
///
/// Belongs in `Scaffold.bottomNavigationBar`, not stacked over the body: the
/// scroll view is then measured against what is left after it, so no scroll
/// offset can hide content underneath. It sizes to the one button it holds.
class ResultBottomCta extends StatelessWidget {
  const ResultBottomCta({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: DecoratedBox(
        // Outside the safe area and outside the gutter, so the rule runs edge
        // to edge and reads as the boundary of the screen.
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.dividerTheme.color ?? theme.dividerColor,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          // Not `PageFrame`: its `Center` expands to whatever height it is
          // offered, which in a `bottomNavigationBar` slot is the whole screen.
          // `heightFactor: 1` makes this hug its child.
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: PrimaryButton(
                key: const ValueKey('result-show-tutorial'),
                label: label,
                icon: Icons.auto_stories_outlined,
                onPressed: onPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
