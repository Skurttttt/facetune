import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_authorization_controller.dart';
import '../admin_authorization_state.dart';

/// Email/password sign-in for the Web Admin, using the project's existing
/// Supabase Auth. Signing in proves identity only; whether the account is an
/// administrator is decided by the server afterwards and routes the user to
/// the shell or to the unauthorized page.
///
/// No guest sign-in, no registration, no OAuth: an admin account already
/// exists and was provisioned server-side.
class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(adminAuthorizationControllerProvider.notifier)
        .signInWithEmail(
          email: _email.text,
          password: _password.text,
          signIn: ref.read(adminSignInStatusProvider.notifier),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authorization = ref.watch(adminAuthorizationControllerProvider);
    final signIn = ref.watch(adminSignInStatusProvider);
    final sessionExpired =
        authorization is AdminUnauthenticated && authorization.sessionExpired;
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'FaceTune Admin',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with an administrator account.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (sessionExpired) ...[
                      const SizedBox(height: 16),
                      _Notice(
                        key: const Key('admin-session-expired'),
                        message: 'Your session has expired. Sign in again.',
                        color: theme.colorScheme.tertiary,
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('admin-email'),
                      controller: _email,
                      enabled: !signIn.isSubmitting,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          (value == null || !value.contains('@'))
                          ? 'Enter your email address.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('admin-password'),
                      controller: _password,
                      enabled: !signIn.isSubmitting,
                      autofillHints: const [AutofillHints.password],
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Enter your password.'
                          : null,
                    ),
                    if (signIn.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _Notice(
                        key: const Key('admin-sign-in-error'),
                        message: signIn.errorMessage!,
                        color: theme.colorScheme.error,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('admin-sign-in'),
                      onPressed: signIn.isSubmitting ? null : _submit,
                      child: signIn.isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message, style: TextStyle(color: color)),
      ),
    );
  }
}
