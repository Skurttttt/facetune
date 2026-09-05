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
import '../../../makeup_kit/presentation/controllers/makeup_kit_library_state.dart';
import '../../../makeup_kit/presentation/controllers/makeup_kit_look_controller.dart';
import '../../../makeup_kit/presentation/controllers/makeup_kit_result_actions_controller.dart';
import '../../../makeup_kit/presentation/controllers/makeup_kit_saved_controller.dart';
import '../../../makeup_kit/presentation/widgets/kit_saved_look_card.dart';
import '../../../preview/presentation/controllers/makeup_preview_controller.dart';
import '../../../recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import '../../../results/presentation/controllers/result_actions_controller.dart';
import '../../domain/entities/saved_look.dart';
import '../controllers/saved_looks_controller.dart';
import '../controllers/saved_looks_state.dart';
import '../widgets/saved_look_card.dart';

class SavedLooksPage extends ConsumerStatefulWidget {
  const SavedLooksPage({super.key});

  @override
  ConsumerState<SavedLooksPage> createState() => _SavedLooksPageState();
}

class _SavedLooksPageState extends ConsumerState<SavedLooksPage> {
  final _scrollController = ScrollController();
  final _kitPaginationAnchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMore);
  }

  void _loadMore() {
    if (!_scrollController.hasClients) return;

    // Standard is the final section, so the page tail is its pagination tail.
    if (_scrollController.position.extentAfter < 500) {
      final standard = ref.read(savedLooksControllerProvider);
      if (standard.status == SavedLooksStatus.ready && standard.hasMore) {
        ref.read(savedLooksControllerProvider.notifier).loadMore();
      }
    }

    // My Makeup Kit sits above Standard. Loading it at the page tail inserted
    // new tiles above the viewport while the user was scrolling Standard. Its
    // own tail is now the trigger, so above-viewport relayout is avoided.
    final kit = ref.read(makeupKitSavedControllerProvider);
    final anchorContext = _kitPaginationAnchor.currentContext;
    final anchorBox = anchorContext?.findRenderObject();
    if (kit.status != MakeupKitLibraryStatus.ready ||
        !kit.hasMore ||
        kit.items.isEmpty ||
        anchorBox is! RenderBox ||
        !anchorBox.attached) {
      return;
    }
    final anchorY = anchorBox.localToGlobal(Offset.zero).dy;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (anchorY > -500 && anchorY < viewportHeight + 500) {
      ref.read(makeupKitSavedControllerProvider.notifier).loadMore();
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
    // Keep the expensive scroll subtree independent from controller metadata.
    // These values change only when the page must swap its outer presentation;
    // loading-more, feedback, and mutation emissions no longer rebuild both
    // visible grids.
    final isInitialLoading = ref.watch(
      savedLooksControllerProvider.select(
        (state) => state.status == SavedLooksStatus.loading,
      ),
    );
    final isInitialFailure = ref.watch(
      savedLooksControllerProvider.select(
        (state) =>
            state.status == SavedLooksStatus.failure && state.items.isEmpty,
      ),
    );
    final kitIsEmpty = ref.watch(
      makeupKitSavedControllerProvider.select((state) => state.items.isEmpty),
    );
    final isGuest = ref.watch(
      authControllerProvider.select((state) => state.user?.isAnonymous == true),
    );
    ref.listen<SavedLooksState>(savedLooksControllerProvider, (previous, next) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      showAppSnackBar(
        context,
        message: next.feedback!,
        tone: next.sessionExpired ? AppTone.danger : AppTone.success,
        actionLabel: next.sessionExpired ? 'Sign in again' : null,
        onAction: next.sessionExpired
            ? () => ref
                  .read(authControllerProvider.notifier)
                  .recoverExpiredSession()
            : null,
      );
      ref.read(savedLooksControllerProvider.notifier).clearFeedback();
    });
    ref.listen<MakeupKitSavedState>(makeupKitSavedControllerProvider, (
      previous,
      next,
    ) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      showAppSnackBar(context, message: next.feedback!);
      ref.read(makeupKitSavedControllerProvider.notifier).clearFeedback();
    });
    return AppShell(
      index: 1,
      child: SafeArea(
        child: PageFrame.scrolling(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(savedLooksControllerProvider.notifier).refresh(),
                ref
                    .read(makeupKitSavedControllerProvider.notifier)
                    .loadInitial(),
              ]);
            },
            child: isInitialLoading
                ? const _InitialLoadingView()
                : isInitialFailure && kitIsEmpty
                ? const _InitialFailureView()
                : _buildContent(context, isGuest),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isGuest) {
    return CustomScrollView(
      // Match History's stable scroll identity. The controller preserves the
      // offset across ordinary rebuilds; PageStorage also preserves it if the
      // Scrollable element is replaced by an initial-state transition.
      key: const PageStorageKey('saved-looks-feed'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: TopLevelPageHeader(
            title: 'Saved looks',
            subtitle: 'Your personal makeup library, ready when you are.',
          ),
        ),
        if (isGuest) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          const SliverToBoxAdapter(
            child: AppNotice(
              tone: AppTone.warning,
              message:
                  'Guest looks are private to this temporary account and may be '
                  'lost after signing out or clearing app data.',
            ),
          ),
        ],
        const _StandardFailureSliver(),
        const SliverToBoxAdapter(
          child: SizedBox(height: TopLevelHeaderMetrics.contentGap),
        ),
        const _KitStatusSliver(),
        const _KitSectionHeaderSliver(),
        _KitSavedLooksGrid(onOpen: _openKitResult, onRemove: _confirmRemoveKit),
        _KitSectionGapSliver(anchorKey: _kitPaginationAnchor),
        const _StandardSectionHeaderSliver(),
        const _EmptySavedLooksSliver(),
        _StandardSavedLooksGrid(
          onOpen: _openResult,
          onFavorite: _toggleFavorite,
          onRemove: _confirmRemove,
        ),
        const _StandardLoadingMoreSliver(),
        const _KitLoadingMoreSliver(),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  void _openResult(SavedLook look) {
    ref.read(faceAnalysisControllerProvider.notifier).restore(look.analysis);
    ref
        .read(makeupStyleSelectionControllerProvider.notifier)
        .restore(look.style);
    ref
        .read(makeupRecommendationControllerProvider.notifier)
        .restore(look.recommendation);
    ref
        .read(makeupPreviewControllerProvider.notifier)
        .restore(look.preview, recommendation: look.recommendation);
    ref.read(resultActionsControllerProvider.notifier).restoreSavedLook(look);
    context.push(AppConstants.previewRoute);
  }

  void _openKitResult(KitSavedLook look) {
    final result = look.result;
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
    ref
        .read(makeupKitResultActionsControllerProvider.notifier)
        .restoreSavedLook(look);
    context.push(AppConstants.makeupKitRecommendationEntryRoute);
  }

  Future<void> _toggleFavorite(SavedLook look) async {
    await ref.read(savedLooksControllerProvider.notifier).toggleFavorite(look);
    if (!mounted) return;
    final updated = ref
        .read(savedLooksControllerProvider)
        .items
        .where((item) => item.id == look.id)
        .firstOrNull;
    if (updated != null) {
      ref
          .read(resultActionsControllerProvider.notifier)
          .restoreSavedLook(updated);
    }
  }

  Future<void> _confirmRemove(SavedLook look) async {
    // Not marked destructive: the copy is explicit that the preview survives in
    // history, so this is a removal from a collection rather than a permanent
    // deletion. Reserving the danger treatment for what is actually
    // irreversible is what keeps it meaningful when it does appear.
    final remove = await showConfirmationDialog(
      context,
      title: 'Remove saved look?',
      message:
          '${look.style.name} will be removed from your saved collection. The '
          'generated preview remains in your private history.',
      confirmLabel: 'Remove',
    );
    if (remove == true) {
      await ref.read(savedLooksControllerProvider.notifier).remove(look);
      if (mounted &&
          !ref
              .read(savedLooksControllerProvider)
              .items
              .any((item) => item.id == look.id)) {
        ref
            .read(resultActionsControllerProvider.notifier)
            .forgetSavedLook(look.preview.id);
      }
    }
  }

  Future<void> _confirmRemoveKit(KitSavedLook look) async {
    final remove = await showConfirmationDialog(
      context,
      title: 'Remove saved kit look?',
      message:
          '${look.result.style.name} will be removed from Saved Looks. Its '
          'product snapshot and preview remain in private history.',
      confirmLabel: 'Remove',
    );
    if (remove == true) {
      await ref.read(makeupKitSavedControllerProvider.notifier).remove(look);
    }
  }
}

