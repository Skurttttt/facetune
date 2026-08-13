import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import '../../../makeup_kit/domain/entities/kit_look_result.dart';
import '../../../makeup_kit/data/providers/makeup_kit_library_providers.dart';
import '../../../makeup_kit/presentation/controllers/makeup_kit_history_controller.dart';
import '../../../makeup_kit/presentation/controllers/makeup_kit_library_state.dart';
import '../../../makeup_kit/presentation/controllers/makeup_kit_look_controller.dart';
import '../../../makeup_kit/presentation/controllers/makeup_kit_result_actions_controller.dart';
import '../../../makeup_kit/presentation/widgets/kit_history_card.dart';
import '../../../preview/presentation/controllers/makeup_preview_controller.dart';
import '../../../preview/presentation/controllers/makeup_preview_state.dart';
import '../../../recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import '../../../results/presentation/controllers/result_actions_controller.dart';
import '../../../saved_looks/data/providers/saved_looks_providers.dart';
import '../../domain/entities/history_entry.dart';
import '../controllers/history_controller.dart';
import '../controllers/history_state.dart';
import '../widgets/history_card.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMore);
  }

  void _loadMore() {
    if (_scrollController.position.extentAfter < 500) {
      ref.read(historyControllerProvider.notifier).loadMore();
      ref.read(makeupKitHistoryControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMore)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final kitState = ref.watch(makeupKitHistoryControllerProvider);
    final isGuest = ref.watch(authControllerProvider).user?.isAnonymous == true;
    final previewIsGenerating = ref.watch(
      makeupPreviewControllerProvider.select(
        (state) => state.status == MakeupPreviewStatus.generating,
      ),
    );
    ref.listen<HistoryState>(historyControllerProvider, (previous, next) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.feedback!),
          action: next.sessionExpired
              ? SnackBarAction(
                  label: 'Sign in again',
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .recoverExpiredSession(),
                )
              : null,
        ),
      );
      ref.read(historyControllerProvider.notifier).clearFeedback();
    });
    ref.listen<MakeupKitHistoryState>(makeupKitHistoryControllerProvider, (
      previous,
      next,
    ) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(next.feedback!)));
      ref.read(makeupKitHistoryControllerProvider.notifier).clearFeedback();
    });
    ref.listen<int>(savedLooksRevisionProvider, (previous, next) {
      if (previous != null && previous != next) {
        ref.read(historyControllerProvider.notifier).refresh();
      }
    });
    ref.listen<int>(makeupKitLibraryRevisionProvider, (previous, next) {
      if (previous != null && previous != next) {
        ref.read(makeupKitHistoryControllerProvider.notifier).loadInitial();
      }
    });
    ref.listen<MakeupPreviewState>(makeupPreviewControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.status == MakeupPreviewStatus.generating &&
          next.status == MakeupPreviewStatus.success) {
        ref.read(historyControllerProvider.notifier).refresh();
      }
    });

    return AppShell(
      index: 2,
      child: SafeArea(
        child: PageFrame(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(historyControllerProvider.notifier).refresh(),
                ref
                    .read(makeupKitHistoryControllerProvider.notifier)
                    .loadInitial(),
              ]);
            },
            child: _content(
              context,
              state,
              kitState,
              isGuest,
              previewIsGenerating,
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    HistoryState state,
    MakeupKitHistoryState kitState,
    bool isGuest,
    bool previewIsGenerating,
  ) {
    if (state.status == HistoryLoadStatus.loading &&
        kitState.status == MakeupKitLibraryStatus.loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: LoadingState(label: 'Loading your history…')),
        ],
      );
    }
    if (state.status == HistoryLoadStatus.failure &&
        state.items.isEmpty &&
        kitState.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          StatusState(
            title: 'History unavailable',
            message: state.message ?? 'Please try again.',
            icon: Icons.history_toggle_off_rounded,
            actionLabel: state.sessionExpired ? 'Sign in again' : 'Try again',
            onAction: state.sessionExpired
                ? () => ref
                      .read(authControllerProvider.notifier)
                      .recoverExpiredSession()
                : () => ref
                      .read(historyControllerProvider.notifier)
                      .loadInitial(),
          ),
        ],
      );
    }

    final visibleItems = state.visibleItems;
    final normalizedQuery = state.query.trim().toLowerCase();
    final visibleKitItems = kitState.items
        .where((entry) {
          final matchesFilter = switch (state.filter) {
            HistoryFilter.all || HistoryFilter.completed => true,
            HistoryFilter.favorites => entry.isFavorite,
          };
          if (!matchesFilter) return false;
          if (normalizedQuery.isEmpty) return true;
          final attributes = entry.result.analysis.attributes;
          final searchable = [
            entry.result.style.name,
            entry.result.style.code,
            entry.result.recommendation.overallIntensity,
            entry.result.recommendation.summary,
            ...entry.result.recommendation.productSnapshots.expand(
              (snapshot) => [
                snapshot.category,
                snapshot.productName,
                snapshot.colorLabel,
                snapshot.colorHex,
                snapshot.finish,
                snapshot.foundationDepth,
                snapshot.foundationUndertone,
              ],
            ),
            attributes.faceShape.name,
            attributes.skinTone.name,
            attributes.undertone.name,
            attributes.eyeShape.name,
            attributes.lipShape.name,
            attributes.hairColor.name,
            attributes.eyeColor.name,
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(normalizedQuery);
        })
        .toList(growable: false);
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Text(
            'History',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
        const SliverToBoxAdapter(
          child: Text('Revisit every step of your FaceTune journey.'),
        ),
        if (isGuest) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          const SliverToBoxAdapter(
            child: AppCard(
              color: AppColors.petal,
              child: Text(
                'Guest history belongs to this temporary account and may be lost after signing out or clearing app data.',
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        SliverToBoxAdapter(
          child: TextField(
            onChanged: (value) =>
                ref.read(historyControllerProvider.notifier).setQuery(value),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search styles or beauty traits',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: state.filter == HistoryFilter.all,
                  onSelected: () => _setFilter(HistoryFilter.all),
                ),
                _FilterChip(
                  label: 'Completed',
                  selected: state.filter == HistoryFilter.completed,
                  onSelected: () => _setFilter(HistoryFilter.completed),
                ),
                _FilterChip(
                  label: 'Favorites',
                  selected: state.filter == HistoryFilter.favorites,
                  onSelected: () => _setFilter(HistoryFilter.favorites),
                ),
              ],
            ),
          ),
        ),
        if (state.status == HistoryLoadStatus.failure &&
            state.items.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverToBoxAdapter(
            child: StatusState(
              title: 'Could not load more history',
              message: state.message ?? 'Pull to refresh and try again.',
              icon: Icons.error_outline_rounded,
              actionLabel: state.sessionExpired ? 'Sign in again' : 'Retry',
              onAction: state.sessionExpired
                  ? () => ref
                        .read(authControllerProvider.notifier)
                        .recoverExpiredSession()
                  : () => ref
                        .read(historyControllerProvider.notifier)
                        .retryLoadMore(),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        if (kitState.status == MakeupKitLibraryStatus.loading)
          const SliverToBoxAdapter(
            child: Center(
              child: LoadingState(label: 'Loading My Makeup Kit history…'),
            ),
          )
        else if (visibleKitItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Text(
              'My Makeup Kit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index.isOdd) {
                return const SizedBox(height: AppSpacing.sm);
              }
              final entry = visibleKitItems[index ~/ 2];
              return KitHistoryCard(
                entry: entry,
                isMutating: kitState.mutatingIds.contains(
                  entry.result.analysis.id,
                ),
                onOpen: () => _openKit(entry),
                onDelete: () => _confirmDeleteKit(entry),
              );
            }, childCount: visibleKitItems.length * 2 - 1),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ] else if (kitState.status == MakeupKitLibraryStatus.failure)
          SliverToBoxAdapter(
            child: StatusState(
              title: 'My Makeup Kit history unavailable',
              message: kitState.message ?? 'Pull to refresh and try again.',
              icon: Icons.inventory_2_outlined,
              actionLabel: 'Try again',
              onAction: () => ref
                  .read(makeupKitHistoryControllerProvider.notifier)
                  .loadInitial(),
            ),
          ),
        if (visibleItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Text(
              'Makeup Recommendations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        ],
        if (visibleItems.isEmpty && visibleKitItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: StatusState(
              title: state.items.isEmpty && kitState.items.isEmpty
                  ? 'No FaceTune history yet'
                  : 'No matching sessions',
              message: state.items.isEmpty && kitState.items.isEmpty
                  ? 'Complete a selfie analysis to begin your private history.'
                  : 'Try another search or filter.',
              icon: state.items.isEmpty
                  ? Icons.history_rounded
                  : Icons.search_off_rounded,
            ),
          )
        else if (visibleItems.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index.isOdd) {
                return const SizedBox(height: AppSpacing.sm);
              }
              final entry = visibleItems[index ~/ 2];
              return HistoryCard(
                entry: entry,
                isMutating: state.mutatingIds.contains(entry.id),
                onOpen: () => _open(entry),
                onFavorite: entry.preview == null
                    ? null
                    : () => ref
                          .read(historyControllerProvider.notifier)
                          .toggleFavorite(entry),
                onRegenerate: entry.canRegenerate && !previewIsGenerating
                    ? () => _regenerate(entry)
                    : null,
                onDelete: () => _confirmDelete(entry),
              );
            }, childCount: visibleItems.length * 2 - 1),
          ),
        if (state.status == HistoryLoadStatus.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        if (kitState.status == MakeupKitLibraryStatus.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  void _setFilter(HistoryFilter filter) =>
      ref.read(historyControllerProvider.notifier).setFilter(filter);

  void _restoreBase(HistoryEntry entry) {
    ref.read(faceAnalysisControllerProvider.notifier).restore(entry.analysis);
    final style = entry.style;
    final recommendation = entry.recommendation;
    if (style != null && recommendation != null) {
      ref.read(makeupStyleSelectionControllerProvider.notifier).restore(style);
      ref
          .read(makeupRecommendationControllerProvider.notifier)
          .restore(recommendation);
    } else {
      ref.read(makeupStyleSelectionControllerProvider.notifier).clear();
      ref.read(makeupRecommendationControllerProvider.notifier).clear();
    }
  }

  void _open(HistoryEntry entry) {
    _restoreBase(entry);
    final preview = entry.preview;
    final recommendation = entry.recommendation;
    if (preview != null && recommendation != null) {
      final style = entry.style;
      if (style == null ||
          recommendation.analysisId != entry.analysis.id ||
          preview.analysisId != entry.analysis.id ||
          preview.recommendationId != recommendation.id ||
          style.code != recommendation.styleCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This historical result has incomplete links and cannot be opened.',
            ),
          ),
        );
        return;
      }
      ref
          .read(makeupPreviewControllerProvider.notifier)
          .restore(preview, recommendation: recommendation);
      final actions = ref.read(resultActionsControllerProvider.notifier);
      final savedLook = entry.savedLook;
      if (savedLook == null) {
        actions.forgetSavedLook(preview.id);
      } else {
        actions.restoreSavedLook(savedLook);
      }
      context.push(AppConstants.previewRoute);
      return;
    }
    ref.read(makeupPreviewControllerProvider.notifier).clear();
    context.push(
      recommendation == null
          ? AppConstants.analysisRoute
          : AppConstants.recommendationRoute,
    );
  }

  void _openKit(KitHistoryEntry entry) {
    final result = entry.result;
    ref.read(faceAnalysisControllerProvider.notifier).restore(result.analysis);
    ref
        .read(makeupStyleSelectionControllerProvider.notifier)
        .restore(result.style);
    ref
        .read(makeupKitLookControllerProvider.notifier)
        .restore(
          recommendation: result.recommendation,
          preview: result.preview,
        );
    final saved = entry.savedLook;
    if (saved != null) {
      ref
          .read(makeupKitResultActionsControllerProvider.notifier)
          .restoreSavedLook(saved);
    }
    context.push(AppConstants.makeupKitRecommendationEntryRoute);
  }

  Future<void> _regenerate(HistoryEntry entry) async {
    final recommendation = entry.recommendation;
    if (recommendation == null ||
        ref.read(makeupPreviewControllerProvider).status ==
            MakeupPreviewStatus.generating) {
      return;
    }
    _restoreBase(entry);
    final generation = ref
        .read(makeupPreviewControllerProvider.notifier)
        .generate(recommendation: recommendation);
    context.push(AppConstants.previewRoute);
    await generation;
  }

  Future<void> _confirmDelete(HistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this history session?'),
        content: const Text(
          'This permanently removes the original selfie, every generated preview, recommendations, and any saved or favorited looks in this session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await ref
        .read(historyControllerProvider.notifier)
        .delete(entry);
    if (!deleted || !mounted) return;
    ref.read(resultActionsControllerProvider.notifier).forgetAnalysis(entry.id);
    if (ref.read(faceAnalysisControllerProvider).analysis?.id == entry.id) {
      ref.read(faceAnalysisControllerProvider.notifier).clear();
      ref.read(makeupStyleSelectionControllerProvider.notifier).clear();
      ref.read(makeupRecommendationControllerProvider.notifier).clear();
      ref.read(makeupPreviewControllerProvider.notifier).clear();
    }
  }

  Future<void> _confirmDeleteKit(KitHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this history session?'),
        content: const Text(
          'This permanently removes the original selfie, standard and My Makeup Kit previews, recommendations, and saved looks in this session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await ref
        .read(makeupKitHistoryControllerProvider.notifier)
        .delete(entry);
    if (!deleted || !mounted) return;
    if (ref.read(faceAnalysisControllerProvider).analysis?.id ==
        entry.result.analysis.id) {
      ref.read(faceAnalysisControllerProvider.notifier).clear();
      ref.read(makeupStyleSelectionControllerProvider.notifier).clear();
      ref.read(makeupRecommendationControllerProvider.notifier).clear();
      ref.read(makeupPreviewControllerProvider.notifier).clear();
      ref.read(makeupKitLookControllerProvider.notifier).clear();
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.xs),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}
