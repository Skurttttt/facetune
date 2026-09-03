import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../history/domain/entities/history_entry.dart';
import '../../../history/presentation/controllers/history_controller.dart';
import '../../../history/presentation/controllers/history_state.dart';
import '../../../makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import '../../../preview/presentation/controllers/makeup_preview_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import '../../../scan/presentation/controllers/scan_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selectors keep this dashboard off the rebuild path for unrelated auth and
    // profile changes (feedback messages, in-flight operation flags), which
    // otherwise rebuild the whole scroll view on every snackbar.
    final authUser = ref.watch(
      authControllerProvider.select((state) => state.user),
    );
    final profile = ref.watch(
      profileControllerProvider.select((state) => state.profile),
    );
    final historyState = ref.watch(historyControllerProvider);
    final name =
        profile?.displayName ?? authUser?.friendlyName ?? 'Beauty lover';
    return AppShell(
      index: 0,
      child: SafeArea(
        child: PageFrame(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(historyControllerProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, $name',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'What beauty mood are you in?',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted(context)),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        // An icon-only control with no tooltip is unlabelled
                        // for a screen reader and unguessable for everyone
                        // else.
                        tooltip: 'Settings',
                        onPressed: () =>
                            context.push(AppConstants.settingsRoute),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
                SliverToBoxAdapter(
                  child: _ScanHero(
                    onStart: () {
                      ref
                        ..invalidate(scanControllerProvider)
                        ..invalidate(faceAnalysisControllerProvider)
                        ..invalidate(makeupStyleSelectionControllerProvider)
                        ..invalidate(makeupRecommendationControllerProvider)
                        ..invalidate(makeupPreviewControllerProvider);
                      context.push(AppConstants.scanRoute);
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'Recent looks',
                    action: 'View all',
                    onAction: () => context.go(AppConstants.historyRoute),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                SliverToBoxAdapter(
                  child: _RecentLooks(
                    state: historyState,
                    onRetry: () => ref
                        .read(historyControllerProvider.notifier)
                        .loadInitial(),
                    onSessionExpired: () => ref
                        .read(authControllerProvider.notifier)
                        .recoverExpiredSession(),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
                const SliverToBoxAdapter(
                  child: SectionHeader('Your next look'),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                const SliverToBoxAdapter(
                  // Was a hand-assembled petal card whose gold icon measured
                  // 2.79:1 against that tint — under even the 3:1 minimum for
                  // non-text graphics. The info role's accent clears 4.70:1,
                  // and the notice stacks its own icon above the text at large
                  // text sizes instead of squeezing the paragraph.
                  child: AppNotice(
                    title: 'Ready when inspiration strikes',
                    message:
                        'Start with a clear selfie to receive a recommendation '
                        'based on your current analysis.',
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentLooks extends StatelessWidget {
  const _RecentLooks({
    required this.state,
    required this.onRetry,
    required this.onSessionExpired,
  });

  final HistoryState state;
  final VoidCallback onRetry;
  final VoidCallback onSessionExpired;

  @override
  Widget build(BuildContext context) {
    if (state.status == HistoryLoadStatus.loading) {
      return const Row(
        children: [
          Expanded(child: SkeletonCard(imageHeight: 96)),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: SkeletonCard(imageHeight: 96)),
        ],
      );
    }
    if (state.status == HistoryLoadStatus.failure && state.items.isEmpty) {
      return StatusState.error(
        title: 'Recent looks unavailable',
        message: state.message == null
            ? 'Start Scan is still available. Try again to refresh your private history.'
            : '${state.message} Start Scan is still available.',
        icon: Icons.cloud_off_outlined,
        actionLabel: state.sessionExpired ? 'Sign in again' : 'Retry',
        onAction: state.sessionExpired ? onSessionExpired : onRetry,
      );
    }
    if (state.items.isEmpty) {
      // An empty history is the expected state for a new account, not a
      // problem — so it stays neutral and stays quiet for a screen reader.
      return const StatusState.empty(
        title: 'No recent looks yet',
        message: 'Your completed analyses and previews will appear here.',
        icon: Icons.history_rounded,
      );
    }
    final recent = state.items.take(2).toList(growable: false);
    // A horizontal strip has to be given a height, and a fixed one clips its
    // own caption the moment the user raises their text size. Only the caption
    // grows, so only the caption's share is scaled: the thumbnail keeps its
    // area and the card grows underneath it.
    return SizedBox(
      height:
          _RecentLookCard.thumbnailHeight +
          _RecentLookCard.captionHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recent.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => _RecentLookCard(
          entry: recent[index],
          onTap: () => context.go(AppConstants.historyRoute),
        ),
      ),
    );
  }
}

class _RecentLookCard extends StatelessWidget {
  const _RecentLookCard({required this.entry, required this.onTap});

  /// The thumbnail's share of the card's height.
  ///
  /// Fixed on purpose: a picture does not get more informative when the text
  /// beside it gets larger, so the caption grows and this does not.
  static const double thumbnailHeight = 150;

  static const double _cardWidth = 168;

  /// Height the caption needs at the reader's current text size.
  ///
  /// Derived from the two line boxes it actually draws rather than guessed:
  /// `titleSmall` at 14/1.35 and `bodySmall` at 12/1.45, inside `AppSpacing.sm`
  /// padding, plus a point of slack so a fractional line height cannot round
  /// into a one-pixel overflow.
  static double captionHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return AppSpacing.sm * 2 +
        scaler.scale(14) * 1.35 +
        scaler.scale(12) * 1.45 +
        2;
  }

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _cardWidth,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: thumbnailHeight,
              width: double.infinity,
              child: PrivateImage(url: entry.thumbnailUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.style?.name ?? 'Beauty analysis',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          _date(entry.latestActivityAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (entry.isFavorite)
                    const Icon(
                      Icons.favorite_rounded,
                      size: AppIconSizes.sm,
                      color: AppColors.rose,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.roseDark, AppColors.rose],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      // The one genuinely floating surface on the screen, so the one place a
      // shadow earns its keep. Tinted with the brand rather than black, which
      // is what keeps it reading as a lift rather than as grime under the card.
      boxShadow: [
        BoxShadow(
          color: AppColors.rose.withValues(alpha: .24),
          blurRadius: AppSpacing.xl,
          offset: const Offset(0, AppSpacing.sm),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.face_retouching_natural_rounded,
          color: Colors.white,
          size: AppIconSizes.hero,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Discover your\nsignature look',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A personalized beauty analysis in a few simple steps.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            // Fixed colours because the gradient keeps its own brightness in
            // both themes, so the button cannot inherit them from the scheme.
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.roseDark,
            ),
            onPressed: onStart,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Start Scan'),
          ),
        ),
      ],
    ),
  );
}
