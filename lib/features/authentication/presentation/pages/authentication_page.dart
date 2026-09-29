import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/services/auth_validators.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../widgets/auth_feedback_listener.dart';
import '../widgets/auth_form_scaffold.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/brand_mark.dart';

/// The sign-in screen.
///
/// Signing in used to take two screens: this one was a landing page — a
/// gradient hero, a marketing headline and a "Sign in with email" button — and
/// the fields lived one push later on `EmailLoginPage`. The fields are now here,
/// so the first thing a signed-out user sees is the task itself.
///
/// The form is the one `EmailLoginPage` had, field for field: the same
/// validators, the same keyboard and autofill settings, and the same call to
/// `signInWithEmail`. That page and its route are still registered; nothing in
/// the app navigates to them any more.
///
/// There is no guest entry. `continueAsGuest` and anonymous sign-in are
/// untouched — this screen simply no longer offers them.
class AuthenticationPage extends ConsumerStatefulWidget {
  const AuthenticationPage({super.key});

  @override
  ConsumerState<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends ConsumerState<AuthenticationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  /// Presentation only: after the first submit, field errors update as the
  /// user corrects them rather than waiting for the next tap.
  bool _submitAttempted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenForAuthFeedback(ref, context);
    final authState = ref.watch(authControllerProvider);
    final supabaseInitialization = ref.watch(supabaseInitializationProvider);
    final isGoogleLoading = authState.activeOperation == AuthOperation.google;
    final isUnconfigured = authState.status == AuthStatus.configurationMissing;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          // Not a ListView: a lazily built list can drop an off-screen field's
          // element, and the form would then validate without it.
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                const BrandMark(size: BrandMarkSize.hero),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sign in to continue your beauty journey.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.muted(context),
                  ),
                ),
                if (isUnconfigured) ...[
                  const SizedBox(height: AppSpacing.lg),
                  // A blocked app is a failure, not an aside.
                  AppNotice(
                    tone: AppTone.danger,
                    message: supabaseInitialization.userMessage,
                    liveRegion: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                // The group lets a password manager fill both fields together,
                // and offer to save them after a successful sign-in.
                AutofillGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submitAttempted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          validator: AuthValidators.email,
                          // Straight to the password, never to a button.
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            errorMaxLines: authFieldErrorMaxLines,
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          // Stay off even while the password is shown, when
                          // the keyboard would otherwise start "correcting" it.
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your password.'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            errorMaxLines: authFieldErrorMaxLines,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              // Also the button's accessible name.
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isUnconfigured
                        ? null
                        : () => context.push(AppConstants.forgotPasswordRoute),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthSubmitButton(
                  label: 'Sign in',
                  loadingLabel: 'Signing in…',
                  isLoading: authState.activeOperation == AuthOperation.signIn,
                  // The controller already ignores a request while another is
                  // running; disabling here just says so on screen.
                  onPressed: authState.isLoading || isUnconfigured
                      ? null
                      : _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                const _OrDivider(),
                const SizedBox(height: AppSpacing.lg),
                SecondaryButton(
                  label: isGoogleLoading
                      ? 'Opening Google…'
                      : 'Continue with Google',
                  // No icon. Google's branding terms require the official asset
                  // when a mark is shown at all, so a lookalike glyph is both
                  // off-brand and a review risk.
                  showIcon: false,
                  isLoading: isGoogleLoading,
                  onPressed: authState.isLoading || isUnconfigured
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                ),
                const SizedBox(height: AppSpacing.md),
                TertiaryButton(
                  label: 'New here? Create an account',
                  expand: true,
                  onPressed: isUnconfigured
                      ? null
                      : () => context.push(AppConstants.registerRoute),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    // The keyboard's Done reaches here without the button, so it gets the
    // same two checks the button's enabled state already applies. The
    // controller would drop a second request anyway; this keeps the form from
    // flashing errors for one it was never going to send.
    final authState = ref.read(authControllerProvider);
    if (authState.isLoading ||
        authState.status == AuthStatus.configurationMissing) {
      return;
    }
    if (!_submitAttempted) {
      setState(() => _submitAttempted = true);
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }
}

/// Separates the email form from the alternative sign-in method.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(
          'or',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
        ),
      ),
      const Expanded(child: Divider()),
    ],
  );
}
