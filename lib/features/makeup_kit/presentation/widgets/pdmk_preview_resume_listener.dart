import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/makeup_kit_look_providers.dart';

/// Continues an interrupted plan-driven My Makeup Kit preview when the app
/// starts, when the user signs in, and when it returns to the foreground.
///
/// Mirrors `SubscriptionResumeRefresher`: a real user event, never a timer.
/// The work it continues was already reserved by the user's own request, and
/// the server alone decides its outcome; this only makes sure the question is
/// asked again after the process that asked it went away.
class PdmkPreviewResumeListener extends ConsumerStatefulWidget {
  const PdmkPreviewResumeListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PdmkPreviewResumeListener> createState() =>
      _PdmkPreviewResumeListenerState();
}

class _PdmkPreviewResumeListenerState
    extends ConsumerState<PdmkPreviewResumeListener> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  void _resume() {
    if (!mounted) return;
    if (ref.read(authControllerProvider).user == null) return;
    ref.read(pdmkPendingPreviewResumerProvider)?.resume();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A sign-in after launch is also a moment to continue.
    ref.listen(authControllerProvider.select((state) => state.user?.id), (
      previous,
      next,
    ) {
      if (next != null && next != previous) _resume();
    });
    return widget.child;
  }
}
