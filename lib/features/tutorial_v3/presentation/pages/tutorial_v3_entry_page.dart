import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/tutorial_v3_providers.dart';
import '../../domain/entities/tutorial_v3_source_mode.dart';
import '../../domain/repositories/tutorial_v3_repository.dart';
import 'tutorial_v3_page.dart';

/// The routed entry into a V3 tutorial.
///
/// A thin wrapper that opens the session and then renders [TutorialV3Page],
/// which stays purely presentational. Splitting them keeps the screen
/// testable without a route and keeps the "open once" concern in one place.
///
/// The route carries only the premium preview's id and which chain it belongs
/// to. Everything the tutorial is built from — the analysis, the
/// recommendation, the selected look, the canonical image path — is resolved
/// server-side from rows RLS has already scoped to the caller, so a
/// hand-edited link cannot point a tutorial anywhere its owner could not
/// already reach.
class TutorialV3EntryPage extends ConsumerStatefulWidget {
  const TutorialV3EntryPage({
    required this.canonicalImageId,
    required this.sourceMode,
    super.key,
  });

  /// The `generated_images` or `kit_generated_images` row id.
  final String canonicalImageId;

  final TutorialV3SourceMode sourceMode;

  @override
  ConsumerState<TutorialV3EntryPage> createState() =>
      _TutorialV3EntryPageState();
}

class _TutorialV3EntryPageState extends ConsumerState<TutorialV3EntryPage> {
  @override
  void initState() {
    super.initState();
    // After the first frame so the controller's state changes have a mounted
    // listener, and so an immediate failure still renders inside the screen
    // rather than during the build that created it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didUpdateWidget(TutorialV3EntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canonicalImageId != widget.canonicalImageId ||
        oldWidget.sourceMode != widget.sourceMode) {
      // Also deferred: a provider may not be modified while the tree is
      // building, and didUpdateWidget runs inside that phase.
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  void _open() {
    if (!mounted) return;
    ref
        .read(tutorialV3SessionControllerProvider.notifier)
        .open(
          TutorialV3EntryPoint(
            canonicalImageId: widget.canonicalImageId,
            sourceMode: widget.sourceMode,
          ),
        );
  }

  @override
  Widget build(BuildContext context) => const TutorialV3Page();
}
