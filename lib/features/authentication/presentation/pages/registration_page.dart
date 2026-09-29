import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/services/auth_validators.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../widgets/auth_feedback_listener.dart';
import '../widgets/auth_form_scaffold.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/password_requirements.dart';

class RegistrationPage extends ConsumerStatefulWidget {
  const RegistrationPage({super.key});

  @override
  ConsumerState<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends ConsumerState<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  // Explicit targets for the keyboard's Next. Left to default traversal, Next
  // from Password lands on the show/hide button beside it, not on Confirm.
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();
  bool _obscurePassword = true;

  /// Presentation only: after the first submit, unmet password criteria switch
  /// from neutral to the error treatment, and field errors update as the user
  /// corrects them. Whether the form is valid is still decided by the
  /// validators alone.
  bool _submitAttempted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenForAuthFeedback(ref, context);
    final authState = ref.watch(authControllerProvider);
    return AuthFormScaffold(
      title: 'Create your account',
      subtitle: 'Save your looks securely and return anytime.',
      // The group lets a password manager offer a strong password for both
      // fields, and offer to save the new account once it is created.
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitAttempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: AuthValidators.displayName,
                onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  errorMaxLines: authFieldErrorMaxLines,
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: AuthValidators.email,
                autocorrect: false,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
                // Stay off even while the passwords are shown, when the
                // keyboard would otherwise start "correcting" them.
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidators.password,
                onFieldSubmitted: (_) => _confirmationFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorMaxLines: authFieldErrorMaxLines,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    // Also the button's accessible name. It shows or hides both
                    // password fields, as it always has.
                    tooltip: _obscurePassword
                        ? 'Show passwords'
                        : 'Hide passwords',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: PasswordRequirementsChecklist(
                  controller: _passwordController,
                  showUnmetAsErrors: _submitAttempted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirmationController,
                focusNode: _confirmationFocus,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => AuthValidators.confirmedPassword(
                  value,
                  _passwordController.text,
                ),
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  errorMaxLines: authFieldErrorMaxLines,
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: PasswordMatchFeedback(
                  password: _passwordController,
                  confirmation: _confirmationController,
                  // Once the field's own error is live, it already says the
                  // passwords differ; saying it twice adds nothing.
                  showMismatch: !_submitAttempted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthSubmitButton(
                label: 'Create account',
                loadingLabel: 'Creating account…',
                isLoading: authState.activeOperation == AuthOperation.register,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              TertiaryButton(
                label: 'Already have an account? Sign in',
                expand: true,
                onPressed: authState.isLoading ? null : _returnToSignIn,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'By continuing, you agree to protect the privacy of any images you upload.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The same destination as the top bar's Back: registration is only ever
  /// pushed on top of the sign-in screen, so returning to it is a pop. The
  /// fallback covers the page being opened with nothing beneath it.
  void _returnToSignIn() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppConstants.authRoute);
    }
  }

  void _submit() {
    // The keyboard's Done reaches here without the button. The controller
    // would drop a second request anyway; this keeps the form from flashing
    // errors for one it was never going to send.
    if (ref.read(authControllerProvider).isLoading) {
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
        .registerWithEmail(
          displayName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
  }
}
