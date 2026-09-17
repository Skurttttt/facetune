import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/subscription_controller.dart';

/// Re-reads authoritative subscription state when the app returns to the
/// foreground.
///
/// ## Why this exists
///
/// A subscription's life happens somewhere else. It renews, lapses, goes on
/// hold, or is refunded at Google, and SUB-11 reconciles each of those
/// server-side from a verified provider read. None of that reaches a running
/// app: the entitlement changes while the process is backgrounded, and the
/// figures on screen go quietly stale.
///
/// Resuming is the honest moment to ask again. It is a real user event rather
/// than a timer, so this generates no background traffic, and it asks the one
/// question the client is allowed to ask — *what does the server say this
/// account has?*
///
/// ## What this is not
///
/// Not a lifecycle decision. Nothing here inspects a date, compares a period
/// end, or concludes that a plan has ended; the client owns no clock that
/// entitlement depends on. If the server's answer is unchanged, nothing
/// changes. The security property does not rest on this widget at all —
/// `resolve_subscription_state` refuses generation on a lapsed period whether
/// or not the app ever refreshed — so a missed resume costs accuracy on
/// screen, never correctness.
class SubscriptionResumeRefresher extends ConsumerStatefulWidget {
  const SubscriptionResumeRefresher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SubscriptionResumeRefresher> createState() =>
      _SubscriptionResumeRefresherState();
}

class _SubscriptionResumeRefresherState
    extends ConsumerState<SubscriptionResumeRefresher> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshAuthoritativeState);
  }

  void _refreshAuthoritativeState() {
    // Signed out there is nothing to read, and asking would be a request that
    // could only fail. `SubscriptionController.refresh` additionally collapses
    // a call that arrives while a read is already in flight, so a resume
    // during a purchase cannot double up.
    final signedIn = ref.read(authControllerProvider).user != null;
    if (!signedIn) return;
    ref.read(subscriptionControllerProvider.notifier).refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
