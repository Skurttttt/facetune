import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
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
import '../../../preview/presentation/controllers/makeup_preview_controller.dart';
import '../../../preview/presentation/controllers/makeup_preview_state.dart';
import '../../../recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import '../../../results/presentation/controllers/result_actions_controller.dart';
import '../../../saved_looks/data/providers/saved_looks_providers.dart';
import '../../domain/entities/history_entry.dart';
import '../controllers/history_controller.dart';
import '../controllers/history_state.dart';
import '../models/history_feed_item.dart';
import '../widgets/history_feed.dart';
import '../widgets/history_filter_controls.dart';
import '../widgets/history_card.dart';
import '../widgets/history_card_skeleton.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  /// The one order the feed is ever built in.
  ///
  /// A constant rather than a field: with the Sort control gone there is no
  /// longer anything that can set an order, so keeping the choice in mutable
  /// state would only leave somewhere for a stale `Oldest` or `A-Z` to survive.
  /// Newest first is also what keeps the date headings meaningful — `A-Z`
  /// suppressed them entirely.
  static const _sort = HistoryFeedSort.newest;

  final _scrollController = ScrollController();
  HistoryFeedTypeFilter _typeFilter = HistoryFeedTypeFilter.all;

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
      // A refresh that failed reports here too, and it must not arrive wearing
      // the same tone as "Added to favorites." The state already carried
      // `feedbackIsError`; nothing was reading it.
      showAppSnackBar(
        context,
        message: next.feedback!,
        tone: next.sessionExpired || next.feedbackIsError
            ? AppTone.danger
            : AppTone.success,
        actionLabel: next.sessionExpired ? 'Sign in again' : null,
        onAction: next.sessionExpired
            ? () => ref
                  .read(authControllerProvider.notifier)
                  .recoverExpiredSession()
            : null,
      );
      ref.read(historyControllerProvider.notifier).clearFeedback();
    });
    ref.listen<MakeupKitHistoryState>(makeupKitHistoryControllerProvider, (
      previous,
      next,
    ) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      showAppSnackBar(context, message: next.feedback!);
      ref.read(makeupKitHistoryControllerProvider.notifier).clearFeedback();
    });
    ref.listen<int>(savedLooksRevisionProvider, (previous, next) {
      if (previous != null && previous != next) {
        ref.read(historyControllerProvider.notifier).refresh();
      }
    });
    ref.listen<int>(makeupKitLibraryRevisionProvider, (previous, next) {
      if (previous != null && previous != next) {
        // A refresh rather than a reload: something changed elsewhere in the
        // app, and the user did not ask to lose their place over it.
        ref.read(makeupKitHistoryControllerProvider.notifier).refresh();
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
        child: PageFrame.scrolling(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(historyControllerProvider.notifier).refresh(),
                ref.read(makeupKitHistoryControllerProvider.notifier).refresh(),
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
    if (state.status == HistoryLoadStatus.failure &&
        state.items.isEmpty &&
        kitState.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppSpacing.xxl),
          StatusState.error(
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

    final feedItems = buildHistoryFeed(
      recommendations: state.items,
      myMakeupKit: kitState.items,
      typeFilter: _typeFilter,
      statusFilter: state.filter,
      query: state.query,
      sort: _sort,
    );
    // How many of the two authorities have not finished their first page. The
    // page chrome is built either way, so the header, the filters and the feed
    // rows all land in their final positions on the very first frame and stay
    // there — there is no full-screen spinner that later gives way to a layout.
    final stillLoading =
        (state.status == HistoryLoadStatus.loading ? 1 : 0) +
        (kitState.status == MakeupKitLibraryStatus.loading ? 1 : 0);
    final isLoadingMore =
        state.status == HistoryLoadStatus.loadingMore ||
        kitState.status == MakeupKitLibraryStatus.loadingMore;
    return CustomScrollView(
      // Opening a record and coming back must land where the user left, not at
      // the top. The offset is kept twice over: by [_scrollController], which
      // outlives the rebuild, and by PageStorage against this key, which
      // survives the Scrollable itself being rebuilt. Both are local to this
      // session — nothing here is written to Supabase or to settings.
      key: const PageStorageKey('history-feed'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: TopLevelPageHeader(
            title: 'History',
            subtitle: 'Revisit every step of your FaceTune journey.',
          ),
        ),
        if (isGuest) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          const SliverToBoxAdapter(
            child: AppNotice(
              tone: AppTone.warning,
              message:
                  'Guest history belongs to this temporary account and may be '
                  'lost after signing out or clearing app data.',
            ),
          ),
        ],
        const SliverToBoxAdapter(
          child: SizedBox(height: TopLevelHeaderMetrics.contentGap),
        ),
        SliverToBoxAdapter(
          child: HistoryFilterControls(
            query: state.query,
            typeFilter: _typeFilter,
            statusFilter: state.filter,
            onQueryChanged: (value) =>
                ref.read(historyControllerProvider.notifier).setQuery(value),
            onTypeChanged: (filter) => setState(() => _typeFilter = filter),
            onStatusChanged: _setFilter,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        if (kitState.status == MakeupKitLibraryStatus.failure &&
            kitState.items.isEmpty)
          SliverToBoxAdapter(
            child: StatusState.error(
              title: 'My Makeup Kit history unavailable',
              message: kitState.message ?? 'Pull to refresh and try again.',
              icon: Icons.inventory_2_outlined,
              actionLabel: kitState.sessionExpired
                  ? 'Sign in again'
                  : 'Try again',
              onAction: kitState.sessionExpired
                  ? () => ref
                        .read(authControllerProvider.notifier)
                        .recoverExpiredSession()
                  : () => ref
                        .read(makeupKitHistoryControllerProvider.notifier)
                        .loadInitial(),
            ),
          ),
        if (feedItems.isEmpty && stillLoading > 0)
          // Nothing has arrived yet. "No FaceTune history yet" would be a claim
          // the app cannot make while a request is still out.
          const HistoryFeedSkeleton(count: 5)
        else if (feedItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            // Every branch is an absence, not a failure: nothing created yet,
            // nothing of this kind yet, nothing favorited yet, or nothing
            // matching. None should announce itself or wear an error tone, and
            // each should name the thing that would fix it.
            child: Builder(
              builder: (context) {
                final reason = resolveHistoryEmptyReason(
                  hasAnyRecords:
                      state.items.isNotEmpty || kitState.items.isNotEmpty,
                  typeFilter: _typeFilter,
                  statusFilter: state.filter,
                  query: state.query,
                );
                return StatusState.empty(
                  title: reason.title,
                  message: reason.message,
                  icon: switch (reason) {
                    HistoryEmptyReason.noHistory => Icons.history_rounded,
                    HistoryEmptyReason.noMyMakeupKitHistory =>
                      Icons.inventory_2_outlined,
                    HistoryEmptyReason.noFavorites =>
                      Icons.favorite_border_rounded,
                    HistoryEmptyReason.noMatches => Icons.search_off_rounded,
                  },
                );
              },
            ),
          )
        else
          HistoryFeed(
            items: feedItems,
            sort: _sort,
            // One card widget, two untouched authorities. Each branch still
            // reads its own controller for mutation state and still calls the
            // callbacks that mode already owned.
            itemBuilder: (context, item) => switch (item) {
              StandardHistoryFeedItem(:final entry) => HistoryCard(
                item: item,
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
                // The wording the removed icon's tooltip already used.
                regenerateLabel: entry.preview == null
                    ? 'Generate preview'
                    : 'Generate another variation',
                onDelete: () => _confirmDelete(entry),
              ),
              // No favorite action: the My Kit history authority
              // (MakeupKitHistoryController) exposes delete only, and inventing
              // one here would mean inventing persistence for it. The heart on
              // the card stays as the read-only indicator it already was.
              MyMakeupKitHistoryFeedItem(:final entry) => HistoryCard(
                item: item,
                isMutating: kitState.mutatingIds.contains(
                  entry.result.analysis.id,
                ),
                onOpen: () => _openKit(entry),
                onDelete: () => _confirmDeleteKit(entry),
              ),
            },
          ),
        // Two rows standing in for the page being fetched — whether that is one
        // authority's first page or another's next. They are shaped like the
        // cards they will become, so the list grows downward instead of a
        // spinner appearing and then shoving everything up. One footer serves
        // both authorities: they page independently, and a second spinner said
        // nothing the first one did not.
        if (feedItems.isNotEmpty && (stillLoading > 0 || isLoadingMore))
          const HistoryFeedSkeleton(count: 2),
        // Inline, at the bottom, next to the rows that did load. A failed next
        // page never takes away the pages that succeeded.
        if (state.status == HistoryLoadStatus.failure && state.items.isNotEmpty)
          SliverToBoxAdapter(
            child: StatusState.error(
              title: 'Could not load more history',
              message: state.message ?? 'Pull to refresh and try again.',
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
        if (kitState.status == MakeupKitLibraryStatus.failure &&
            kitState.items.isNotEmpty)
          SliverToBoxAdapter(
            child: StatusState.error(
              title: 'Could not load more My Makeup Kit history',
              message: kitState.message ?? 'Pull to refresh and try again.',
              icon: Icons.inventory_2_outlined,
              actionLabel: kitState.sessionExpired ? 'Sign in again' : 'Retry',
              onAction: kitState.sessionExpired
                  ? () => ref
                        .read(authControllerProvider.notifier)
                        .recoverExpiredSession()
                  : () => ref
                        .read(makeupKitHistoryControllerProvider.notifier)
                        .retryLoadMore(),
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
    // Irreversible, and it was styled exactly like an ordinary confirmation —
    // a plain filled button next to Cancel. `isDestructive` gives it the danger
    // treatment every other permanent deletion in the app now shares.
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this history session?',
      message:
          'This permanently removes the original selfie, every generated '
          'preview, recommendations, and any saved or favorited looks in this '
          'session.',
      confirmLabel: 'Delete permanently',
      isDestructive: true,
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
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this history session?',
      message:
          'This permanently removes the original selfie, standard and My Makeup '
          'Kit previews, recommendations, and saved looks in this session.',
      confirmLabel: 'Delete permanently',
      isDestructive: true,
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
