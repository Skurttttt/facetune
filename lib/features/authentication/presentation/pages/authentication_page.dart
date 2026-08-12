import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../widgets/auth_feedback_listener.dart';

class AuthenticationPage extends ConsumerWidget {
  const AuthenticationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenForAuthFeedback(ref, context);
    final authState = ref.watch(authControllerProvider);
    final supabaseInitialization = ref.watch(supabaseInitializationProvider);
    final isGoogleLoading = authState.activeOperation == AuthOperation.google;
    final isGuestLoading = authState.activeOperation == AuthOperation.guest;

    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.rose,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'FaceTune',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const BeautyImage(height: 250),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Meet the look\nmade for you.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Personalized makeup inspiration, guided by your unique features.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.muted(context),
                  ),
                ),
                if (authState.status == AuthStatus.configurationMissing) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    color: AppColors.petal,
                    child: Text(
                      supabaseInitialization.userMessage,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Sign in with email',
                  icon: Icons.mail_outline_rounded,
                  onPressed: authState.status == AuthStatus.configurationMissing
                      ? null
                      : () => context.push(AppConstants.emailLoginRoute),
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: isGoogleLoading
                      ? 'Opening Google…'
                      : 'Continue with Google',
                  icon: Icons.g_mobiledata_rounded,
                  onPressed:
                      authState.isLoading ||
                          authState.status == AuthStatus.configurationMissing
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed:
                      authState.isLoading ||
                          authState.status == AuthStatus.configurationMissing
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .continueAsGuest(),
                  child: Text(
                    isGuestLoading
                        ? 'Creating guest session…'
                        : 'Explore as a guest',
                  ),
                ),
                TextButton(
                  onPressed: authState.status == AuthStatus.configurationMissing
                      ? null
                      : () => context.push(AppConstants.registerRoute),
                  child: const Text('New here? Create an account'),
                ),
                Text(
                  'Guest sessions are temporary and remain isolated by account.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
