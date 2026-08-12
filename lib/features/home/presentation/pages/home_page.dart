import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_shell.dart';
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
                            const SizedBox(height: 4),
                            Text(
                              'What beauty mood are you in?',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted(context)),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
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
                SliverToBoxAdapter(
                  child: AppCard(
                    color: AppColors.petal,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          color: AppColors.gold,
                          size: AppIconSizes.lg,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ready when inspiration strikes',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Start with a clear selfie to receive a recommendation based on your current analysis.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
      return StatusState(
        title: 'Recent looks unavailable',
        message: state.message == null
            ? 'Start Scan is still available. Try again to refresh your private history.'
            : '${state.message} Start Scan is still available.',
        icon: Icons.cloud_off_outlined,
        actionLabel: state.sessionExpired ? 'Sign in again' : 'Retry',
        onAction: state.sessionExpired ? onSessionExpired : onRetry,
        liveRegion: true,
      );
    }
    if (state.items.isEmpty) {
      return const StatusState(
        title: 'No recent looks yet',
        message: 'Your completed analyses and previews will appear here.',
        icon: Icons.history_rounded,
      );
    }
    final recent = state.items.take(2).toList(growable: false);
    return SizedBox(
      height: 224,
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

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 168,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: PrivateImage(url: entry.thumbnailUrl),
              ),
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
      boxShadow: [
        BoxShadow(
          color: AppColors.rose.withValues(alpha: .24),
          blurRadius: 30,
          offset: const Offset(0, 14),
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
        const Text(
          'A personalized beauty analysis in a few simple steps.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.roseDark,
          ),
          onPressed: onStart,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Start Scan'),
        ),
      ],
    ),
  );
}
