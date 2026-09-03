import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../widgets/auth_feedback_listener.dart';
import '../widgets/brand_mark.dart';

class AuthenticationPage extends ConsumerWidget {
  const AuthenticationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenForAuthFeedback(ref, context);
    final authState = ref.watch(authControllerProvider);
    final supabaseInitialization = ref.watch(supabaseInitializationProvider);
    final isGoogleLoading = authState.activeOperation == AuthOperation.google;
    final isGuestLoading = authState.activeOperation == AuthOperation.guest;
    final isUnconfigured = authState.status == AuthStatus.configurationMissing;

    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                const _EntryHero(),
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
                if (isUnconfigured) ...[
                  const SizedBox(height: AppSpacing.lg),
                  // A blocked app is a failure, not an aside. It used to render
                  // on the same pink surface the app uses for ordinary hints.
                  AppNotice(
                    tone: AppTone.danger,
                    message: supabaseInitialization.userMessage,
                    liveRegion: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Sign in with email',
                  icon: Icons.mail_outline_rounded,
                  onPressed: isUnconfigured
                      ? null
                      : () => context.push(AppConstants.emailLoginRoute),
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: isGoogleLoading
                      ? 'Opening Google…'
                      : 'Continue with Google',
                  // No icon. The glyph here was `Icons.g_mobiledata_rounded` —
                  // Material's generic letter G standing in for Google's mark.
                  // Google's branding terms require the official asset when a
                  // mark is shown at all, so a lookalike is both off-brand and a
                  // review risk. Text alone is the compliant option until the
                  // real asset is added.
                  showIcon: false,
                  isLoading: isGoogleLoading,
                  onPressed: authState.isLoading || isUnconfigured
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                ),
                const SizedBox(height: AppSpacing.xs),
                TertiaryButton(
                  label: isGuestLoading
                      ? 'Creating guest session…'
                      : 'Explore as a guest',
                  expand: true,
                  onPressed: authState.isLoading || isUnconfigured
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .continueAsGuest(),
                ),
                TertiaryButton(
                  label: 'New here? Create an account',
                  expand: true,
                  onPressed: isUnconfigured
                      ? null
                      : () => context.push(AppConstants.registerRoute),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Guest sessions are temporary and remain isolated by account.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The entry panel.
///
/// Replaces a 250pt render of `assets/images/beauty_portrait.png` — a stock
/// photograph of a face, on the entry screen of an app that analyses faces,
/// where it read as an example result rather than as branding. It was also the
/// only asset in the project, at ~2 MB.
///
/// The gradient is deliberately the same one the Home screen's Start Scan panel
/// uses, so the first screen and the first screen *after* signing in belong to
/// one product.
///
/// The asset and [BeautyImage] are both still in the repository, unused. If
/// photography is wanted here, restoring it is one line — and if it is not,
/// the asset can be deleted.
class _EntryHero extends StatelessWidget {
  const _EntryHero();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xl,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.roseDark, AppColors.rose],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(AppRadii.xl),
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(
          size: BrandMarkSize.hero,
          // Fixed light foreground: the gradient keeps its own brightness in
          // both themes, so this cannot be inherited from the colour scheme.
          foreground: Colors.white,
          background: Colors.white24,
        ),
      ],
    ),
  );
}