class _InitialLoadingView extends StatelessWidget {
  const _InitialLoadingView();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: const [
      SizedBox(height: AppSpacing.xxl * 2),
      Center(child: LoadingState(label: 'Loading your saved looks…')),
    ],
  );
}

class _InitialFailureView extends ConsumerWidget {
  const _InitialFailureView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(
      savedLooksControllerProvider.select(
        (state) =>
            (message: state.message, sessionExpired: state.sessionExpired),
      ),
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        StatusState.error(
          title: 'Saved looks unavailable',
          message: failure.message ?? 'Please try again.',
          icon: Icons.cloud_off_outlined,
          actionLabel: failure.sessionExpired ? 'Sign in again' : 'Try again',
          onAction: failure.sessionExpired
              ? () => ref
                    .read(authControllerProvider.notifier)
                    .recoverExpiredSession()
              : () => ref
                    .read(savedLooksControllerProvider.notifier)
                    .loadInitial(),
        ),
      ],
    );
  }
}

/// Owns only the Standard inline failure presentation. Status changes can
/// rebuild this small sliver without replacing either grid delegate.
class _StandardFailureSliver extends ConsumerWidget {
  const _StandardFailureSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(
      savedLooksControllerProvider.select(
        (state) => (
          visible:
              state.status == SavedLooksStatus.failure &&
              state.items.isNotEmpty,
          message: state.message,
          sessionExpired: state.sessionExpired,
        ),
      ),
    );
    if (!failure.visible) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: StatusState.error(
          title: 'Could not finish updating',
          message: failure.message ?? 'Pull to refresh and try again.',
          icon: Icons.error_outline_rounded,
          actionLabel: failure.sessionExpired ? 'Sign in again' : 'Retry',
          onAction: failure.sessionExpired
              ? () => ref
                    .read(authControllerProvider.notifier)
                    .recoverExpiredSession()
              : () => ref
                    .read(savedLooksControllerProvider.notifier)
                    .retryLoadMore(),
        ),
      ),
    );
  }
}

