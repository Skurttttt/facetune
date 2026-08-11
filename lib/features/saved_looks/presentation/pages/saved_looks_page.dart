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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMore);
  }

  void _loadMore() {
    if (_scrollController.position.extentAfter < 500) {
      ref.read(savedLooksControllerProvider.notifier).loadMore();
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
    final state = ref.watch(savedLooksControllerProvider);
    final isGuest = ref.watch(authControllerProvider).user?.isAnonymous == true;
    return AppShell(
      index: 1,
      child: SafeArea(
        child: PageFrame(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(savedLooksControllerProvider.notifier).refresh(),
            child: _buildContent(context, state, isGuest),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SavedLooksState state,
    bool isGuest,
  ) {
    if (state.status == SavedLooksStatus.loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          Center(child: LoadingState(label: 'Loading your saved looks…')),
        ],
      );
    }
    if (state.status == SavedLooksStatus.failure && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          StatusState(
            title: 'Saved looks unavailable',
            message: state.message ?? 'Please try again.',
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Try again',
            onAction: () =>
                ref.read(savedLooksControllerProvider.notifier).loadInitial(),
          ),
        ],
      );
    }
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Text(
            'Saved looks',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
        const SliverToBoxAdapter(
          child: Text('Your personal makeup library, ready when you are.'),
        ),
        if (isGuest) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          const SliverToBoxAdapter(
            child: AppCard(
              color: AppColors.petal,
              child: Text(
                'Guest looks are private to this temporary account and may be lost after signing out or clearing app data.',
              ),
            ),
          ),
        ],
        if (state.status == SavedLooksStatus.failure &&
            state.items.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverToBoxAdapter(
            child: StatusState(
              title: 'Could not finish updating',
              message: state.message ?? 'Pull to refresh and try again.',
              icon: Icons.error_outline_rounded,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        if (state.items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: StatusState(
              title: 'No saved looks yet',
              message:
                  'Generate a makeup preview and choose Save Look to build your collection.',
              icon: Icons.bookmark_border_rounded,
            ),
          )
        else
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final columns = width >= 1000
                  ? 4
                  : width >= 700
                  ? 3
                  : 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: .68,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final look = state.items[index];
                  return SavedLookCard(
                    look: look,
                    onOpen: () => _openResult(look),
                    onFavorite: () => _toggleFavorite(look),
                    onRemove: () => _confirmRemove(look),
                  );
                }, childCount: state.items.length),
              );
            },
          ),
        if (state.status == SavedLooksStatus.loadingMore)
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

  void _openResult(SavedLook look) {
    ref.read(faceAnalysisControllerProvider.notifier).restore(look.analysis);
    ref
        .read(makeupStyleSelectionControllerProvider.notifier)
        .restore(look.style);
    ref
        .read(makeupRecommendationControllerProvider.notifier)
        .restore(look.recommendation);
    ref.read(makeupPreviewControllerProvider.notifier).restore(look.preview);
    ref.read(resultActionsControllerProvider.notifier).restoreSavedLook(look);
    context.push(AppConstants.previewRoute);
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
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove saved look?'),
        content: Text(
          '${look.style.name} will be removed from your saved collection. The generated preview remains in your private history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
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
}
