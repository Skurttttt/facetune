import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_authorization_controller.dart';
import '../admin_authorization_state.dart';

/// The stop the router sends every non-admin outcome to: a signed-in account
/// the server refused, a server that could not answer, or a build with no
/// Supabase configuration. Renders no account data beyond the fact of the
/// refusal, and offers only the actions that can change it.
class AdminUnauthorizedPage extends ConsumerWidget {
  const AdminUnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAuthorizationControllerProvider);
    final controller = ref.read(adminAuthorizationControllerProvider.notifier);
    final theme = Theme.of(context);

    final (title, message, retryable) = switch (state) {
      AdminAuthorizationFailed(:final retryable) => (
        'Authorization could not be verified',
        'The server did not confirm this session. '
            '${retryable ? 'Try again in a moment.' : 'Sign out and sign in again.'}',
        retryable,
      ),
      AdminConfigurationMissing() => (
        'Admin unavailable',
        'This build is missing its Supabase runtime configuration.',
        false,
      ),
      _ => (
        'Not authorized',
        'This account is not authorized to use the FaceTune Admin.',
        false,
      ),
    };

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: theme.colorScheme.error,
                  semanticLabel: 'Access denied',
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  key: const Key('admin-unauthorized-title'),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (retryable) ...[
                  FilledButton(
                    key: const Key('admin-retry'),
                    onPressed: controller.refresh,
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (state is! AdminConfigurationMissing)
                  OutlinedButton(
                    key: const Key('admin-sign-out'),
                    onPressed: controller.signOut,
                    child: const Text('Sign out'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