/// Owns only My Makeup Kit's initial loading/failure presentation. Its item
/// grid observes the item list separately below.
class _KitStatusSliver extends ConsumerWidget {
  const _KitStatusSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      makeupKitSavedControllerProvider.select(
        (state) => (
          status: state.status,
          hasItems: state.items.isNotEmpty,
          message: state.message,
          sessionExpired: state.sessionExpired,
        ),
      ),
    );
    if (state.status == MakeupKitLibraryStatus.loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.lg),
          child: Center(
            child: LoadingState(label: 'Loading My Makeup Kit looks…'),
          ),
        ),
      );
    }
    if (state.status != MakeupKitLibraryStatus.failure || state.hasItems) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: StatusState.error(
        title: 'My Makeup Kit looks unavailable',
        message: state.message ?? 'Pull to refresh and try again.',
        icon: Icons.inventory_2_outlined,
        actionLabel: state.sessionExpired ? 'Sign in again' : 'Try again',
        onAction: state.sessionExpired
            ? () => ref
                  .read(authControllerProvider.notifier)
                  .recoverExpiredSession()
            : () => ref
                  .read(makeupKitSavedControllerProvider.notifier)
                  .loadInitial(),
      ),
    );
  }
}

class _KitSectionHeaderSliver extends ConsumerWidget {
  const _KitSectionHeaderSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = ref.watch(
      makeupKitSavedControllerProvider.select(
        (state) => state.items.isNotEmpty,
      ),
    );
    if (!hasItems) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          'My Makeup Kit',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

class _KitSectionGapSliver extends ConsumerWidget {
  const _KitSectionGapSliver({required this.anchorKey});

  final Key anchorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = ref.watch(
      makeupKitSavedControllerProvider.select(
        (state) => state.items.isNotEmpty,
      ),
    );
    return SliverToBoxAdapter(
      child: SizedBox(key: anchorKey, height: hasItems ? AppSpacing.lg : 0),
    );
  }
}

class _StandardSectionHeaderSliver extends ConsumerWidget {
  const _StandardSectionHeaderSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = ref.watch(
      savedLooksControllerProvider.select((state) => state.items.isNotEmpty),
    );
    if (!hasItems) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          'Makeup Recommendations',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

class _EmptySavedLooksSliver extends ConsumerWidget {
  const _EmptySavedLooksSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standardIsEmpty = ref.watch(
      savedLooksControllerProvider.select((state) => state.items.isEmpty),
    );
    final kitIsEmpty = ref.watch(
      makeupKitSavedControllerProvider.select((state) => state.items.isEmpty),
    );
    if (!standardIsEmpty || !kitIsEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: StatusState.empty(
        title: 'No saved looks yet',
        message:
            'Generate a makeup preview and choose Save Look to build your collection.',
        icon: Icons.bookmark_border_rounded,
      ),
    );
  }
}

class _KitSavedLooksGrid extends ConsumerWidget {
  const _KitSavedLooksGrid({required this.onOpen, required this.onRemove});

  final void Function(KitSavedLook look) onOpen;
  final void Function(KitSavedLook look) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      makeupKitSavedControllerProvider.select((state) => state.items),
    );
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnsFor(constraints.crossAxisExtent),
          childAspectRatio: .56,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final look = items[index];
          return _KitSavedLookTile(
            key: ValueKey(look.id),
            look: look,
            onOpen: () => onOpen(look),
            onRemove: () => onRemove(look),
          );
        }, childCount: items.length),
      ),
    );
  }
}

class _StandardSavedLooksGrid extends ConsumerWidget {
  const _StandardSavedLooksGrid({
    required this.onOpen,
    required this.onFavorite,
    required this.onRemove,
  });

  final void Function(SavedLook look) onOpen;
  final void Function(SavedLook look) onFavorite;
  final void Function(SavedLook look) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      savedLooksControllerProvider.select((state) => state.items),
    );
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnsFor(constraints.crossAxisExtent),
          childAspectRatio: .56,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final look = items[index];
          return _StandardSavedLookTile(
            key: ValueKey(look.id),
            look: look,
            onOpen: () => onOpen(look),
            onFavorite: () => onFavorite(look),
            onRemove: () => onRemove(look),
          );
        }, childCount: items.length),
      ),
    );
  }
}

/// Only the affected card observes its mutation bit. A mutation emission keeps
/// the item-list identity unchanged, so neither grid delegate is reconstructed.
class _StandardSavedLookTile extends ConsumerWidget {
  const _StandardSavedLookTile({
    required this.look,
    required this.onOpen,
    required this.onFavorite,
    required this.onRemove,
    super.key,
  });

  final SavedLook look;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMutating = ref.watch(
      savedLooksControllerProvider.select(
        (state) => state.mutatingIds.contains(look.id),
      ),
    );
    return SavedLookCard(
      look: look,
      isMutating: isMutating,
      onOpen: onOpen,
      onFavorite: onFavorite,
      onRemove: onRemove,
    );
  }
}

class _KitSavedLookTile extends ConsumerWidget {
  const _KitSavedLookTile({
    required this.look,
    required this.onOpen,
    required this.onRemove,
    super.key,
  });

  final KitSavedLook look;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMutating = ref.watch(
      makeupKitSavedControllerProvider.select(
        (state) => state.mutatingIds.contains(look.id),
      ),
    );
    return KitSavedLookCard(
      look: look,
      isMutating: isMutating,
      onOpen: onOpen,
      onFavorite: () => ref
          .read(makeupKitSavedControllerProvider.notifier)
          .toggleFavorite(look),
      onRemove: onRemove,
    );
  }
}

class _StandardLoadingMoreSliver extends ConsumerWidget {
  const _StandardLoadingMoreSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoadingMore = ref.watch(
      savedLooksControllerProvider.select(
        (state) => state.status == SavedLooksStatus.loadingMore,
      ),
    );
    return SliverToBoxAdapter(
      child: isLoadingMore
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: AppProgress()),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _KitLoadingMoreSliver extends ConsumerWidget {
  const _KitLoadingMoreSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoadingMore = ref.watch(
      makeupKitSavedControllerProvider.select(
        (state) => state.status == MakeupKitLibraryStatus.loadingMore,
      ),
    );
    return SliverToBoxAdapter(
      child: isLoadingMore
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: AppProgress()),
            )
          : const SizedBox.shrink(),
    );
  }
}

int _columnsFor(double width) => width >= 1000
    ? 4
    : width >= 700
    ? 3
    : 2;
